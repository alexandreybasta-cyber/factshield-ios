// FactShield Chrome Extension — Fact Check Pipeline Orchestrator
import { PIPELINE_STATES, STORAGE_KEYS, MAX_SOURCES } from "../shared/constants.js";
import { extractClaims, synthesizeVerdict } from "./qwen.js";
import { searchEvidence } from "./tavily.js";
import { searchFactChecks } from "./google-factcheck.js";

const LOG_PREFIX = "[FactShield]";

/**
 * Main orchestrator for the fact-checking pipeline.
 * Coordinates claim extraction, evidence retrieval, and verdict synthesis.
 */
export class FactCheckPipeline {
  constructor() {
    this.qwenApiKey = null;
    this.tavilyApiKey = null;
    this.googleApiKey = null;
    this.statusCallback = null;
    this.initialized = false;
  }

  /**
   * Loads API keys from chrome.storage.local.
   */
  async initialize() {
    try {
      const result = await chrome.storage.local.get([
        STORAGE_KEYS.QWEN_API_KEY,
        STORAGE_KEYS.TAVILY_API_KEY,
        STORAGE_KEYS.GOOGLE_FACTCHECK_API_KEY,
      ]);

      this.qwenApiKey = result[STORAGE_KEYS.QWEN_API_KEY] || null;
      this.tavilyApiKey = result[STORAGE_KEYS.TAVILY_API_KEY] || null;
      this.googleApiKey = result[STORAGE_KEYS.GOOGLE_FACTCHECK_API_KEY] || null;
      this.initialized = true;

      if (!this.qwenApiKey) {
        console.warn(`${LOG_PREFIX} Qwen API key not configured — pipeline will not function`);
      }

      console.log(`${LOG_PREFIX} Pipeline initialized. Keys: Qwen=${!!this.qwenApiKey}, Tavily=${!!this.tavilyApiKey}, Google=${!!this.googleApiKey}`);
    } catch (error) {
      console.error(`${LOG_PREFIX} Failed to initialize pipeline:`, error);
    }
  }

  /**
   * Registers a status callback function.
   * @param {function(string, *): void} fn - Callback receiving (status, data)
   */
  setStatusCallback(fn) {
    this.statusCallback = fn;
  }

  /**
   * Emits a status update via the registered callback.
   */
  _emitStatus(state, data = null) {
    if (this.statusCallback) {
      this.statusCallback(state, data);
    }
  }

  /**
   * Runs the full pipeline on a text block:
   * Extract claims → for each claim: gather evidence → synthesize verdict.
   * @param {string} text - The text to fact-check
   * @returns {Promise<{claims: Array}>}
   */
  async checkText(text) {
    if (!this.initialized) {
      await this.initialize();
    }

    if (!this.qwenApiKey) {
      this._emitStatus(PIPELINE_STATES.ERROR, { message: "Qwen API key not configured. Please set your API keys in the extension options." });
      return { claims: [] };
    }

    try {
      // Step 1: Extract claims
      this._emitStatus(PIPELINE_STATES.EXTRACTING, { text: text.substring(0, 100) });
      console.log(`${LOG_PREFIX} Extracting claims from text (${text.length} chars)`);

      const claims = await extractClaims(text, this.qwenApiKey);

      if (!claims || claims.length === 0) {
        console.log(`${LOG_PREFIX} No verifiable claims extracted`);
        this._emitStatus(PIPELINE_STATES.COMPLETE, { claims: [] });
        return { claims: [] };
      }

      console.log(`${LOG_PREFIX} Extracted ${claims.length} claims`);
      this._emitStatus(PIPELINE_STATES.SEARCHING, { claimCount: claims.length });

      // Step 2 & 3: For each claim, gather evidence and synthesize verdict
      const results = [];
      for (const claim of claims) {
        const result = await this._processClaim(claim);
        results.push(result);
      }

      this._emitStatus(PIPELINE_STATES.COMPLETE, { claims: results });
      console.log(`${LOG_PREFIX} Pipeline complete. Processed ${results.length} claims.`);

      return { claims: results };
    } catch (error) {
      console.error(`${LOG_PREFIX} Pipeline error:`, error);
      this._emitStatus(PIPELINE_STATES.ERROR, { message: error.message });
      return { claims: [] };
    }
  }

  /**
   * Checks a single claim directly (skips extraction step).
   * @param {string} claimText - The claim text to verify
   * @returns {Promise<{text: string, verdict: string, confidence: number, reasoning: string, sources: Array}>}
   */
  async checkClaim(claimText) {
    if (!this.initialized) {
      await this.initialize();
    }

    if (!this.qwenApiKey) {
      this._emitStatus(PIPELINE_STATES.ERROR, { message: "Qwen API key not configured." });
      return null;
    }

    const claim = { text: claimText, checkWorthiness: "high", originalContext: claimText };
    this._emitStatus(PIPELINE_STATES.SEARCHING, { claimCount: 1 });

    const result = await this._processClaim(claim);
    this._emitStatus(PIPELINE_STATES.COMPLETE, { claims: [result] });

    return result;
  }

  /**
   * Processes a single claim: gather evidence from all sources, then synthesize verdict.
   * @param {{text: string, checkWorthiness: string, originalContext: string}} claim
   * @returns {Promise<{text: string, checkWorthiness: string, verdict: string, confidence: number, reasoning: string, sources: Array}>}
   */
  async _processClaim(claim) {
    console.log(`${LOG_PREFIX} Processing claim: "${claim.text.substring(0, 80)}..."`);

    // Gather evidence from all sources in parallel
    const evidencePromises = [
      this.tavilyApiKey ? searchEvidence(claim.text, this.tavilyApiKey) : Promise.resolve([]),
      this.googleApiKey ? searchFactChecks(claim.text, this.googleApiKey) : Promise.resolve([]),
    ];

    const settled = await Promise.allSettled(evidencePromises);

    // Collect results
    const tavilyResults = settled[0].status === "fulfilled" ? settled[0].value : [];
    const googleResults = settled[1].status === "fulfilled" ? settled[1].value : [];

    // Normalize Google results to same shape as Tavily
    const normalizedGoogle = googleResults.map((r) => ({
      title: r.text || "Fact Check",
      url: r.reviewUrl || "",
      content: `Rating: ${r.rating}. Publisher: ${r.publisher}. Review date: ${r.reviewDate}`,
      score: 0.9,
      source: r.publisher,
    }));

    // Merge and deduplicate by URL
    const allEvidence = [...tavilyResults, ...normalizedGoogle];
    const seen = new Set();
    const dedupedEvidence = allEvidence.filter((e) => {
      if (!e.url || seen.has(e.url)) return false;
      seen.add(e.url);
      return true;
    });

    // Limit to MAX_SOURCES
    const evidence = dedupedEvidence.slice(0, MAX_SOURCES);
    console.log(`${LOG_PREFIX} Gathered ${evidence.length} evidence sources for claim`);

    // Synthesize verdict
    this._emitStatus(PIPELINE_STATES.VERIFYING, { claim: claim.text });

    let verdict = null;
    if (evidence.length > 0) {
      verdict = await synthesizeVerdict(claim.text, evidence, this.qwenApiKey);
    }

    return {
      text: claim.text,
      checkWorthiness: claim.checkWorthiness,
      verdict: verdict?.verdict || "UNVERIFIABLE",
      confidence: verdict?.confidence || 0,
      reasoning: verdict?.reasoning || "Insufficient evidence to verify this claim.",
      sources: evidence.map((e) => ({
        title: e.title,
        url: e.url,
        content: e.content?.substring(0, 300) || "",
        source: e.source || new URL(e.url).hostname,
      })),
      sourceAnalysis: verdict?.sourceAnalysis || [],
    };
  }
}

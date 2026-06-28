// FactShield Chrome Extension — Qwen API Integration
import { QWEN_BASE_URL } from "../shared/constants.js";

const LOG_PREFIX = "[FactShield]";
const MAX_RETRIES = 3;

/**
 * Sleep helper for exponential backoff.
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Performs a fetch with retry logic for rate limiting (429).
 */
async function fetchWithRetry(url, options, retries = MAX_RETRIES) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    const response = await fetch(url, options);

    if (response.status === 429 && attempt < retries) {
      const backoff = Math.pow(2, attempt) * 1000;
      console.warn(`${LOG_PREFIX} Rate limited (429). Retrying in ${backoff}ms (attempt ${attempt + 1}/${retries})`);
      await sleep(backoff);
      continue;
    }

    return response;
  }
}

/**
 * Extracts verifiable factual claims from text using Qwen.
 * @param {string} text - The text to extract claims from
 * @param {string} apiKey - Qwen API key
 * @returns {Promise<Array<{text: string, checkWorthiness: string, originalContext: string}>>}
 */
export async function extractClaims(text, apiKey) {
  if (!apiKey) {
    console.error(`${LOG_PREFIX} Qwen API key not configured`);
    return [];
  }

  try {
    const response = await fetchWithRetry(`${QWEN_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "qwen-plus",
        temperature: 0.1,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "You are a fact-checking claim extraction assistant. Your task is to identify specific, verifiable factual claims from the given text. Only extract claims that can be objectively verified - ignore opinions, predictions, questions, and vague statements. Return only valid JSON.",
          },
          {
            role: "user",
            content: `Extract all verifiable factual claims from the following text. For each claim, assess its check-worthiness (high, medium, or low). Only include claims rated 'high' or 'medium'.\n\nText: ${text}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      console.error(`${LOG_PREFIX} Qwen extractClaims failed with status ${response.status}`);
      return [];
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;

    if (!content) {
      console.warn(`${LOG_PREFIX} No content in Qwen response`);
      return [];
    }

    const parsed = JSON.parse(content);
    const claims = parsed.claims || parsed.results || (Array.isArray(parsed) ? parsed : []);

    return claims.map((claim) => ({
      text: claim.text || claim.claim || "",
      checkWorthiness: claim.checkWorthiness || claim.check_worthiness || "medium",
      originalContext: claim.originalContext || claim.original_context || text.substring(0, 200),
    }));
  } catch (error) {
    console.error(`${LOG_PREFIX} Error extracting claims:`, error);
    return [];
  }
}

/**
 * Synthesizes a verdict for a claim based on gathered evidence.
 * @param {string} claim - The claim text to verify
 * @param {Array<{title: string, url: string, content: string, source?: string}>} evidence - Evidence array
 * @param {string} apiKey - Qwen API key
 * @returns {Promise<{verdict: string, confidence: number, reasoning: string, sourceAnalysis: Array}|null>}
 */
export async function synthesizeVerdict(claim, evidence, apiKey) {
  if (!apiKey) {
    console.error(`${LOG_PREFIX} Qwen API key not configured`);
    return null;
  }

  try {
    const formattedEvidence = evidence
      .map(
        (e, i) =>
          `Source ${i + 1}:\n  Title: ${e.title}\n  URL: ${e.url}\n  Content: ${e.content}\n  Publisher: ${e.source || "Unknown"}`
      )
      .join("\n\n");

    const userPrompt = `Verify the following claim against the provided evidence sources.

Claim: "${claim}"

Evidence:
${formattedEvidence}

Analyze the evidence and return a JSON object with:
- "verdict": one of "TRUE", "SUBSTANTIALLY_TRUE", "MISLEADING", "FALSE", "UNVERIFIABLE"
- "confidence": a number between 0 and 1 indicating confidence in the verdict
- "reasoning": a clear explanation of why you reached this verdict
- "sourceAnalysis": an array of objects, each with "sourceName", "supportsClaim" (boolean), and "credibility" (high/medium/low)`;

    const response = await fetchWithRetry(`${QWEN_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "qwen-max",
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "You are an expert fact-checker and verification analyst. Analyze claims against provided evidence with rigorous objectivity. Consider source credibility, recency, and consensus. Be transparent about uncertainty. Return only valid JSON.",
          },
          {
            role: "user",
            content: userPrompt,
          },
        ],
      }),
    });

    if (!response.ok) {
      console.error(`${LOG_PREFIX} Qwen synthesizeVerdict failed with status ${response.status}`);
      return null;
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;

    if (!content) {
      console.warn(`${LOG_PREFIX} No content in Qwen verdict response`);
      return null;
    }

    const parsed = JSON.parse(content);
    return {
      verdict: parsed.verdict || "UNVERIFIABLE",
      confidence: typeof parsed.confidence === "number" ? parsed.confidence : 0.5,
      reasoning: parsed.reasoning || "Unable to determine reasoning.",
      sourceAnalysis: parsed.sourceAnalysis || parsed.source_analysis || [],
    };
  } catch (error) {
    console.error(`${LOG_PREFIX} Error synthesizing verdict:`, error);
    return null;
  }
}

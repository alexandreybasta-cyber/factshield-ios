// FactShield Chrome Extension — Tavily Search API Integration
import { TAVILY_BASE_URL } from "../shared/constants.js";

const LOG_PREFIX = "[FactShield]";

/**
 * Searches for evidence related to a claim using Tavily.
 * @param {string} query - The search query (claim text)
 * @param {string} apiKey - Tavily API key
 * @returns {Promise<Array<{title: string, url: string, content: string, score: number, publishedDate: string}>>}
 */
export async function searchEvidence(query, apiKey) {
  if (!apiKey) {
    console.warn(`${LOG_PREFIX} Tavily API key not configured, skipping search`);
    return [];
  }

  try {
    const response = await fetch(`${TAVILY_BASE_URL}/search`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        api_key: apiKey,
        query,
        search_depth: "advanced",
        include_answer: false,
        max_results: 5,
      }),
    });

    if (!response.ok) {
      console.error(`${LOG_PREFIX} Tavily search failed with status ${response.status}`);
      return [];
    }

    const data = await response.json();
    const results = data.results || [];

    return results.map((result) => ({
      title: result.title || "",
      url: result.url || "",
      content: result.content || "",
      score: result.score || 0,
      publishedDate: result.published_date || result.publishedDate || "",
    }));
  } catch (error) {
    console.error(`${LOG_PREFIX} Error searching Tavily:`, error);
    return [];
  }
}

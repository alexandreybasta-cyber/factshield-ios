// FactShield Chrome Extension — Google Fact Check Tools API Integration
import { GOOGLE_FACTCHECK_URL } from "../shared/constants.js";

const LOG_PREFIX = "[FactShield]";

/**
 * Searches for existing fact-checks related to a claim using Google Fact Check Tools API.
 * @param {string} query - The claim text to search for
 * @param {string} apiKey - Google Fact Check Tools API key
 * @returns {Promise<Array<{text: string, reviewUrl: string, publisher: string, rating: string, reviewDate: string}>>}
 */
export async function searchFactChecks(query, apiKey) {
  if (!apiKey) {
    console.warn(`${LOG_PREFIX} Google Fact Check API key not configured, skipping`);
    return [];
  }

  try {
    const url = `${GOOGLE_FACTCHECK_URL}?query=${encodeURIComponent(query)}&key=${apiKey}&pageSize=5`;
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      console.error(`${LOG_PREFIX} Google Fact Check search failed with status ${response.status}`);
      return [];
    }

    const data = await response.json();
    const claims = data.claims || [];

    return claims.map((claim) => {
      const review = claim.claimReview?.[0] || {};
      return {
        text: claim.text || "",
        reviewUrl: review.url || "",
        publisher: review.publisher?.name || review.publisher?.site || "Unknown",
        rating: review.textualRating || "",
        reviewDate: review.reviewDate || "",
      };
    });
  } catch (error) {
    console.error(`${LOG_PREFIX} Error searching Google Fact Check:`, error);
    return [];
  }
}

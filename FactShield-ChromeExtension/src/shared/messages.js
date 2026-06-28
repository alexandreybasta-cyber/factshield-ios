// FactShield Chrome Extension — Message Types & Helpers

// Content Script → Background
export const MSG_TYPES = Object.freeze({
  // Content → Background
  TEXT_EXTRACTED: "TEXT_EXTRACTED",
  CAPTION_UPDATE: "CAPTION_UPDATE",
  PAGE_CONTEXT: "PAGE_CONTEXT",

  // Background → SidePanel
  PIPELINE_STATUS: "PIPELINE_STATUS",
  CLAIM_EXTRACTED: "CLAIM_EXTRACTED",
  VERDICT_READY: "VERDICT_READY",
  ERROR: "ERROR",

  // SidePanel → Background
  START_FACTCHECK: "START_FACTCHECK",
  STOP_FACTCHECK: "STOP_FACTCHECK",
  CHECK_TEXT: "CHECK_TEXT",
  GET_STATE: "GET_STATE",

  // Background → Content
  HIGHLIGHT_CLAIMS: "HIGHLIGHT_CLAIMS",
  START_CAPTURE: "START_CAPTURE",
  STOP_CAPTURE: "STOP_CAPTURE",
});

/**
 * Creates a standardized message object.
 * @param {string} type - One of MSG_TYPES values
 * @param {*} payload - Arbitrary payload data
 * @returns {{type: string, payload: *, timestamp: number}}
 */
export function createMessage(type, payload) {
  return {
    type,
    payload,
    timestamp: Date.now(),
  };
}

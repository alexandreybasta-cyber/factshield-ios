// FactShield Chrome Extension — Shared Constants

export const QWEN_BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1";
export const TAVILY_BASE_URL = "https://api.tavily.com";
export const GOOGLE_FACTCHECK_URL = "https://factchecktools.googleapis.com/v1alpha1/claims:search";

export const EXTRACTION_INTERVAL_MS = 15000;
export const MAX_TRANSCRIPT_WORDS = 2000;
export const RECENT_WINDOW_WORDS = 75;
export const MIN_SOURCES = 3;
export const MAX_SOURCES = 5;

export const VERDICTS = Object.freeze({
  TRUE: "TRUE",
  SUBSTANTIALLY_TRUE: "SUBSTANTIALLY_TRUE",
  MISLEADING: "MISLEADING",
  FALSE: "FALSE",
  UNVERIFIABLE: "UNVERIFIABLE",
});

export const PIPELINE_STATES = Object.freeze({
  IDLE: "IDLE",
  CAPTURING: "CAPTURING",
  EXTRACTING: "EXTRACTING",
  SEARCHING: "SEARCHING",
  VERIFYING: "VERIFYING",
  COMPLETE: "COMPLETE",
  ERROR: "ERROR",
});

export const STORAGE_KEYS = Object.freeze({
  QWEN_API_KEY: "qwen_api_key",
  TAVILY_API_KEY: "tavily_api_key",
  GOOGLE_FACTCHECK_API_KEY: "google_factcheck_api_key",
  SETTINGS: "factshield_settings",
  CLAIM_HISTORY: "factshield_history",
});

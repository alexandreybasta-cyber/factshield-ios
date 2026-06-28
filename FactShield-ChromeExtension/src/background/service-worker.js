// FactShield Chrome Extension — Background Service Worker
import { PIPELINE_STATES } from "../shared/constants.js";
import { MSG_TYPES, createMessage } from "../shared/messages.js";
import { FactCheckPipeline } from "../api/pipeline.js";

const LOG_PREFIX = "[FactShield]";

// --- State ---
const state = {
  isActive: false,
  currentTab: null,
  pipelineState: PIPELINE_STATES.IDLE,
  claims: [],
  verdicts: [],
};

// Pipeline instance
const pipeline = new FactCheckPipeline();

// --- Lifecycle Events ---

chrome.runtime.onInstalled.addListener(async (details) => {
  console.log(`${LOG_PREFIX} Extension installed (reason: ${details.reason})`);

  // Set side panel to open on action click
  if (chrome.sidePanel?.setPanelBehavior) {
    await chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
  }

  // Initialize pipeline
  await pipeline.initialize();
});

// Open side panel when action icon is clicked
chrome.action.onClicked.addListener(async (tab) => {
  console.log(`${LOG_PREFIX} Action clicked on tab ${tab.id}`);
  if (chrome.sidePanel?.open) {
    await chrome.sidePanel.open({ tabId: tab.id });
  }
});

// --- Message Routing ---

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log(`${LOG_PREFIX} Message received:`, message.type);

  // Handle async responses
  handleMessage(message, sender)
    .then((response) => sendResponse(response))
    .catch((error) => {
      console.error(`${LOG_PREFIX} Error handling message:`, error);
      sendResponse({ error: error.message });
    });

  // Return true to indicate async response
  return true;
});

/**
 * Routes incoming messages to appropriate handlers.
 */
async function handleMessage(message, sender) {
  switch (message.type) {
    case MSG_TYPES.START_FACTCHECK:
      return handleStartFactCheck(sender);

    case MSG_TYPES.STOP_FACTCHECK:
      return handleStopFactCheck();

    case MSG_TYPES.CHECK_TEXT:
      return handleCheckText(message.payload);

    case MSG_TYPES.TEXT_EXTRACTED:
      return handleTextExtracted(message.payload, sender);

    case MSG_TYPES.CAPTION_UPDATE:
      return handleTextExtracted(message.payload, sender);

    case MSG_TYPES.GET_STATE:
      return { ...state };

    default:
      console.warn(`${LOG_PREFIX} Unknown message type: ${message.type}`);
      return { error: "Unknown message type" };
  }
}

/**
 * Starts fact-checking on the current active tab.
 */
async function handleStartFactCheck(sender) {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab) {
      return { error: "No active tab found" };
    }

    state.isActive = true;
    state.currentTab = tab.id;
    state.pipelineState = PIPELINE_STATES.CAPTURING;
    state.claims = [];
    state.verdicts = [];

    // Ensure pipeline is initialized
    if (!pipeline.initialized) {
      await pipeline.initialize();
    }

    // Set up status callback
    pipeline.setStatusCallback((status, data) => {
      state.pipelineState = status;
      broadcastToSidePanel(createMessage(MSG_TYPES.PIPELINE_STATUS, { state: status, ...data }));
    });

    // Send START_CAPTURE to the content script
    await chrome.tabs.sendMessage(tab.id, createMessage(MSG_TYPES.START_CAPTURE, {}));

    console.log(`${LOG_PREFIX} Fact-checking started on tab ${tab.id}`);
    broadcastToSidePanel(createMessage(MSG_TYPES.PIPELINE_STATUS, { state: PIPELINE_STATES.CAPTURING }));

    return { success: true, tabId: tab.id };
  } catch (error) {
    console.error(`${LOG_PREFIX} Error starting fact-check:`, error);
    state.pipelineState = PIPELINE_STATES.ERROR;
    return { error: error.message };
  }
}

/**
 * Stops the current fact-checking session.
 */
async function handleStopFactCheck() {
  try {
    if (state.currentTab) {
      await chrome.tabs.sendMessage(state.currentTab, createMessage(MSG_TYPES.STOP_CAPTURE, {}));
    }
  } catch (e) {
    // Tab may have been closed
    console.warn(`${LOG_PREFIX} Could not send stop to tab:`, e.message);
  }

  state.isActive = false;
  state.currentTab = null;
  state.pipelineState = PIPELINE_STATES.IDLE;

  console.log(`${LOG_PREFIX} Fact-checking stopped`);
  broadcastToSidePanel(createMessage(MSG_TYPES.PIPELINE_STATUS, { state: PIPELINE_STATES.IDLE }));

  return { success: true };
}

/**
 * Runs the pipeline on provided text (manual fact-check).
 */
async function handleCheckText(payload) {
  const text = payload?.text;
  if (!text) {
    return { error: "No text provided" };
  }

  if (!pipeline.initialized) {
    await pipeline.initialize();
  }

  pipeline.setStatusCallback((status, data) => {
    state.pipelineState = status;
    broadcastToSidePanel(createMessage(MSG_TYPES.PIPELINE_STATUS, { state: status, ...data }));
  });

  console.log(`${LOG_PREFIX} Running pipeline on manual text (${text.length} chars)`);
  const result = await pipeline.checkText(text);

  state.claims = result.claims;
  state.pipelineState = PIPELINE_STATES.COMPLETE;

  // Send verdicts to side panel
  broadcastToSidePanel(createMessage(MSG_TYPES.VERDICT_READY, { claims: result.claims }));

  // Highlight claims in the content tab if active
  if (state.currentTab) {
    try {
      await chrome.tabs.sendMessage(
        state.currentTab,
        createMessage(MSG_TYPES.HIGHLIGHT_CLAIMS, { claims: result.claims })
      );
    } catch (e) {
      console.warn(`${LOG_PREFIX} Could not highlight claims in tab:`, e.message);
    }
  }

  return { success: true, claims: result.claims };
}

/**
 * Handles text extracted by the content script.
 */
async function handleTextExtracted(payload, sender) {
  if (!state.isActive) {
    return { ignored: true, reason: "not active" };
  }

  const text = payload?.text;
  if (!text || text.trim().length < 50) {
    return { ignored: true, reason: "text too short" };
  }

  if (!pipeline.initialized) {
    await pipeline.initialize();
  }

  pipeline.setStatusCallback((status, data) => {
    state.pipelineState = status;
    broadcastToSidePanel(createMessage(MSG_TYPES.PIPELINE_STATUS, { state: status, ...data }));
  });

  console.log(`${LOG_PREFIX} Processing extracted text from tab (${text.length} chars)`);
  const result = await pipeline.checkText(text);

  if (result.claims.length > 0) {
    state.claims = [...state.claims, ...result.claims];

    // Notify side panel
    broadcastToSidePanel(createMessage(MSG_TYPES.VERDICT_READY, { claims: result.claims }));

    // Highlight in content
    const tabId = sender?.tab?.id || state.currentTab;
    if (tabId) {
      try {
        await chrome.tabs.sendMessage(
          tabId,
          createMessage(MSG_TYPES.HIGHLIGHT_CLAIMS, { claims: result.claims })
        );
      } catch (e) {
        console.warn(`${LOG_PREFIX} Could not highlight claims:`, e.message);
      }
    }
  }

  return { success: true, claimsFound: result.claims.length };
}

/**
 * Broadcasts a message to all extension views (side panels, popups).
 */
function broadcastToSidePanel(message) {
  chrome.runtime.sendMessage(message).catch(() => {
    // No listeners — side panel might not be open
  });
}

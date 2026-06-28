// FactShield Chrome Extension — Content Script (Text Extractor)
// Runs on matched pages to extract text content for fact-checking.

const LOG_PREFIX = "[FactShield]";

// --- State ---
let isCapturing = false;
let extractionInterval = null;
let observer = null;
let lastExtractedText = "";

// --- Platform Detection ---

function detectPlatform() {
  const url = window.location.href;
  if (url.includes("youtube.com")) return "youtube";
  if (url.includes("instagram.com")) return "instagram";
  if (url.includes("x.com") || url.includes("twitter.com")) return "twitter";
  if (url.includes("spotify.com")) return "spotify";
  return "generic";
}

// --- YouTube Extraction ---

function extractYouTubeCaptions() {
  // Try to get visible caption segments from the player
  const captionSegments = document.querySelectorAll(".ytp-caption-segment");
  if (captionSegments.length > 0) {
    return Array.from(captionSegments)
      .map((seg) => seg.textContent.trim())
      .filter(Boolean)
      .join(" ");
  }
  return "";
}

function extractYouTubeMetadata() {
  const title = document.querySelector("h1.ytd-video-primary-info-renderer yt-formatted-string")?.textContent
    || document.querySelector("h1.ytd-watch-metadata yt-formatted-string")?.textContent
    || document.title || "";

  const description = document.querySelector("#description-inline-expander yt-formatted-string")?.textContent
    || document.querySelector("#description yt-formatted-string")?.textContent
    || "";

  return { title: title.trim(), description: description.trim() };
}

function extractYouTubeContent() {
  const captions = extractYouTubeCaptions();
  const metadata = extractYouTubeMetadata();

  let text = "";
  if (metadata.title) text += metadata.title + ". ";
  if (captions) text += captions;
  else if (metadata.description) text += metadata.description.substring(0, 2000);

  return text.trim();
}

// --- Generic Page Extraction ---

function extractGenericContent() {
  // Priority: <article>, [role="main"], main, largest text block
  const selectors = [
    "article",
    '[role="main"]',
    "main",
    ".post-content",
    ".article-content",
    ".entry-content",
    ".story-body",
    "#content",
  ];

  for (const selector of selectors) {
    const el = document.querySelector(selector);
    if (el) {
      const text = extractTextFromElement(el);
      if (text.length > 200) return text;
    }
  }

  // Fallback: find largest text block
  return extractLargestTextBlock();
}

function extractTextFromElement(element) {
  // Clone and remove unwanted elements
  const clone = element.cloneNode(true);
  const removeSelectors = [
    "nav", "header", "footer", "aside",
    "[role='navigation']", "[role='banner']", "[role='complementary']",
    ".ad", ".advertisement", ".sidebar", ".nav",
    "script", "style", "noscript", "iframe",
  ];

  removeSelectors.forEach((sel) => {
    clone.querySelectorAll(sel).forEach((el) => el.remove());
  });

  return clone.textContent
    .replace(/\s+/g, " ")
    .trim()
    .substring(0, 5000);
}

function extractLargestTextBlock() {
  const paragraphs = document.querySelectorAll("p");
  let bestBlock = "";
  let bestLength = 0;

  // Group adjacent paragraphs
  const blocks = [];
  let currentBlock = [];

  paragraphs.forEach((p) => {
    const text = p.textContent.trim();
    if (text.length > 30) {
      currentBlock.push(text);
    } else if (currentBlock.length > 0) {
      blocks.push(currentBlock.join(" "));
      currentBlock = [];
    }
  });
  if (currentBlock.length > 0) blocks.push(currentBlock.join(" "));

  for (const block of blocks) {
    if (block.length > bestLength) {
      bestLength = block.length;
      bestBlock = block;
    }
  }

  return bestBlock.substring(0, 5000);
}

// --- Twitter/X Extraction ---

function extractTwitterContent() {
  const tweets = document.querySelectorAll('[data-testid="tweetText"]');
  if (tweets.length === 0) return "";

  return Array.from(tweets)
    .slice(0, 10)
    .map((tweet) => tweet.textContent.trim())
    .filter((t) => t.length > 20)
    .join("\n\n");
}

// --- Instagram Extraction ---

function extractInstagramContent() {
  // Get post captions
  const captions = document.querySelectorAll("h1, span[class]");
  const texts = [];

  captions.forEach((el) => {
    const text = el.textContent.trim();
    if (text.length > 50 && text.length < 5000) {
      texts.push(text);
    }
  });

  return texts.slice(0, 5).join("\n\n");
}

// --- Page Context ---

function getPageContext() {
  return {
    url: window.location.href,
    title: document.title,
    platform: detectPlatform(),
    metaDescription: document.querySelector('meta[name="description"]')?.content || "",
  };
}

// --- Main Extraction ---

function extractContent() {
  const platform = detectPlatform();

  switch (platform) {
    case "youtube":
      return extractYouTubeContent();
    case "twitter":
      return extractTwitterContent();
    case "instagram":
      return extractInstagramContent();
    case "spotify":
      // Spotify web player doesn't expose lyrics easily
      return document.title || "";
    default:
      return extractGenericContent();
  }
}

// --- Selected Text ---

function getSelectedText() {
  return window.getSelection()?.toString()?.trim() || "";
}

// --- Highlighting ---

const VERDICT_COLORS = {
  TRUE: { bg: "rgba(34, 197, 94, 0.15)", border: "#22c55e" },
  SUBSTANTIALLY_TRUE: { bg: "rgba(163, 230, 53, 0.15)", border: "#a3e635" },
  MISLEADING: { bg: "rgba(249, 115, 22, 0.15)", border: "#f97316" },
  FALSE: { bg: "rgba(239, 68, 68, 0.15)", border: "#ef4444" },
  UNVERIFIABLE: { bg: "rgba(156, 163, 175, 0.15)", border: "#9ca3af" },
};

function highlightClaims(claims) {
  // Remove existing highlights
  document.querySelectorAll(".factshield-highlight").forEach((el) => {
    const parent = el.parentNode;
    parent.replaceChild(document.createTextNode(el.textContent), el);
    parent.normalize();
  });

  if (!claims || claims.length === 0) return;

  const bodyText = document.body.innerHTML;

  claims.forEach((claim) => {
    if (!claim.text || !claim.verdict) return;

    const colors = VERDICT_COLORS[claim.verdict] || VERDICT_COLORS.UNVERIFIABLE;

    // Find text nodes containing the claim text
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );

    const matchingNodes = [];
    let node;
    while ((node = walker.nextNode())) {
      if (node.textContent.includes(claim.text.substring(0, 40))) {
        matchingNodes.push(node);
      }
    }

    // Highlight first match only
    if (matchingNodes.length > 0) {
      const textNode = matchingNodes[0];
      const text = textNode.textContent;
      const shortClaim = claim.text.substring(0, 40);
      const idx = text.indexOf(shortClaim);

      if (idx >= 0) {
        const range = document.createRange();
        range.setStart(textNode, idx);
        range.setEnd(textNode, Math.min(idx + claim.text.length, text.length));

        const highlight = document.createElement("span");
        highlight.className = "factshield-highlight";
        highlight.style.cssText = `
          background: ${colors.bg};
          border-bottom: 2px solid ${colors.border};
          padding: 1px 2px;
          border-radius: 2px;
          position: relative;
          cursor: pointer;
        `;
        highlight.title = `FactShield: ${claim.verdict} (${Math.round((claim.confidence || 0) * 100)}% confidence)\n${claim.reasoning || ""}`;
        highlight.dataset.verdict = claim.verdict;
        highlight.dataset.confidence = claim.confidence || 0;

        try {
          range.surroundContents(highlight);
        } catch (e) {
          // Can fail if range spans multiple elements
          console.warn(`${LOG_PREFIX} Could not highlight claim:`, e.message);
        }
      }
    }
  });

  console.log(`${LOG_PREFIX} Highlighted ${claims.length} claims on page`);
}

// --- Capture Control ---

function startCapture() {
  if (isCapturing) return;
  isCapturing = true;

  console.log(`${LOG_PREFIX} Starting text capture on ${detectPlatform()}`);

  // Initial extraction
  performExtraction();

  // Set up interval for periodic extraction (15s)
  extractionInterval = setInterval(performExtraction, 15000);

  // Set up MutationObserver for YouTube captions
  if (detectPlatform() === "youtube") {
    setupYouTubeObserver();
  }
}

function stopCapture() {
  isCapturing = false;

  if (extractionInterval) {
    clearInterval(extractionInterval);
    extractionInterval = null;
  }

  if (observer) {
    observer.disconnect();
    observer = null;
  }

  console.log(`${LOG_PREFIX} Stopped text capture`);
}

function performExtraction() {
  const text = extractContent();

  // Avoid sending duplicate/unchanged text
  if (!text || text === lastExtractedText || text.length < 50) return;
  lastExtractedText = text;

  chrome.runtime.sendMessage({
    type: "TEXT_EXTRACTED",
    payload: { text, platform: detectPlatform(), context: getPageContext() },
    timestamp: Date.now(),
  }).catch(() => {
    // Background might not be ready
  });
}

function setupYouTubeObserver() {
  // Observe caption container for changes
  const captionContainer = document.querySelector(".caption-window") || document.querySelector(".ytp-caption-window-container");

  if (captionContainer) {
    observer = new MutationObserver(() => {
      if (!isCapturing) return;
      const captions = extractYouTubeCaptions();
      if (captions && captions !== lastExtractedText) {
        lastExtractedText = captions;
        chrome.runtime.sendMessage({
          type: "CAPTION_UPDATE",
          payload: { text: captions, platform: "youtube", context: getPageContext() },
          timestamp: Date.now(),
        }).catch(() => {});
      }
    });

    observer.observe(captionContainer, { childList: true, subtree: true, characterData: true });
    console.log(`${LOG_PREFIX} YouTube caption observer started`);
  } else {
    // Retry after a delay (captions may load later)
    setTimeout(() => {
      if (isCapturing) setupYouTubeObserver();
    }, 3000);
  }
}

// --- Message Listener ---

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  switch (message.type) {
    case "START_CAPTURE":
      startCapture();
      sendResponse({ success: true });
      break;

    case "STOP_CAPTURE":
      stopCapture();
      sendResponse({ success: true });
      break;

    case "HIGHLIGHT_CLAIMS":
      highlightClaims(message.payload?.claims || []);
      sendResponse({ success: true });
      break;

    default:
      break;
  }
  return true;
});

// --- Initialize ---
console.log(`${LOG_PREFIX} Content script loaded on ${detectPlatform()} — ${window.location.href}`);

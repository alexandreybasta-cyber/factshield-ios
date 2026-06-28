// FactShield Side Panel — Main Application Module

// ─── State ───────────────────────────────────────────────────────────────────
const state = {
  isActive: false,
  mode: 'live', // 'live' | 'manual'
  pipelineState: null, // EXTRACTING | SEARCHING | VERIFYING | COMPLETE | ERROR
  pipelineMessage: '',
  pipelineProgress: 0,
  claims: [],
  history: [],
  settings: {},
  error: null,
  hasApiKey: true,
  expandedCards: new Set(),
  expandedSources: new Set(),
  historyExpanded: false,
};

// ─── Verdict Config ──────────────────────────────────────────────────────────
const VERDICT_CONFIG = {
  TRUE: { label: 'Verified True', color: '#10B981', bg: 'bg-emerald-500/20', text: 'text-emerald-400', border: 'border-emerald-500/30' },
  SUBSTANTIALLY_TRUE: { label: 'Substantially True', color: '#14B8A6', bg: 'bg-teal-500/20', text: 'text-teal-400', border: 'border-teal-500/30' },
  MISLEADING: { label: 'Misleading', color: '#F59E0B', bg: 'bg-amber-500/20', text: 'text-amber-400', border: 'border-amber-500/30' },
  FALSE: { label: 'False', color: '#EF4444', bg: 'bg-red-500/20', text: 'text-red-400', border: 'border-red-500/30' },
  UNVERIFIABLE: { label: 'Unverifiable', color: '#6B7280', bg: 'bg-gray-500/20', text: 'text-gray-400', border: 'border-gray-500/30' },
};

// ─── Helpers ─────────────────────────────────────────────────────────────────
function getVerdictColor(verdict) {
  return VERDICT_CONFIG[verdict]?.color || '#6B7280';
}

function renderVerdictBadge(verdict) {
  const cfg = VERDICT_CONFIG[verdict] || VERDICT_CONFIG.UNVERIFIABLE;
  return `<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${cfg.bg} ${cfg.text} ${cfg.border} border">${cfg.label}</span>`;
}

function renderConfidenceMeter(confidence, verdict) {
  const color = getVerdictColor(verdict);
  return `
    <div class="flex items-center gap-2 mt-1.5">
      <div class="flex-1 h-1.5 bg-slate-700 rounded-full overflow-hidden">
        <div class="confidence-fill h-full rounded-full" style="--fill-width: ${confidence}%; background-color: ${color};"></div>
      </div>
      <span class="text-xs font-mono text-fs-muted w-8 text-right">${confidence}%</span>
    </div>`;
}

function renderSourceCard(source, idx) {
  const domain = source.url ? new URL(source.url).hostname.replace('www.', '') : 'Unknown';
  const supportsBadge = source.supportsClaim
    ? '<span class="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">Supports</span>'
    : '<span class="text-[10px] px-1.5 py-0.5 rounded bg-red-500/20 text-red-400 border border-red-500/30">Refutes</span>';
  const credWidth = Math.round((source.credibility || 0.5) * 100);
  return `
    <div class="flex flex-col gap-1 py-1.5 border-b border-slate-700/50 last:border-0">
      <div class="flex items-center justify-between gap-2">
        <a href="${source.url || '#'}" target="_blank" rel="noopener" class="text-xs text-fs-accent hover:underline truncate flex-1">${domain}</a>
        ${supportsBadge}
      </div>
      <p class="text-[11px] text-fs-muted line-clamp-2">${source.title || ''}</p>
      <div class="flex items-center gap-1.5">
        <span class="text-[10px] text-slate-500">Credibility</span>
        <div class="flex-1 h-1 bg-slate-700 rounded-full max-w-[60px]">
          <div class="h-full rounded-full bg-fs-accent/70" style="width:${credWidth}%"></div>
        </div>
      </div>
    </div>`;
}

function formatTimestamp(ts) {
  if (!ts) return '';
  const diff = Math.floor((Date.now() - new Date(ts).getTime()) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(ts).toLocaleDateString();
}

function escapeHtml(text) {
  const d = document.createElement('div');
  d.textContent = text;
  return d.innerHTML;
}

// ─── Communication ───────────────────────────────────────────────────────────
function sendMessage(type, payload = {}) {
  try {
    chrome.runtime.sendMessage({ type, payload });
  } catch (e) {
    console.warn('[FactShield] sendMessage failed:', e);
  }
}

function initMessageListener() {
  try {
    chrome.runtime.onMessage.addListener((message) => {
      handleBackgroundMessage(message);
    });
  } catch (e) {
    console.warn('[FactShield] Message listener init failed:', e);
  }
}

function handleBackgroundMessage(msg) {
  switch (msg.type) {
    case 'PIPELINE_STATUS':
      state.pipelineState = msg.payload.state;
      state.pipelineMessage = msg.payload.message || '';
      state.pipelineProgress = msg.payload.progress || 0;
      if (msg.payload.state === 'COMPLETE') state.isActive = false;
      if (msg.payload.state === 'ERROR') {
        state.error = msg.payload.message;
        state.isActive = false;
      }
      break;
    case 'CLAIM_EXTRACTED':
      if (msg.payload.claims) {
        msg.payload.claims.forEach(c => {
          if (!state.claims.find(ec => ec.text === c.text)) {
            state.claims.unshift({ ...c, timestamp: Date.now() });
          }
        });
      }
      break;
    case 'VERDICT_READY':
      if (msg.payload.claims) {
        msg.payload.claims.forEach(vc => {
          const idx = state.claims.findIndex(c => c.text === vc.text);
          if (idx !== -1) {
            state.claims[idx] = { ...state.claims[idx], ...vc, timestamp: state.claims[idx].timestamp || Date.now() };
          } else {
            state.claims.unshift({ ...vc, timestamp: Date.now() });
          }
        });
      }
      break;
    case 'ERROR':
      state.error = msg.payload.message;
      state.pipelineState = 'ERROR';
      break;
  }
  render();
}

// ─── Actions ─────────────────────────────────────────────────────────────────
function startFactCheck() {
  state.isActive = true;
  state.pipelineState = 'EXTRACTING';
  state.error = null;
  state.claims = [];
  sendMessage('START_FACTCHECK');
  render();
}

function stopFactCheck() {
  state.isActive = false;
  state.pipelineState = null;
  sendMessage('STOP_FACTCHECK');
  render();
}

function checkText() {
  const textarea = document.getElementById('manual-input');
  const text = textarea?.value?.trim();
  if (!text) return;
  state.isActive = true;
  state.pipelineState = 'EXTRACTING';
  state.error = null;
  state.claims = [];
  sendMessage('CHECK_TEXT', { text });
  render();
}

function toggleCard(id) {
  state.expandedCards.has(id) ? state.expandedCards.delete(id) : state.expandedCards.add(id);
  render();
}

function toggleSources(id) {
  state.expandedSources.has(id) ? state.expandedSources.delete(id) : state.expandedSources.add(id);
  render();
}

function copyVerdict(claim) {
  const cfg = VERDICT_CONFIG[claim.verdict] || VERDICT_CONFIG.UNVERIFIABLE;
  const text = `[${cfg.label}] "${claim.text}"\nConfidence: ${claim.confidence}%\nReasoning: ${claim.reasoning || 'N/A'}`;
  navigator.clipboard.writeText(text).then(() => showToast('Copied to clipboard'));
}

function openOptions() {
  try {
    chrome.runtime.openOptionsPage();
  } catch (e) {
    window.open(chrome.runtime.getURL('src/options/index.html'));
  }
}

function switchMode(mode) {
  state.mode = mode;
  render();
}

function toggleHistory() {
  state.historyExpanded = !state.historyExpanded;
  render();
}

function showToast(message) {
  const existing = document.getElementById('toast');
  if (existing) existing.remove();
  const toast = document.createElement('div');
  toast.id = 'toast';
  toast.className = 'fixed top-2 left-1/2 -translate-x-1/2 bg-slate-700 text-white text-xs px-3 py-1.5 rounded-lg shadow-lg toast-enter z-50';
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => { toast.classList.replace('toast-enter', 'toast-exit'); setTimeout(() => toast.remove(), 300); }, 2000);
}

// ─── Render Functions ────────────────────────────────────────────────────────
function renderHeader() {
  const statusDot = state.isActive
    ? '<span class="w-2 h-2 rounded-full bg-fs-true animate-blink"></span>'
    : '<span class="w-2 h-2 rounded-full bg-slate-500"></span>';
  const statusText = state.isActive ? 'Monitoring' : 'Idle';
  return `
    <header class="flex items-center justify-between px-4 py-3 border-b border-fs-border bg-fs-bg/95 backdrop-blur-sm sticky top-0 z-40">
      <div class="flex items-center gap-2.5">
        <div class="w-7 h-7 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-lg flex items-center justify-center text-sm shadow-md">🛡️</div>
        <div>
          <h1 class="text-sm font-bold leading-none tracking-tight">FactShield</h1>
          <div class="flex items-center gap-1.5 mt-0.5">
            ${statusDot}
            <span class="text-[11px] text-fs-muted">${statusText}</span>
          </div>
        </div>
      </div>
      <button onclick="openOptions()" class="p-1.5 rounded-lg hover:bg-slate-700/50 transition-colors" title="Settings">
        <svg class="w-4.5 h-4.5 text-fs-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
      </button>
    </header>`;
}

function renderControls() {
  const liveActive = state.mode === 'live' ? 'bg-fs-accent text-white' : 'text-fs-muted hover:text-white';
  const manualActive = state.mode === 'manual' ? 'bg-fs-accent text-white' : 'text-fs-muted hover:text-white';

  let controlContent = '';
  if (state.mode === 'live') {
    if (state.isActive) {
      controlContent = `
        <button onclick="stopFactCheck()" class="btn-press w-full py-2.5 px-4 bg-red-500/20 hover:bg-red-500/30 text-red-400 border border-red-500/30 rounded-xl font-medium text-sm transition-all flex items-center justify-center gap-2">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="1" stroke-width="2"/></svg>
          Stop Monitoring
        </button>`;
    } else {
      controlContent = `
        <button onclick="startFactCheck()" class="btn-press w-full py-2.5 px-4 bg-fs-accent hover:bg-blue-600 text-white rounded-xl font-medium text-sm transition-all shadow-lg shadow-blue-500/20 flex items-center justify-center gap-2 glow-active">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
          Start Fact-Checking
        </button>`;
    }
  } else {
    controlContent = `
      <textarea id="manual-input" placeholder="Paste text to fact-check..." class="w-full h-20 bg-slate-800/50 border border-fs-border rounded-xl px-3 py-2 text-sm text-fs-text placeholder-slate-500 resize-none focus:outline-none focus:border-fs-accent/50 focus:ring-1 focus:ring-fs-accent/20 transition-all"></textarea>
      <button onclick="checkText()" class="btn-press w-full py-2.5 px-4 bg-fs-accent hover:bg-blue-600 text-white rounded-xl font-medium text-sm transition-all mt-2 flex items-center justify-center gap-2">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/></svg>
        Check This Text
      </button>`;
  }

  return `
    <section class="px-4 py-3 border-b border-fs-border">
      <div class="flex bg-slate-800/50 rounded-lg p-0.5 mb-3">
        <button onclick="switchMode('live')" class="flex-1 py-1.5 px-3 rounded-md text-xs font-medium transition-all ${liveActive}">Live Monitor</button>
        <button onclick="switchMode('manual')" class="flex-1 py-1.5 px-3 rounded-md text-xs font-medium transition-all ${manualActive}">Manual Check</button>
      </div>
      ${controlContent}
    </section>`;
}

function renderPipeline() {
  if (!state.pipelineState || state.pipelineState === 'COMPLETE') return '';
  if (state.pipelineState === 'ERROR') return '';

  const statusMessages = {
    EXTRACTING: 'Extracting claims...',
    SEARCHING: 'Searching evidence...',
    VERIFYING: 'Cross-checking sources...',
  };
  const msg = state.pipelineMessage || statusMessages[state.pipelineState] || 'Processing...';

  return `
    <section class="px-4 py-3 border-b border-fs-border animate-fade-in">
      <div class="flex items-center gap-2 mb-2">
        <div class="w-4 h-4 border-2 border-fs-accent border-t-transparent rounded-full animate-spin-slow"></div>
        <span class="text-xs text-fs-muted">${escapeHtml(msg)}</span>
      </div>
      <div class="h-1.5 bg-slate-700 rounded-full overflow-hidden">
        <div class="progress-gradient h-full rounded-full transition-all duration-500" style="width: ${state.pipelineProgress}%"></div>
      </div>
    </section>`;
}

function renderVerdictCards() {
  if (state.claims.length === 0) return '';
  return `
    <section class="flex-1 overflow-y-auto custom-scrollbar px-4 py-3 space-y-3">
      ${state.claims.map((claim, i) => renderSingleCard(claim, i)).join('')}
    </section>`;
}

function renderSingleCard(claim, idx) {
  const id = `claim-${idx}`;
  const hasVerdict = !!claim.verdict;
  const isExpanded = state.expandedCards.has(id);
  const sourcesExpanded = state.expandedSources.has(id);

  if (!hasVerdict) {
    return `
      <div class="verdict-card bg-fs-card border border-fs-border rounded-xl p-3 animate-slide-in">
        <div class="flex items-start gap-2">
          <div class="w-3 h-3 mt-0.5 rounded-full shimmer shrink-0"></div>
          <div class="flex-1">
            <p class="text-xs text-fs-text leading-relaxed">${escapeHtml(claim.text)}</p>
            <p class="text-[11px] text-fs-muted mt-1 italic">Verifying...</p>
          </div>
        </div>
      </div>`;
  }

  const reasoning = claim.reasoning || '';
  const shortReasoning = reasoning.length > 100 ? reasoning.slice(0, 100) + '...' : reasoning;
  const sources = claim.sources || [];

  return `
    <div class="verdict-card bg-fs-card border border-fs-border rounded-xl p-3 animate-slide-in">
      <div class="flex items-start justify-between gap-2 mb-2">
        ${renderVerdictBadge(claim.verdict)}
        <span class="text-[10px] text-slate-500 shrink-0">${formatTimestamp(claim.timestamp)}</span>
      </div>
      <p class="text-xs text-fs-text leading-relaxed mb-2">${escapeHtml(claim.text)}</p>
      ${renderConfidenceMeter(claim.confidence || 0, claim.verdict)}
      
      <!-- Reasoning -->
      <div class="mt-2.5">
        <p class="text-[11px] text-fs-muted leading-relaxed">${isExpanded ? escapeHtml(reasoning) : escapeHtml(shortReasoning)}</p>
        ${reasoning.length > 100 ? `<button onclick="toggleCard('${id}')" class="text-[10px] text-fs-accent hover:underline mt-0.5">${isExpanded ? 'Show less' : 'Show more'}</button>` : ''}
      </div>

      <!-- Sources -->
      ${sources.length > 0 ? `
        <div class="mt-2.5 pt-2 border-t border-slate-700/50">
          <button onclick="toggleSources('${id}')" class="flex items-center gap-1 text-[11px] text-fs-muted hover:text-fs-text transition-colors">
            <svg class="w-3 h-3 transition-transform ${sourcesExpanded ? 'rotate-90' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
            ${sources.length} source${sources.length > 1 ? 's' : ''}
          </button>
          <div class="expandable-content ${sourcesExpanded ? 'expanded' : ''} mt-1.5 pl-1">
            ${sources.map((s, si) => renderSourceCard(s, si)).join('')}
          </div>
        </div>` : ''}

      <!-- Actions -->
      <div class="flex justify-end mt-2">
        <button onclick="copyVerdict(state.claims[${idx}])" class="text-[10px] text-slate-500 hover:text-fs-text flex items-center gap-1 transition-colors">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/></svg>
          Copy
        </button>
      </div>
    </div>`;
}

function renderEmptyState() {
  if (state.claims.length > 0 || state.pipelineState) return '';
  return `
    <section class="flex-1 flex flex-col items-center justify-center px-6 py-10 text-center">
      <div class="w-16 h-16 bg-slate-800 rounded-2xl flex items-center justify-center mb-4 shadow-inner">
        <span class="text-3xl">🔍</span>
      </div>
      <h3 class="text-sm font-medium text-fs-text mb-1">Ready to fact-check</h3>
      <p class="text-xs text-fs-muted leading-relaxed mb-4">Start monitoring a page or paste text to verify claims in real-time.</p>
      <div class="bg-slate-800/50 rounded-lg px-3 py-2 border border-fs-border">
        <p class="text-[11px] text-slate-400 leading-relaxed">💡 Works best on YouTube, news articles, and podcasts</p>
      </div>
    </section>`;
}

function renderError() {
  if (!state.error && state.hasApiKey) return '';
  if (!state.hasApiKey) {
    return `
      <section class="px-4 py-3">
        <div class="bg-amber-500/10 border border-amber-500/30 rounded-xl p-3">
          <div class="flex items-start gap-2">
            <span class="text-base">⚙️</span>
            <div>
              <p class="text-xs text-amber-300 font-medium">API Key Required</p>
              <p class="text-[11px] text-amber-200/70 mt-0.5">Please configure your API keys in Settings to start fact-checking.</p>
              <button onclick="openOptions()" class="text-[11px] text-fs-accent hover:underline mt-1.5 inline-block">Open Settings →</button>
            </div>
          </div>
        </div>
      </section>`;
  }
  if (state.error) {
    return `
      <section class="px-4 py-3">
        <div class="bg-red-500/10 border border-red-500/30 rounded-xl p-3">
          <div class="flex items-start gap-2">
            <span class="text-base">⚠️</span>
            <div>
              <p class="text-xs text-red-300 font-medium">Error</p>
              <p class="text-[11px] text-red-200/70 mt-0.5">${escapeHtml(state.error)}</p>
            </div>
          </div>
        </div>
      </section>`;
  }
  return '';
}

function renderHistory() {
  if (state.history.length === 0) return '';
  const arrow = state.historyExpanded ? 'rotate-90' : '';
  return `
    <section class="border-t border-fs-border">
      <button onclick="toggleHistory()" class="w-full px-4 py-2.5 flex items-center justify-between hover:bg-slate-800/30 transition-colors">
        <span class="text-xs font-medium text-fs-muted">History (${state.history.length})</span>
        <svg class="w-3.5 h-3.5 text-fs-muted transition-transform ${arrow}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
      </button>
      <div class="expandable-content ${state.historyExpanded ? 'expanded' : ''} px-4 pb-3">
        ${state.history.slice(0, 10).map(h => `
          <div class="py-2 border-b border-slate-700/50 last:border-0">
            <div class="flex items-center justify-between">
              <span class="text-[11px] text-fs-text truncate max-w-[200px]">${escapeHtml(h.url || 'Manual check')}</span>
              <span class="text-[10px] text-slate-500">${formatTimestamp(h.date)}</span>
            </div>
            <p class="text-[10px] text-fs-muted mt-0.5">${h.claimCount || 0} claims checked</p>
          </div>
        `).join('')}
      </div>
    </section>`;
}

// ─── Main Render ─────────────────────────────────────────────────────────────
function render() {
  const app = document.getElementById('app');
  if (!app) return;
  app.innerHTML = `
    ${renderHeader()}
    ${renderError()}
    ${renderControls()}
    ${renderPipeline()}
    ${state.claims.length > 0 ? renderVerdictCards() : renderEmptyState()}
    ${renderHistory()}
  `;
}

// ─── Initialization ──────────────────────────────────────────────────────────
async function init() {
  // Check API key availability
  try {
    const result = await chrome.storage.local.get(['qwen_api_key', 'factshield_history', 'factshield_settings']);
    state.hasApiKey = !!result.qwen_api_key;
    state.history = result.factshield_history || [];
    state.settings = result.factshield_settings || {};
  } catch (e) {
    // Running outside extension context (dev mode)
    state.hasApiKey = true;
  }

  initMessageListener();
  sendMessage('GET_STATE');
  render();
}

// Expose functions to global scope for inline handlers
window.startFactCheck = startFactCheck;
window.stopFactCheck = stopFactCheck;
window.checkText = checkText;
window.toggleCard = toggleCard;
window.toggleSources = toggleSources;
window.copyVerdict = copyVerdict;
window.openOptions = openOptions;
window.switchMode = switchMode;
window.toggleHistory = toggleHistory;
window.state = state;

// Boot
init();

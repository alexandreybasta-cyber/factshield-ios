// FactShield Options Page

// ─── State ───────────────────────────────────────────────────────────────────
let settings = {
  qwen_api_key: '',
  tavily_api_key: '',
  google_factcheck_api_key: '',
  enableHighlights: true,
  showNotifications: false,
  autoStartYoutube: false,
  extractionInterval: 15,
  evidenceDepth: 'standard',
};

let keyValidity = { qwen: null, tavily: null, google: null }; // null | true | false
let showPasswords = { qwen: false, tavily: false, google: false };

// ─── Toast ───────────────────────────────────────────────────────────────────
function showToast(message, type = 'success') {
  const existing = document.getElementById('toast');
  if (existing) existing.remove();
  const colors = type === 'success' ? 'bg-emerald-500' : type === 'error' ? 'bg-red-500' : 'bg-gray-700';
  const toast = document.createElement('div');
  toast.id = 'toast';
  toast.className = `fixed top-4 left-1/2 -translate-x-1/2 ${colors} text-white text-sm px-4 py-2 rounded-lg shadow-xl toast-enter z-50`;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => { toast.classList.replace('toast-enter', 'toast-exit'); setTimeout(() => toast.remove(), 300); }, 2500);
}

// ─── Storage Helpers ─────────────────────────────────────────────────────────
async function loadSettings() {
  try {
    const result = await chrome.storage.local.get([
      'qwen_api_key', 'tavily_api_key', 'google_factcheck_api_key', 'factshield_settings'
    ]);
    settings.qwen_api_key = result.qwen_api_key || '';
    settings.tavily_api_key = result.tavily_api_key || '';
    settings.google_factcheck_api_key = result.google_factcheck_api_key || '';
    const prefs = result.factshield_settings || {};
    settings.enableHighlights = prefs.enableHighlights !== undefined ? prefs.enableHighlights : true;
    settings.showNotifications = prefs.showNotifications || false;
    settings.autoStartYoutube = prefs.autoStartYoutube || false;
    settings.extractionInterval = prefs.extractionInterval || 15;
    settings.evidenceDepth = prefs.evidenceDepth || 'standard';
  } catch (e) {
    // Running outside extension context
  }
  render();
}

async function saveSettings() {
  if (!settings.qwen_api_key.trim()) {
    showToast('Qwen API Key is required', 'error');
    return;
  }
  try {
    await chrome.storage.local.set({
      qwen_api_key: settings.qwen_api_key.trim(),
      tavily_api_key: settings.tavily_api_key.trim(),
      google_factcheck_api_key: settings.google_factcheck_api_key.trim(),
      factshield_settings: {
        enableHighlights: settings.enableHighlights,
        showNotifications: settings.showNotifications,
        autoStartYoutube: settings.autoStartYoutube,
        extractionInterval: settings.extractionInterval,
        evidenceDepth: settings.evidenceDepth,
      }
    });
    showToast('Settings saved successfully');
  } catch (e) {
    showToast('Failed to save settings', 'error');
  }
}

// ─── API Key Validation ──────────────────────────────────────────────────────
async function testQwenKey() {
  const key = settings.qwen_api_key.trim();
  if (!key) { showToast('Enter a Qwen API key first', 'error'); return; }
  keyValidity.qwen = null;
  render();
  try {
    const response = await fetch('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` },
      body: JSON.stringify({ model: 'qwen-turbo', messages: [{ role: 'user', content: 'Hi' }], max_tokens: 5 })
    });
    keyValidity.qwen = response.ok || response.status === 200;
    showToast(keyValidity.qwen ? 'Qwen API key is valid' : `Invalid key (HTTP ${response.status})`, keyValidity.qwen ? 'success' : 'error');
  } catch (e) {
    keyValidity.qwen = false;
    showToast('Connection failed — check network', 'error');
  }
  render();
}

// ─── Data Management ─────────────────────────────────────────────────────────
async function clearHistory() {
  if (!confirm('Clear all fact-check history? This cannot be undone.')) return;
  try {
    await chrome.storage.local.set({ factshield_history: [] });
    showToast('History cleared');
  } catch (e) {
    showToast('Failed to clear history', 'error');
  }
}

async function exportHistory() {
  try {
    const result = await chrome.storage.local.get('factshield_history');
    const history = result.factshield_history || [];
    const blob = new Blob([JSON.stringify(history, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `factshield-history-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('History exported');
  } catch (e) {
    showToast('Failed to export history', 'error');
  }
}

// ─── Input Handlers ──────────────────────────────────────────────────────────
function onInput(field, value) {
  settings[field] = value;
}

function onToggle(field) {
  settings[field] = !settings[field];
  render();
}

function onSlider(value) {
  settings.extractionInterval = parseInt(value);
  document.getElementById('interval-value').textContent = `${value}s`;
}

function onSelect(value) {
  settings.evidenceDepth = value;
}

function togglePassword(key) {
  showPasswords[key] = !showPasswords[key];
  render();
}

// ─── Render ──────────────────────────────────────────────────────────────────
function validityIcon(status) {
  if (status === true) return '<span class="text-emerald-500 text-lg ml-2">✓</span>';
  if (status === false) return '<span class="text-red-500 text-lg ml-2">✗</span>';
  return '';
}

function renderApiKeyField(label, field, storageKey, helperText, helperLink, validity, passwordKey) {
  const type = showPasswords[passwordKey] ? 'text' : 'password';
  const eyeIcon = showPasswords[passwordKey]
    ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L6.59 6.59m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>'
    : '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>';

  return `
    <div class="mb-5">
      <label class="flex items-center text-sm font-medium text-fs-text mb-1.5">
        ${label}
        ${validityIcon(validity)}
      </label>
      <div class="relative">
        <input type="${type}" value="${settings[field]}" oninput="onInput('${field}', this.value)"
          class="w-full bg-white border border-fs-border rounded-lg px-3 py-2.5 pr-10 text-sm text-fs-text placeholder-gray-400 focus:outline-none focus:border-fs-accent focus:ring-2 focus:ring-orange-100 transition-all"
          placeholder="Enter your API key">
        <button onclick="togglePassword('${passwordKey}')" class="absolute right-3 top-1/2 -translate-y-1/2 text-fs-muted hover:text-fs-text transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">${eyeIcon}</svg>
        </button>
      </div>
      <p class="text-[11px] text-fs-muted mt-1.5">${helperText} ${helperLink ? `<a href="${helperLink}" target="_blank" class="text-fs-accent font-medium hover:underline">Get key →</a>` : ''}</p>
    </div>`;
}

function render() {
  const root = document.getElementById('options-root');
  if (!root) return;

  root.innerHTML = `
    <!-- Header -->
    <div class="flex items-center gap-3 mb-8">
      <div class="w-10 h-10 bg-gradient-to-br from-orange-400 to-orange-600 rounded-xl flex items-center justify-center text-xl shadow-lg shadow-orange-200">🛡️</div>
      <div>
        <h1 class="text-xl font-bold tracking-tight text-fs-text">FactShield Settings</h1>
        <p class="text-xs text-fs-muted">Configure your fact-checking experience</p>
      </div>
    </div>

    <!-- API Keys Section -->
    <section class="bg-white border border-fs-border rounded-xl p-5 mb-5 shadow-sm">
      <h2 class="text-sm font-semibold text-fs-text mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"/></svg>
        API Keys
      </h2>

      ${renderApiKeyField('Qwen API Key (Required)', 'qwen_api_key', 'qwen_api_key', 'Powers AI claim extraction and verdict synthesis.', 'https://dashscope.console.aliyun.com/', keyValidity.qwen, 'qwen')}
      
      <div class="flex gap-2 -mt-2 mb-5">
        <button onclick="testQwenKey()" class="px-3 py-1.5 bg-gray-50 hover:bg-gray-100 text-xs text-fs-text font-medium rounded-lg transition-colors border border-fs-border">Test Connection</button>
      </div>

      ${renderApiKeyField('Tavily API Key (Optional — improves evidence quality)', 'tavily_api_key', 'tavily_api_key', 'Enhances web search for evidence gathering.', 'https://tavily.com', keyValidity.tavily, 'tavily')}
      ${renderApiKeyField('Google Fact Check API Key (Optional)', 'google_factcheck_api_key', 'google_factcheck_api_key', 'Cross-references Google\'s fact-check database.', 'https://console.cloud.google.com/', keyValidity.google, 'google')}
      
      <button onclick="saveSettings()" class="w-full py-2.5 bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-600 hover:to-orange-700 text-white text-sm font-semibold rounded-lg transition-all shadow-md shadow-orange-200 hover:shadow-lg hover:shadow-orange-300">
        Save API Keys
      </button>
    </section>

    <!-- Preferences Section -->
    <section class="bg-white border border-fs-border rounded-xl p-5 mb-5 shadow-sm">
      <h2 class="text-sm font-semibold text-fs-text mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"/></svg>
        Preferences
      </h2>

      <!-- Toggle: Inline highlights -->
      <div class="flex items-center justify-between py-3 border-b border-gray-100">
        <div>
          <p class="text-sm text-fs-text">Enable inline highlights</p>
          <p class="text-[11px] text-fs-muted">Highlight checked claims directly on the page</p>
        </div>
        <button onclick="onToggle('enableHighlights')" class="relative w-11 h-6 rounded-full transition-colors ${settings.enableHighlights ? 'bg-fs-accent' : 'bg-gray-200'}">
          <span class="absolute top-0.5 ${settings.enableHighlights ? 'left-[22px]' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-sm transition-all"></span>
        </button>
      </div>

      <!-- Toggle: Notifications -->
      <div class="flex items-center justify-between py-3 border-b border-gray-100">
        <div>
          <p class="text-sm text-fs-text">Show notifications for verdicts</p>
          <p class="text-[11px] text-fs-muted">Browser notification when a claim is verified</p>
        </div>
        <button onclick="onToggle('showNotifications')" class="relative w-11 h-6 rounded-full transition-colors ${settings.showNotifications ? 'bg-fs-accent' : 'bg-gray-200'}">
          <span class="absolute top-0.5 ${settings.showNotifications ? 'left-[22px]' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-sm transition-all"></span>
        </button>
      </div>

      <!-- Toggle: Auto-start YouTube -->
      <div class="flex items-center justify-between py-3 border-b border-gray-100">
        <div>
          <p class="text-sm text-fs-text">Auto-start on YouTube</p>
          <p class="text-[11px] text-fs-muted">Automatically begin monitoring YouTube videos</p>
        </div>
        <button onclick="onToggle('autoStartYoutube')" class="relative w-11 h-6 rounded-full transition-colors ${settings.autoStartYoutube ? 'bg-fs-accent' : 'bg-gray-200'}">
          <span class="absolute top-0.5 ${settings.autoStartYoutube ? 'left-[22px]' : 'left-0.5'} w-5 h-5 bg-white rounded-full shadow-sm transition-all"></span>
        </button>
      </div>

      <!-- Slider: Extraction interval -->
      <div class="py-3 border-b border-gray-100">
        <div class="flex items-center justify-between mb-2">
          <div>
            <p class="text-sm text-fs-text">Extraction interval</p>
            <p class="text-[11px] text-fs-muted">How often to extract new claims from audio/text</p>
          </div>
          <span id="interval-value" class="text-sm font-mono text-fs-accent font-semibold">${settings.extractionInterval}s</span>
        </div>
        <input type="range" min="5" max="60" step="5" value="${settings.extractionInterval}" oninput="onSlider(this.value)"
          class="w-full h-1.5 appearance-none cursor-pointer rounded-full">
        <div class="flex justify-between text-[10px] text-gray-400 mt-1">
          <span>5s</span><span>30s</span><span>60s</span>
        </div>
      </div>

      <!-- Dropdown: Evidence depth -->
      <div class="py-3">
        <div class="mb-2">
          <p class="text-sm text-fs-text">Evidence depth</p>
          <p class="text-[11px] text-fs-muted">Number of sources to search per claim</p>
        </div>
        <select onchange="onSelect(this.value)" class="w-full bg-white border border-fs-border rounded-lg px-3 py-2 text-sm text-fs-text focus:outline-none focus:border-fs-accent focus:ring-2 focus:ring-orange-100 transition-all appearance-none cursor-pointer">
          <option value="minimal" ${settings.evidenceDepth === 'minimal' ? 'selected' : ''}>Minimal (3 sources)</option>
          <option value="standard" ${settings.evidenceDepth === 'standard' ? 'selected' : ''}>Standard (5 sources)</option>
          <option value="deep" ${settings.evidenceDepth === 'deep' ? 'selected' : ''}>Deep (8 sources)</option>
        </select>
      </div>

      <button onclick="saveSettings()" class="w-full py-2.5 mt-3 bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-600 hover:to-orange-700 text-white text-sm font-semibold rounded-lg transition-all shadow-md shadow-orange-200">
        Save Preferences
      </button>
    </section>

    <!-- About Section -->
    <section class="bg-white border border-fs-border rounded-xl p-5 mb-5 shadow-sm">
      <h2 class="text-sm font-semibold text-fs-text mb-3 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
        About FactShield
      </h2>
      <div class="space-y-2">
        <div class="flex justify-between text-xs">
          <span class="text-fs-muted">Version</span>
          <span class="text-fs-text font-mono font-medium">1.0.0</span>
        </div>
        <p class="text-xs text-fs-muted leading-relaxed">FactShield verifies claims in real-time using AI-powered multi-source evidence retrieval. Claims are extracted from audio or text, evidence is gathered from multiple search APIs, and verdicts are synthesized using large language models.</p>
        <div class="bg-orange-50 rounded-lg p-3 mt-3 border border-orange-100">
          <p class="text-[11px] text-orange-700 font-medium mb-1">Pipeline:</p>
          <p class="text-[11px] text-orange-600">Audio/Text → Claim Extraction → Evidence Search → Cross-Reference → Verdict Synthesis</p>
        </div>
      </div>
    </section>

    <!-- Data Management Section -->
    <section class="bg-white border border-fs-border rounded-xl p-5 mb-8 shadow-sm">
      <h2 class="text-sm font-semibold text-fs-text mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"/></svg>
        Data Management
      </h2>
      <div class="flex gap-3">
        <button onclick="clearHistory()" class="flex-1 py-2.5 px-3 bg-red-50 hover:bg-red-100 text-red-600 text-xs font-medium rounded-lg border border-red-200 transition-all">
          Clear History
        </button>
        <button onclick="exportHistory()" class="flex-1 py-2.5 px-3 bg-gray-50 hover:bg-gray-100 text-fs-text text-xs font-medium rounded-lg border border-fs-border transition-all">
          Export History (JSON)
        </button>
      </div>
    </section>
  `;
}

// ─── Init ────────────────────────────────────────────────────────────────────
loadSettings();
// FactShield Options Page

// ─── State ───────────────────────────────────────────────────────────────────
let settings = {
  qwen_api_key: '',
  tavily_api_key: '',
  google_factcheck_api_key: '',
  enableHighlights: true,
  showNotifications: false,
  autoStartYoutube: false,
  extractionInterval: 15,
  evidenceDepth: 'standard',
};

let keyValidity = { qwen: null, tavily: null, google: null }; // null | true | false
let showPasswords = { qwen: false, tavily: false, google: false };

// ─── Toast ───────────────────────────────────────────────────────────────────
function showToast(message, type = 'success') {
  const existing = document.getElementById('toast');
  if (existing) existing.remove();
  const colors = type === 'success' ? 'bg-emerald-600' : type === 'error' ? 'bg-red-600' : 'bg-slate-600';
  const toast = document.createElement('div');
  toast.id = 'toast';
  toast.className = `fixed top-4 left-1/2 -translate-x-1/2 ${colors} text-white text-sm px-4 py-2 rounded-lg shadow-xl toast-enter z-50`;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => { toast.classList.replace('toast-enter', 'toast-exit'); setTimeout(() => toast.remove(), 300); }, 2500);
}

// ─── Storage Helpers ─────────────────────────────────────────────────────────
async function loadSettings() {
  try {
    const result = await chrome.storage.local.get([
      'qwen_api_key', 'tavily_api_key', 'google_factcheck_api_key', 'factshield_settings'
    ]);
    settings.qwen_api_key = result.qwen_api_key || '';
    settings.tavily_api_key = result.tavily_api_key || '';
    settings.google_factcheck_api_key = result.google_factcheck_api_key || '';
    const prefs = result.factshield_settings || {};
    settings.enableHighlights = prefs.enableHighlights !== undefined ? prefs.enableHighlights : true;
    settings.showNotifications = prefs.showNotifications || false;
    settings.autoStartYoutube = prefs.autoStartYoutube || false;
    settings.extractionInterval = prefs.extractionInterval || 15;
    settings.evidenceDepth = prefs.evidenceDepth || 'standard';
  } catch (e) {
    // Running outside extension context
  }
  render();
}

async function saveSettings() {
  if (!settings.qwen_api_key.trim()) {
    showToast('Qwen API Key is required', 'error');
    return;
  }
  try {
    await chrome.storage.local.set({
      qwen_api_key: settings.qwen_api_key.trim(),
      tavily_api_key: settings.tavily_api_key.trim(),
      google_factcheck_api_key: settings.google_factcheck_api_key.trim(),
      factshield_settings: {
        enableHighlights: settings.enableHighlights,
        showNotifications: settings.showNotifications,
        autoStartYoutube: settings.autoStartYoutube,
        extractionInterval: settings.extractionInterval,
        evidenceDepth: settings.evidenceDepth,
      }
    });
    showToast('Settings saved successfully');
  } catch (e) {
    showToast('Failed to save settings', 'error');
  }
}

// ─── API Key Validation ──────────────────────────────────────────────────────
async function testQwenKey() {
  const key = settings.qwen_api_key.trim();
  if (!key) { showToast('Enter a Qwen API key first', 'error'); return; }
  keyValidity.qwen = null;
  render();
  try {
    const response = await fetch('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` },
      body: JSON.stringify({ model: 'qwen-turbo', messages: [{ role: 'user', content: 'Hi' }], max_tokens: 5 })
    });
    keyValidity.qwen = response.ok || response.status === 200;
    showToast(keyValidity.qwen ? 'Qwen API key is valid' : `Invalid key (HTTP ${response.status})`, keyValidity.qwen ? 'success' : 'error');
  } catch (e) {
    keyValidity.qwen = false;
    showToast('Connection failed — check network', 'error');
  }
  render();
}

// ─── Data Management ─────────────────────────────────────────────────────────
async function clearHistory() {
  if (!confirm('Clear all fact-check history? This cannot be undone.')) return;
  try {
    await chrome.storage.local.set({ factshield_history: [] });
    showToast('History cleared');
  } catch (e) {
    showToast('Failed to clear history', 'error');
  }
}

async function exportHistory() {
  try {
    const result = await chrome.storage.local.get('factshield_history');
    const history = result.factshield_history || [];
    const blob = new Blob([JSON.stringify(history, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `factshield-history-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('History exported');
  } catch (e) {
    showToast('Failed to export history', 'error');
  }
}

// ─── Input Handlers ──────────────────────────────────────────────────────────
function onInput(field, value) {
  settings[field] = value;
}

function onToggle(field) {
  settings[field] = !settings[field];
  render();
}

function onSlider(value) {
  settings.extractionInterval = parseInt(value);
  document.getElementById('interval-value').textContent = `${value}s`;
}

function onSelect(value) {
  settings.evidenceDepth = value;
}

function togglePassword(key) {
  showPasswords[key] = !showPasswords[key];
  render();
}

// ─── Render ──────────────────────────────────────────────────────────────────
function validityIcon(status) {
  if (status === true) return '<span class="text-emerald-400 text-lg ml-2">✓</span>';
  if (status === false) return '<span class="text-red-400 text-lg ml-2">✗</span>';
  return '';
}

function renderApiKeyField(label, field, storageKey, helperText, helperLink, validity, passwordKey) {
  const type = showPasswords[passwordKey] ? 'text' : 'password';
  const eyeIcon = showPasswords[passwordKey]
    ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L6.59 6.59m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>'
    : '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>';

  return `
    <div class="mb-5">
      <label class="flex items-center text-sm font-medium text-fs-text mb-1.5">
        ${label}
        ${validityIcon(validity)}
      </label>
      <div class="relative">
        <input type="${type}" value="${settings[field]}" oninput="onInput('${field}', this.value)"
          class="w-full bg-slate-800/70 border border-fs-border rounded-lg px-3 py-2.5 pr-10 text-sm text-fs-text placeholder-slate-500 focus:outline-none focus:border-fs-accent focus:ring-1 focus:ring-fs-accent/30 transition-all"
          placeholder="Enter your API key">
        <button onclick="togglePassword('${passwordKey}')" class="absolute right-3 top-1/2 -translate-y-1/2 text-fs-muted hover:text-fs-text transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">${eyeIcon}</svg>
        </button>
      </div>
      <p class="text-[11px] text-fs-muted mt-1">${helperText} ${helperLink ? `<a href="${helperLink}" target="_blank" class="text-fs-accent hover:underline">Get key →</a>` : ''}</p>
    </div>`;
}

function render() {
  const root = document.getElementById('options-root');
  if (!root) return;

  root.innerHTML = `
    <!-- Header -->
    <div class="flex items-center gap-3 mb-8">
      <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center text-xl shadow-lg">🛡️</div>
      <div>
        <h1 class="text-xl font-bold tracking-tight">FactShield Settings</h1>
        <p class="text-xs text-fs-muted">Configure your fact-checking experience</p>
      </div>
    </div>

    <!-- API Keys Section -->
    <section class="bg-fs-card border border-fs-border rounded-xl p-5 mb-5">
      <h2 class="text-sm font-semibold text-fs-text mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"/></svg>
        API Keys
      </h2>

      ${renderApiKeyField('Qwen API Key (Required)', 'qwen_api_key', 'qwen_api_key', 'Powers AI claim extraction and verdict synthesis.', 'https://dashscope.console.aliyun.com/', keyValidity.qwen, 'qwen')}
      
      <div class="flex gap-2 -mt-2 mb-5">
        <button onclick="testQwenKey()" class="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-xs text-fs-text rounded-lg transition-colors border border-fs-border">Test Connection</button>
      </div>

      ${renderApiKeyField('Tavily API Key (Optional — improves evidence quality)', 'tavily_api_key', 'tavily_api_key', 'Enhances web search for evidence gathering.', 'https://tavily.com', keyValidity.tavily, 'tavily')}
      ${renderApiKeyField('Google Fact Check API Key (Optional)', 'google_factcheck_api_key', 'google_factcheck_api_key', 'Cross-references Google\'s fact-check database.', 'https://console.cloud.google.com/', keyValidity.google, 'google')}
      
      <button onclick="saveSettings()" class="w-full py-2.5 bg-fs-accent hover:bg-blue-600 text-white text-sm font-medium rounded-lg transition-all shadow-lg shadow-blue-500/20">
        Save API Keys
      </button>
    </section>

    <!-- Preferences Section -->
    <section class="bg-fs-card border border-fs-border rounded-xl p-5 mb-5">
      <h2 class="text-sm font-semibold text-fs-text mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"/></svg>
        Preferences
      </h2>

      <!-- Toggle: Inline highlights -->
      <div class="flex items-center justify-between py-3 border-b border-slate-700/50">
        <div>
          <p class="text-sm text-fs-text">Enable inline highlights</p>
          <p class="text-[11px] text-fs-muted">Highlight checked claims directly on the page</p>
        </div>
        <button onclick="onToggle('enableHighlights')" class="relative w-10 h-5 rounded-full transition-colors ${settings.enableHighlights ? 'bg-fs-accent' : 'bg-slate-600'}">
          <span class="absolute top-0.5 ${settings.enableHighlights ? 'left-5' : 'left-0.5'} w-4 h-4 bg-white rounded-full shadow transition-all"></span>
        </button>
      </div>

      <!-- Toggle: Notifications -->
      <div class="flex items-center justify-between py-3 border-b border-slate-700/50">
        <div>
          <p class="text-sm text-fs-text">Show notifications for verdicts</p>
          <p class="text-[11px] text-fs-muted">Browser notification when a claim is verified</p>
        </div>
        <button onclick="onToggle('showNotifications')" class="relative w-10 h-5 rounded-full transition-colors ${settings.showNotifications ? 'bg-fs-accent' : 'bg-slate-600'}">
          <span class="absolute top-0.5 ${settings.showNotifications ? 'left-5' : 'left-0.5'} w-4 h-4 bg-white rounded-full shadow transition-all"></span>
        </button>
      </div>

      <!-- Toggle: Auto-start YouTube -->
      <div class="flex items-center justify-between py-3 border-b border-slate-700/50">
        <div>
          <p class="text-sm text-fs-text">Auto-start on YouTube</p>
          <p class="text-[11px] text-fs-muted">Automatically begin monitoring YouTube videos</p>
        </div>
        <button onclick="onToggle('autoStartYoutube')" class="relative w-10 h-5 rounded-full transition-colors ${settings.autoStartYoutube ? 'bg-fs-accent' : 'bg-slate-600'}">
          <span class="absolute top-0.5 ${settings.autoStartYoutube ? 'left-5' : 'left-0.5'} w-4 h-4 bg-white rounded-full shadow transition-all"></span>
        </button>
      </div>

      <!-- Slider: Extraction interval -->
      <div class="py-3 border-b border-slate-700/50">
        <div class="flex items-center justify-between mb-2">
          <div>
            <p class="text-sm text-fs-text">Extraction interval</p>
            <p class="text-[11px] text-fs-muted">How often to extract new claims from audio/text</p>
          </div>
          <span id="interval-value" class="text-sm font-mono text-fs-accent">${settings.extractionInterval}s</span>
        </div>
        <input type="range" min="5" max="60" step="5" value="${settings.extractionInterval}" oninput="onSlider(this.value)"
          class="w-full h-1.5 appearance-none cursor-pointer rounded-full">
        <div class="flex justify-between text-[10px] text-slate-500 mt-1">
          <span>5s</span><span>30s</span><span>60s</span>
        </div>
      </div>

      <!-- Dropdown: Evidence depth -->
      <div class="py-3">
        <div class="mb-2">
          <p class="text-sm text-fs-text">Evidence depth</p>
          <p class="text-[11px] text-fs-muted">Number of sources to search per claim</p>
        </div>
        <select onchange="onSelect(this.value)" class="w-full bg-slate-800/70 border border-fs-border rounded-lg px-3 py-2 text-sm text-fs-text focus:outline-none focus:border-fs-accent transition-all appearance-none cursor-pointer">
          <option value="minimal" ${settings.evidenceDepth === 'minimal' ? 'selected' : ''}>Minimal (3 sources)</option>
          <option value="standard" ${settings.evidenceDepth === 'standard' ? 'selected' : ''}>Standard (5 sources)</option>
          <option value="deep" ${settings.evidenceDepth === 'deep' ? 'selected' : ''}>Deep (8 sources)</option>
        </select>
      </div>

      <button onclick="saveSettings()" class="w-full py-2.5 mt-3 bg-fs-accent hover:bg-blue-600 text-white text-sm font-medium rounded-lg transition-all">
        Save Preferences
      </button>
    </section>

    <!-- About Section -->
    <section class="bg-fs-card border border-fs-border rounded-xl p-5 mb-5">
      <h2 class="text-sm font-semibold text-fs-text mb-3 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
        About FactShield
      </h2>
      <div class="space-y-2">
        <div class="flex justify-between text-xs">
          <span class="text-fs-muted">Version</span>
          <span class="text-fs-text font-mono">1.0.0</span>
        </div>
        <p class="text-xs text-fs-muted leading-relaxed">FactShield verifies claims in real-time using AI-powered multi-source evidence retrieval. Claims are extracted from audio or text, evidence is gathered from multiple search APIs, and verdicts are synthesized using large language models.</p>
        <div class="bg-slate-800/50 rounded-lg p-3 mt-3">
          <p class="text-[11px] text-slate-400 font-medium mb-1">Pipeline:</p>
          <p class="text-[11px] text-slate-500">Audio/Text → Claim Extraction → Evidence Search → Cross-Reference → Verdict Synthesis</p>
        </div>
      </div>
    </section>

    <!-- Data Management Section -->
    <section class="bg-fs-card border border-fs-border rounded-xl p-5 mb-8">
      <h2 class="text-sm font-semibold text-fs-text mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-fs-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"/></svg>
        Data Management
      </h2>
      <div class="flex gap-3">
        <button onclick="clearHistory()" class="flex-1 py-2 px-3 bg-red-500/10 hover:bg-red-500/20 text-red-400 text-xs font-medium rounded-lg border border-red-500/20 transition-all">
          Clear History
        </button>
        <button onclick="exportHistory()" class="flex-1 py-2 px-3 bg-slate-700 hover:bg-slate-600 text-fs-text text-xs font-medium rounded-lg border border-fs-border transition-all">
          Export History (JSON)
        </button>
      </div>
    </section>
  `;
}

// ─── Init ────────────────────────────────────────────────────────────────────
loadSettings();

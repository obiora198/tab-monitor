// ===== Tab Tracker Logic (inlined from tabTracker.js) =====
const DEFAULT_TAB_THRESHOLD = 15;

async function getTabThreshold() {
  const result = await chrome.storage.sync.get({ tabThreshold: DEFAULT_TAB_THRESHOLD });
  return result.tabThreshold;
}

async function getRecommendedTabsToClose() {
  const tabs = await chrome.tabs.query({});
  
  const closableTabs = tabs.filter(tab => {
    if (tab.active) return false;
    if (tab.pinned) return false;
    if (tab.audible) return false;
    return true;
  });

  closableTabs.sort((a, b) => {
    const aTime = a.lastAccessed || 0;
    const bTime = b.lastAccessed || 0;
    return aTime - bTime;
  });

  return closableTabs.slice(0, 5);
}

// ===== Native Messaging =====
let nativePort = null;
const NATIVE_HOST_NAME = 'com.tabmonitor.host';

function connectNativeHost() {
  nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);
  
  nativePort.onMessage.addListener((msg) => {
    console.log('[Scout] Received message from native host:', msg);
    if (msg.action === 'CLOSE_TABS' && Array.isArray(msg.tabIds)) {
      chrome.tabs.remove(msg.tabIds, () => {
        console.log(`[Scout] Closed tabs: ${msg.tabIds.join(', ')}`);
        checkTabCount({ triggerShow: false });
      });
    } else if (msg.action === 'FOCUS_TAB' && msg.tabId) {
      chrome.tabs.update(msg.tabId, { active: true });
      if (msg.windowId) {
        chrome.windows.update(msg.windowId, { focused: true });
      }
    } else if (msg.action === 'OPEN_OPTIONS') {
      if (chrome.runtime.openOptionsPage) {
        chrome.runtime.openOptionsPage();
      } else {
        chrome.tabs.create({ url: chrome.runtime.getURL('options.html') });
      }
    }
  });

  nativePort.onDisconnect.addListener(() => {
    console.log('[Scout] Disconnected from native host. ' + chrome.runtime.lastError?.message);
    nativePort = null;
  });
  
  console.log('[Scout] Connected to Native Host');
}

// Check tab count and alert if needed
async function checkTabCount(options = { triggerShow: true }) {
  const allTabs = await chrome.tabs.query({});
  const tabCount = allTabs.length;
  const threshold = await getTabThreshold();

  console.log(`[Scout] Tab count: ${tabCount}, Threshold: ${threshold}`);

  if (tabCount > threshold) {
    const closableTabs = await getRecommendedTabsToClose();
    const closableIds = new Set(closableTabs.map(t => t.id));
    
    const suggestedData = closableTabs.map(t => ({
      id: t.id,
      windowId: t.windowId,
      title: t.title,
      url: t.url,
      active: t.active,
      pinned: t.pinned,
      audible: t.audible
    }));

    const otherData = allTabs
      .filter(t => !closableIds.has(t.id))
      .map(t => ({
        id: t.id,
        windowId: t.windowId,
        title: t.title,
        url: t.url,
        active: t.active,
        pinned: t.pinned,
        audible: t.audible
      }));

    if (nativePort) {
      const eventName = options.triggerShow ? 'TAB_WARNING' : 'TAB_UPDATE';
      console.log(`[Scout] Sending ${eventName} to native host`);
      nativePort.postMessage({
        event: eventName,
        tabCount: tabCount,
        threshold: threshold,
        tabs: suggestedData,
        otherTabs: otherData
      });
    } else if (options.triggerShow) {
      console.log('[Scout] Native port not connected, falling back to browser notification');
      chrome.notifications.create({
        type: 'basic',
        iconUrl: 'icon.png',
        title: 'Tab Monitor Warning',
        message: `You have ${tabCount} tabs open. Threshold is ${threshold}.`
      });
    }
  } else {
    // Tab count is NOW <= threshold! Auto-close/hide warning
    console.log('[Scout] Tab count is within threshold. Sending TAB_RESOLVED');
    if (nativePort) {
      nativePort.postMessage({
        event: 'TAB_RESOLVED',
        tabCount: tabCount,
        threshold: threshold
      });
    }
  }
}

// Listeners
chrome.tabs.onCreated.addListener(() => checkTabCount({ triggerShow: true }));
chrome.tabs.onRemoved.addListener(() => checkTabCount({ triggerShow: false }));

// Initial connection
connectNativeHost();

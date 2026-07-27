// tabTracker.js - Browser-agnostic tab tracking logic

// Default configuration
const DEFAULT_TAB_THRESHOLD = 15;

/**
 * Gets the current tab threshold from storage, or returns default.
 */
async function getTabThreshold() {
  const result = await chrome.storage.sync.get({ tabThreshold: DEFAULT_TAB_THRESHOLD });
  return result.tabThreshold;
}

/**
 * Gets recommended tabs to close.
 * Filters out active, pinned, and audible tabs.
 * Sorts by least recently used if possible.
 */
async function getRecommendedTabsToClose() {
  const tabs = await chrome.tabs.query({});
  
  // Filter tabs
  const closableTabs = tabs.filter(tab => {
    // Keep active tabs
    if (tab.active) return false;
    // Keep pinned tabs
    if (tab.pinned) return false;
    // Keep audible tabs (playing music/video)
    if (tab.audible) return false;
    
    return true;
  });

  // Sort by least recently used if we have lastAccessed
  closableTabs.sort((a, b) => {
    const aTime = a.lastAccessed || 0;
    const bTime = b.lastAccessed || 0;
    return aTime - bTime;
  });

  return closableTabs.slice(0, 5); // Return up to 5 recommendations
}

export { getTabThreshold, getRecommendedTabsToClose };

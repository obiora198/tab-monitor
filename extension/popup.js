import { getRecommendedTabsToClose } from './tabTracker.js';

document.addEventListener('DOMContentLoaded', async () => {
  const tabCountEl = document.getElementById('tabCount');
  const sysMemoryEl = document.getElementById('sysMemory');
  const closeBtn = document.getElementById('closeRecommendedBtn');

  // Get tab count
  const tabs = await chrome.tabs.query({});
  tabCountEl.textContent = tabs.length;

  // Get system memory info
  chrome.system.memory.getInfo((info) => {
    const totalGB = (info.capacity / (1024 * 1024 * 1024)).toFixed(1);
    const availableGB = (info.availableCapacity / (1024 * 1024 * 1024)).toFixed(1);
    sysMemoryEl.textContent = `${availableGB}GB free / ${totalGB}GB`;
  });

  // Handle close button
  closeBtn.addEventListener('click', async () => {
    closeBtn.disabled = true;
    closeBtn.textContent = 'Closing...';
    
    const recommended = await getRecommendedTabsToClose();
    if (recommended.length > 0) {
      const tabIds = recommended.map(t => t.id);
      chrome.tabs.remove(tabIds, () => {
        window.close(); // Close popup when done
      });
    } else {
      closeBtn.textContent = 'No tabs to close';
      setTimeout(() => {
        closeBtn.disabled = false;
        closeBtn.textContent = 'Close Recommended Tabs';
      }, 2000);
    }
  });
});

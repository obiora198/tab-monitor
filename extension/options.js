document.addEventListener('DOMContentLoaded', () => {
  const thresholdInput = document.getElementById('threshold');
  const saveBtn = document.getElementById('saveBtn');
  const status = document.getElementById('status');

  // Load current setting
  chrome.storage.sync.get({ tabThreshold: 15 }, (items) => {
    thresholdInput.value = items.tabThreshold;
  });

  // Save setting
  saveBtn.addEventListener('click', () => {
    const val = parseInt(thresholdInput.value, 10);
    if (val > 0) {
      chrome.storage.sync.set({ tabThreshold: val }, () => {
        status.style.display = 'inline';
        setTimeout(() => {
          status.style.display = 'none';
        }, 2000);
      });
    }
  });
});

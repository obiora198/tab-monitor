let suggestedTabs = [];
let otherTabs = [];
let desktopApps = [];
let selectedTabIds = new Set();
let totalTabCount = 0;
let invoke = null;
let listen = null;

window.addEventListener("DOMContentLoaded", async () => {
  const dismissBtn = document.getElementById("dismissBtn");
  const closeBtn = document.getElementById("closeBtn");
  const tabCountEl = document.getElementById("tabCount");
  const progressFill = document.getElementById("progressFill");
  const progressCount = document.getElementById("progressCount");
  const closeCountLabel = document.getElementById("closeCountLabel");
  const selectAllEl = document.getElementById("selectAll");
  const selectAllCheck = document.getElementById("selectAllCheck");

  const suggestedHeader = document.getElementById("suggestedHeader");
  const suggestedContainer = document.getElementById("suggestedContainer");
  const suggestedList = document.getElementById("suggestedList");
  const suggestedCountEl = document.getElementById("suggestedCount");

  const otherHeader = document.getElementById("otherHeader");
  const otherContainer = document.getElementById("otherContainer");
  const otherList = document.getElementById("otherList");
  const otherCountEl = document.getElementById("otherCount");

  const desktopHeader = document.getElementById("desktopHeader");
  const desktopContainer = document.getElementById("desktopContainer");
  const desktopList = document.getElementById("desktopList");
  const desktopCountEl = document.getElementById("desktopCount");

  // Avatar Images
  const avatarImg = document.getElementById("avatarImg");
  const warningAvatars = [
    "./assets/pointing_at_you.png",
    "./assets/pointing_at_tab.png"
  ];
  const successAvatar = "./assets/thumbs_up.png";

  let currentAvatarIdx = 0;
  let isSuccessState = false;
  let avatarInterval = null;

  function setAvatarImage(src) {
    if (avatarImg && avatarImg.src !== src) {
      avatarImg.style.opacity = "0.15";
      setTimeout(() => {
        avatarImg.src = src;
        avatarImg.style.opacity = "1";
      }, 200);
    }
  }

  function startAvatarRotation() {
    if (avatarInterval) clearInterval(avatarInterval);
    avatarInterval = setInterval(() => {
      if (!isSuccessState) {
        currentAvatarIdx = (currentAvatarIdx + 1) % warningAvatars.length;
        setAvatarImage(warningAvatars[currentAvatarIdx]);
      }
    }, 3500);
  }

  startAvatarRotation();

  // Accordion section toggles
  setupAccordion(suggestedHeader, suggestedContainer);
  setupAccordion(otherHeader, otherContainer);
  setupAccordion(desktopHeader, desktopContainer);

  function setupAccordion(header, container) {
    header.addEventListener("click", () => {
      const isCollapsed = header.classList.toggle("collapsed");
      container.style.display = isCollapsed ? "none" : "block";
    });
  }

  let threshold = 15;

  function getBarRatio(remaining, total, thresh) {
    if (total <= 0) return 0;
    if (remaining >= thresh) {
      const extraRange = Math.max(1, total - thresh);
      const overThresh = remaining - thresh;
      return 0.5 + 0.5 * (overThresh / extraRange);
    } else {
      return 0.5 * (remaining / Math.max(1, thresh));
    }
  }

  function getBarColor(ratio) {
    const clamp = Math.max(0, Math.min(1, ratio));
    let r, g, b;
    if (clamp <= 0.5) {
      const t = clamp / 0.5;
      r = Math.round(137 + (166 - 137) * t);
      g = Math.round(180 + (227 - 180) * t);
      b = Math.round(250 + (161 - 250) * t);
    } else {
      const t = (clamp - 0.5) / 0.5;
      r = Math.round(166 + (243 - 166) * t);
      g = Math.round(227 + (139 - 227) * t);
      b = Math.round(161 + (168 - 161) * t);
    }
    return `rgb(${r}, ${g}, ${b})`;
  }

  function updateProgressBar() {
    const remaining = Math.max(0, totalTabCount - selectedTabIds.size);
    const ratio = getBarRatio(remaining, totalTabCount, threshold);
    const pct = Math.max(5, Math.round(ratio * 100));

    progressFill.style.width = pct + '%';
    progressFill.style.backgroundColor = getBarColor(ratio);
    
    if (remaining > threshold) {
      if (isSuccessState) {
        isSuccessState = false;
        setAvatarImage(warningAvatars[currentAvatarIdx]);
      }
      progressCount.textContent = `${remaining} tabs (${remaining - threshold} over threshold)`;
    } else {
      isSuccessState = true;
      setAvatarImage(successAvatar);
      progressCount.textContent = `${remaining} tabs remaining (Target reached!)`;
    }

    if (selectedTabIds.size > 0) {
      closeBtn.disabled = false;
      closeCountLabel.textContent = `${selectedTabIds.size} selected`;
    } else {
      closeBtn.disabled = true;
      closeCountLabel.textContent = '';
    }

    const allSuggestedSelected = suggestedTabs.length > 0 && suggestedTabs.every(t => selectedTabIds.has(t.id));
    if (allSuggestedSelected) {
      selectAllCheck.parentElement.classList.add('selected');
    } else {
      selectAllCheck.parentElement.classList.remove('selected');
    }
  }

  function createTabElement(tab) {
    const div = document.createElement('div');
    div.className = 'tab-item';
    div.dataset.tabId = tab.id;
    if (selectedTabIds.has(tab.id)) {
      div.classList.add('selected');
    }

    // Checkbox
    const checkbox = document.createElement('div');
    checkbox.className = 'tab-checkbox';
    checkbox.innerHTML = '<svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="#11111b" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="2 6 5 9 10 3"></polyline></svg>';

    // Title
    const titleSpan = document.createElement('span');
    titleSpan.className = 'tab-title';
    titleSpan.textContent = tab.title || tab.url;
    titleSpan.title = tab.url || '';

    // Pop-out icon on hover
    const popout = document.createElement('div');
    popout.className = 'tab-popout';
    popout.title = 'Switch to this tab';
    popout.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg>';

    popout.addEventListener('click', (e) => {
      e.stopPropagation();
      if (invoke) {
        invoke('focus_tab', { tabId: tab.id, windowId: tab.windowId }).catch(console.error);
      }
    });

    div.appendChild(checkbox);
    div.appendChild(titleSpan);
    div.appendChild(popout);

    div.addEventListener('click', () => {
      if (selectedTabIds.has(tab.id)) {
        selectedTabIds.delete(tab.id);
        div.classList.remove('selected');
      } else {
        selectedTabIds.add(tab.id);
        div.classList.add('selected');
      }
      updateProgressBar();
    });

    return div;
  }

  function renderAll() {
    selectedTabIds.clear();

    // Suggested Tabs
    suggestedList.innerHTML = '';
    suggestedCountEl.textContent = suggestedTabs.length;
    if (suggestedTabs.length > 0) {
      suggestedTabs.forEach(tab => suggestedList.appendChild(createTabElement(tab)));
    } else {
      suggestedList.innerHTML = '<div style="color: #6c7086; text-align: center; padding: 10px; font-size: 0.78rem;">No suggested tabs to close.</div>';
    }

    // Other Tabs
    otherList.innerHTML = '';
    otherCountEl.textContent = otherTabs.length;
    if (otherTabs.length > 0) {
      otherTabs.forEach(tab => otherList.appendChild(createTabElement(tab)));
    } else {
      otherList.innerHTML = '<div style="color: #6c7086; text-align: center; padding: 10px; font-size: 0.78rem;">No other open tabs.</div>';
    }

    // Desktop Apps
    desktopList.innerHTML = '';
    desktopCountEl.textContent = desktopApps.length;
    if (desktopApps.length > 0) {
      desktopApps.forEach(app => {
        const div = document.createElement('div');
        div.className = 'desktop-item';

        const title = document.createElement('span');
        title.className = 'desktop-title';
        title.textContent = app.title;
        title.title = `${app.title} (PID: ${app.pid})`;

        const mem = document.createElement('span');
        mem.className = 'desktop-mem';
        mem.textContent = `${app.memory_mb} MB`;

        const actions = document.createElement('div');
        actions.className = 'desktop-actions';

        const focusBtn = document.createElement('span');
        focusBtn.className = 'desktop-btn desktop-focus';
        focusBtn.textContent = 'Focus';
        focusBtn.addEventListener('click', () => {
          if (invoke) invoke('focus_desktop_app', { hwnd: app.hwnd }).catch(console.error);
        });

        const closeBtnApp = document.createElement('span');
        closeBtnApp.className = 'desktop-btn desktop-close';
        closeBtnApp.textContent = 'Close';
        closeBtnApp.addEventListener('click', () => {
          if (invoke) invoke('close_desktop_app', { hwnd: app.hwnd }).catch(console.error);
          div.remove();
        });

        actions.appendChild(focusBtn);
        actions.appendChild(closeBtnApp);

        div.appendChild(title);
        div.appendChild(mem);
        div.appendChild(actions);

        desktopList.appendChild(div);
      });
    } else {
      desktopList.innerHTML = '<div style="color: #6c7086; text-align: center; padding: 10px; font-size: 0.78rem;">No heavy desktop apps detected.</div>';
    }

    updateProgressBar();
  }

  // Select All Suggested Toggle
  selectAllEl.addEventListener('click', () => {
    const allSuggestedSelected = suggestedTabs.length > 0 && suggestedTabs.every(t => selectedTabIds.has(t.id));
    if (allSuggestedSelected) {
      suggestedTabs.forEach(t => selectedTabIds.delete(t.id));
    } else {
      suggestedTabs.forEach(t => selectedTabIds.add(t.id));
    }
    
    const items = suggestedList.querySelectorAll('.tab-item');
    items.forEach(div => {
      const id = parseInt(div.dataset.tabId, 10);
      if (selectedTabIds.has(id)) {
        div.classList.add('selected');
      } else {
        div.classList.remove('selected');
      }
    });

    updateProgressBar();
  });

  try {
    const tauri = window.__TAURI__ || {};
    invoke = (tauri.core && tauri.core.invoke) || tauri.invoke;
    listen = (tauri.event && tauri.event.listen) || tauri.listen;

    if (!invoke || !listen) {
      throw new Error("Tauri APIs not found in window.__TAURI__");
    }

    dismissBtn.addEventListener("click", () => {
      invoke('hide_window').catch(console.error);
    });

    closeBtn.addEventListener("click", async () => {
      if (selectedTabIds.size === 0) return;
      closeBtn.textContent = "Closing...";
      closeBtn.disabled = true;
      try {
        await invoke('close_tabs', { tabIds: Array.from(selectedTabIds) });
      } catch (e) {
        console.error(e);
      }
      setTimeout(() => {
        invoke('hide_window').catch(console.error);
        closeBtn.textContent = "Close Selected";
        closeBtn.disabled = false;
      }, 500);
    });

    await listen('tab-warning', (event) => {
      const data = event.payload;
      totalTabCount = data.tabCount || 0;
      threshold = data.threshold || 15;
      tabCountEl.textContent = totalTabCount;
      suggestedTabs = data.tabs || [];
      otherTabs = data.otherTabs || [];
      desktopApps = data.desktopApps || [];
      renderAll();
    });

    await listen('tab-resolved', () => {
      isSuccessState = true;
      setAvatarImage(successAvatar);
    });
  } catch (err) {
    console.error("Frontend Error:", err);
    suggestedList.innerHTML = `<div style="color: #f38ba8; padding: 20px;">Error: ${err.message}</div>`;
  }
});

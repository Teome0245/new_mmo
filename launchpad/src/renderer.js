const { ipcRenderer } = require('electron');

let servers = [];
let selectedServerId = 'prime';
let activeProfileId = 'prime';

document.getElementById('min-btn').addEventListener('click', () => {
  ipcRenderer.send('window-control', 'minimize');
});

document.getElementById('close-btn').addEventListener('click', () => {
  ipcRenderer.send('window-control', 'close');
});

const keepOpenCb = document.getElementById('keep-open-cb');
keepOpenCb.checked = localStorage.getItem('keepOpen') === 'true';
keepOpenCb.addEventListener('change', (e) => {
  localStorage.setItem('keepOpen', e.target.checked);
});

const serverSelect = document.getElementById('server-select');
const profileLabel = document.getElementById('active-profile-label');
const diskWarning = document.getElementById('disk-warning');

serverSelect.addEventListener('change', () => {
  selectedServerId = serverSelect.value;
  localStorage.setItem('selectedServerId', selectedServerId);
  ipcRenderer.send('select-server', selectedServerId);
  renderServerStatuses(lastStatusRows);
});

document.getElementById('update-btn').addEventListener('click', () => {
  ipcRenderer.send('manual-update-check');
});

const playBtn = document.getElementById('play-btn');
const statusMsg = document.getElementById('status-message');

playBtn.addEventListener('click', () => {
  if (!playBtn.disabled && playBtn.textContent.startsWith('JOUER')) {
    playBtn.disabled = true;
    playBtn.textContent = 'LANCEMENT...';
    statusMsg.textContent = '';
    ipcRenderer.send('launch-game', keepOpenCb.checked);
  }
});

const gameDirInput = document.getElementById('game-dir-input');
const gameExeInput = document.getElementById('game-exe-input');
const gameExeLabel = document.getElementById('game-exe-label');
const pathHint = document.getElementById('path-settings-hint');

function applyPathFields(cfg) {
  if (!cfg) return;
  activeProfileId = cfg.profileId || activeProfileId;
  if (gameDirInput) gameDirInput.value = cfg.gameDir || '';
  if (gameExeInput) {
    gameExeInput.value = cfg.gameExeRelative || cfg.gameExe || '';
    const base = cfg.profileId === 'prime' ? 'lbgemu.exe' : 'SWGEmu.exe';
    gameExeInput.placeholder = cfg.gameExeConfigured ? '' : `Par défaut : ${base}`;
  }
  if (gameExeLabel) {
    gameExeLabel.textContent =
      cfg.profileId === 'prime' ? 'lbgemu.exe' : 'SWGEmu.exe';
  }
  if (profileLabel) {
    profileLabel.textContent = cfg.profileLabel
      ? `Client : ${cfg.profileLabel}`
      : '';
  }
}

function renderDiskWarning(disk) {
  if (!diskWarning || !disk) return;
  diskWarning.textContent = disk.message || '';
  diskWarning.classList.toggle('disk-warning--ok', Boolean(disk.ok));
  diskWarning.classList.toggle('disk-warning--low', disk.ok === false);
}

document.getElementById('browse-dir-btn')?.addEventListener('click', () => {
  ipcRenderer.send('browse-game-dir');
});

document.getElementById('browse-exe-btn')?.addEventListener('click', () => {
  ipcRenderer.send('browse-game-exe');
});

document.getElementById('save-paths-btn')?.addEventListener('click', () => {
  ipcRenderer.send('save-path-settings', {
    gameDir: gameDirInput?.value || '',
    gameExe: gameExeInput?.value || '',
  });
});

ipcRenderer.on('browse-result', (event, result) => {
  if (result.canceled) return;
  if (result.gameDir) gameDirInput.value = result.gameDir;
  if (result.gameExe) gameExeInput.value = result.gameExe;
});

ipcRenderer.on('path-settings-saved', (event, result) => {
  if (!result.ok) {
    pathHint.style.color = '#ff3333';
    pathHint.textContent = result.message || 'Erreur enregistrement';
    return;
  }
  applyPathFields(result);
  pathHint.style.color = '#00ff66';
  pathHint.textContent = `Profil « ${result.profileLabel || activeProfileId} » enregistré.`;
});

ipcRenderer.on('active-profile', (event, profile) => {
  applyPathFields(profile);
});

ipcRenderer.on('config', (event, cfg) => {
  servers = cfg.servers || [];
  selectedServerId =
    localStorage.getItem('selectedServerId') || cfg.defaultServerId || servers[0]?.id;
  serverSelect.innerHTML = servers
    .map((s) => `<option value="${s.id}">${s.label}</option>`)
    .join('');
  serverSelect.value = selectedServerId;
  ipcRenderer.send('select-server', selectedServerId);
  applyPathFields(cfg);
  renderDiskWarning(cfg.diskSpace);
});

ipcRenderer.on('launch-status', (event, response) => {
  if (response.error) {
    playBtn.disabled = false;
    playBtn.textContent = playLabel();
    statusMsg.style.color = '#ff3333';
    statusMsg.textContent = response.message;
  } else {
    statusMsg.style.color = '#00ff66';
    statusMsg.textContent = response.message;
    if (!keepOpenCb.checked) {
      playBtn.textContent = 'LANCÉ';
    } else {
      playBtn.disabled = false;
      playBtn.textContent = playLabel();
    }
  }
});

let lastStatusRows = [];

function playLabel() {
  const sel = lastStatusRows.find((r) => r.id === selectedServerId);
  if (sel && !sel.online) return 'JOUER (HORS-LIGNE)';
  return 'JOUER';
}

function renderServerStatuses(rows) {
  lastStatusRows = rows;
  const box = document.getElementById('servers-status');
  if (!rows.length) {
    box.innerHTML = '<span class="muted">État serveurs inconnu</span>';
    return;
  }
  box.innerHTML = rows
    .map((s) => {
      const cls = s.ready ? 'online' : s.online ? 'starting' : 'offline';
      const label = s.ready ? 'En ligne' : s.online ? 'Démarrage' : 'Hors ligne';
      const active = s.id === selectedServerId ? ' active' : '';
      const host = s.host ? `${s.host}` : '';
      const meta = host ? `${label} · ${host}` : label;
      return `<div class="server-pill${active}" data-id="${s.id}">
        <span class="dot ${cls}"></span>
        <span><strong>${s.label}</strong><br><span class="meta">${meta}</span></span>
      </div>`;
    })
    .join('');
  playBtn.disabled = false;
  playBtn.textContent = playLabel();
}

ipcRenderer.on('servers-status', (event, payload) => {
  renderServerStatuses(payload.servers || []);
  if (payload.error) {
    statusMsg.style.color = '#fbbf24';
    statusMsg.textContent = 'API état serveurs indisponible — vérifiez le LAN / :8792';
  } else if (payload.stale) {
    statusMsg.style.color = '#fbbf24';
    statusMsg.textContent = 'Actualisation serveurs lente — dernier état conservé (:8792)';
  } else if (statusMsg.textContent.includes('Actualisation serveurs lente') || statusMsg.textContent.includes('API état serveurs indisponible')) {
    statusMsg.textContent = '';
  }
});

ipcRenderer.on('patch-status', (event, data) => {
  const progressContainer = document.getElementById('progress-container');
  if (data.status === 'checking') {
    playBtn.disabled = true;
    playBtn.textContent = 'VÉRIFICATION...';
    statusMsg.textContent = data.message;
    progressContainer.style.display = 'none';
  } else if (data.status === 'patching') {
    playBtn.disabled = true;
    playBtn.textContent = 'MISE À JOUR';
    statusMsg.textContent = data.message;
    progressContainer.style.display = 'block';
  } else if (data.status === 'ready') {
    playBtn.disabled = false;
    playBtn.textContent = playLabel();
    statusMsg.style.color = '#00ff66';
    statusMsg.textContent = data.message || 'Prêt à jouer.';
    progressContainer.style.display = 'none';
  } else if (data.status === 'error') {
    playBtn.disabled = false;
    playBtn.textContent = playLabel();
    statusMsg.style.color = '#ff3333';
    statusMsg.textContent = data.message;
    progressContainer.style.display = 'none';
  }
});

ipcRenderer.on('patch-progress', (event, data) => {
  document.getElementById('progress-bar').style.width = `${data.percent}%`;
  document.getElementById('progress-text').textContent = `${data.percent}% (${data.file})`;
});

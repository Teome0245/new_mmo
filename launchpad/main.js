const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const http = require('http');
const https = require('https');
const crypto = require('crypto');

const LAUNCHPAD_VERSION = '2.0.5';
const STATUS_API_TIMEOUT_MS = 12000;
const STATUS_API_FAIL_THRESHOLD = 2;
const PRECU_HOST_LAN = '192.168.0.245';
const PRIME_HOST_LAN = '192.168.0.246';

/** Dossier de l’exe (config.json à côté du .exe). */
function appRoot() {
  return app.isPackaged ? path.dirname(process.execPath) : __dirname;
}

/** Racine de l’app (index.html dans app.asar quand packagé). */
function appDir() {
  return __dirname;
}

function configPath() {
  return path.join(appRoot(), 'launchpad.config.json');
}

function defaultProfiles() {
  const swgRoot = 'J:\\swgemu';
  return [
    {
      id: 'precu',
      label: 'SWGEmu PreCu (original)',
      gameDir: path.join(swgRoot, 'StarWarsGalaxies'),
      gameExe: 'SWGEmu.exe',
      configFile: 'swgemu.cfg',
      patchChannel: 'precu',
      servers: [
        { id: 'precu', label: 'LBG SWGEMU PreCu', ip: PRECU_HOST_LAN, loginPort: 44453 },
      ],
    },
    {
      id: 'prime',
      label: 'LBG Prime',
      gameDir: path.join(swgRoot, 'clients', 'prime-lbg'),
      gameExe: 'lbgemu.exe',
      configFile: 'swgemu.cfg',
      patchChannel: 'prime',
      servers: [
        { id: 'prime', label: 'LBG MMO Serveur Prime', ip: PRIME_HOST_LAN, loginPort: 44553 },
      ],
    },
  ];
}

function defaultConfig() {
  return {
    launchpadVersion: LAUNCHPAD_VERSION,
    statusApiUrl: 'http://192.168.0.245:8792/api/servers',
    patchServerUrl: 'http://192.168.0.245:8080',
    patchServerUrlNas: '',
    diskSpaceWarningGb: 40,
    defaultProfileId: 'prime',
    profiles: defaultProfiles(),
  };
}

/** Ancien format (gameDir unique + servers[]) → profils PreCu / Prime. */
function migrateLegacyConfig(legacy) {
  const swgRoot = legacy.gameDir
    ? path.dirname(legacy.gameDir.replace(/[/\\]+$/, ''))
    : 'J:\\swgemu';
  const legacyServers = Array.isArray(legacy.servers) ? legacy.servers : [];
  const precuServer = legacyServers.find((s) => s.id === 'precu') || {
    id: 'precu',
    label: 'LBG SWGEMU PreCu',
    ip: PRECU_HOST_LAN,
    loginPort: 44453,
  };
  const primeServer = legacyServers.find((s) => s.id === 'prime') || {
    id: 'prime',
    label: 'LBG MMO Serveur Prime',
    ip: PRIME_HOST_LAN,
    loginPort: 44553,
  };
  const precuDir = legacy.gameDir || path.join(swgRoot, 'StarWarsGalaxies');
  const defaultProf = legacy.defaultServerId === 'precu' ? 'precu' : 'prime';

  return {
    launchpadVersion: LAUNCHPAD_VERSION,
    statusApiUrl: legacy.statusApiUrl || defaultConfig().statusApiUrl,
    patchServerUrl: legacy.patchServerUrl || defaultConfig().patchServerUrl,
    patchServerUrlNas: legacy.patchServerUrlNas || '',
    diskSpaceWarningGb: legacy.diskSpaceWarningGb ?? 40,
    defaultProfileId: defaultProf,
    profiles: [
      {
        id: 'precu',
        label: 'SWGEmu PreCu (original)',
        gameDir: precuDir,
        gameExe: legacy.gameExe || 'SWGEmu.exe',
        configFile: legacy.configFile || 'swgemu.cfg',
        patchChannel: 'precu',
        servers: [precuServer],
      },
      {
        id: 'prime',
        label: 'LBG Prime',
        gameDir: path.join(swgRoot, 'clients', 'prime-lbg'),
        gameExe: 'lbgemu.exe',
        configFile: legacy.configFile || 'swgemu.cfg',
        patchChannel: 'prime',
        servers: [primeServer],
      },
    ],
  };
}

function migratePrecuHost246(cfg) {
  let changed = false;
  for (const profile of cfg.profiles || []) {
    for (const server of profile.servers || []) {
      if (server.id === 'precu' && server.ip === PRIME_HOST_LAN) {
        server.ip = PRECU_HOST_LAN;
        changed = true;
      }
    }
  }
  return changed;
}

function resolveApiClientHost(row, serverId) {
  if (row.client_ip) {
    return row.client_ip;
  }
  if (row.host && row.host !== '127.0.0.1' && row.host !== 'localhost') {
    return row.host;
  }
  return serverId === 'precu' ? PRECU_HOST_LAN : PRIME_HOST_LAN;
}

function applyStatusApiHosts(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return false;
  const idMap = { swgemu: 'precu', prime: 'prime' };
  let changed = false;
  for (const row of rows) {
    const serverId = idMap[row.id] || row.id;
    const host = resolveApiClientHost(row, serverId);
    for (const profile of config.profiles) {
      for (const server of profile.servers || []) {
        if (server.id === serverId && server.ip !== host) {
          server.ip = host;
          changed = true;
        }
      }
    }
  }
  if (changed) saveConfig(config);
  return changed;
}

function normalizeConfig(raw) {
  const base = defaultConfig();
  if (!raw || typeof raw !== 'object') {
    return base;
  }
  if (Array.isArray(raw.profiles) && raw.profiles.length > 0) {
    const normalized = {
      ...base,
      ...raw,
      profiles: raw.profiles.map((p) => ({
        ...p,
        servers: Array.isArray(p.servers) ? p.servers : [],
      })),
    };
    migratePrecuHost246(normalized);
    return normalized;
  }
  if (raw.gameDir || (Array.isArray(raw.servers) && raw.servers.length > 0)) {
    return migrateLegacyConfig(raw);
  }
  return base;
}

function flattenServers(profiles) {
  const rows = [];
  for (const profile of profiles) {
    for (const server of profile.servers || []) {
      rows.push({
        ...server,
        profileId: profile.id,
        profileLabel: profile.label,
      });
    }
  }
  return rows;
}

function loadConfig() {
  const cfgPath = configPath();
  try {
    if (fs.existsSync(cfgPath)) {
      const raw = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
      const normalized = normalizeConfig(raw);
      const migrated = migratePrecuHost246(normalized);
      if (
        !raw.profiles ||
        raw.launchpadVersion !== LAUNCHPAD_VERSION ||
        migrated
      ) {
        saveConfig(normalized);
      }
      return normalized;
    }
  } catch (err) {
    console.error('launchpad.config.json:', err.message);
  }
  const fresh = defaultConfig();
  try {
    saveConfig(fresh);
  } catch (e) {
    console.warn('save default config:', e.message);
  }
  return fresh;
}

function saveConfig(next) {
  const cfgPath = configPath();
  const out = { ...next, launchpadVersion: LAUNCHPAD_VERSION };
  fs.writeFileSync(cfgPath, `${JSON.stringify(out, null, 2)}\n`, 'utf8');
}

function getProfileById(profileId) {
  return config.profiles.find((p) => p.id === profileId) || config.profiles[0];
}

function getProfileForServer(serverId) {
  for (const profile of config.profiles) {
    if ((profile.servers || []).some((s) => s.id === serverId)) {
      return profile;
    }
  }
  return getProfileById(config.defaultProfileId);
}

function getServer(serverId) {
  for (const profile of config.profiles) {
    const hit = (profile.servers || []).find((s) => s.id === serverId);
    if (hit) return hit;
  }
  return flattenServers(config.profiles)[0];
}

function resolveGameExe(profile) {
  const raw = (profile.gameExe || '').trim();
  if (!raw) {
    return path.join(profile.gameDir, 'SWGEmu.exe');
  }
  if (path.isAbsolute(raw)) {
    return raw;
  }
  return path.join(profile.gameDir, raw);
}

function profilePathPayload(profile) {
  const gameExe = resolveGameExe(profile);
  return {
    profileId: profile.id,
    profileLabel: profile.label,
    gameDir: profile.gameDir,
    gameExe,
    gameExeRelative: profile.gameExe || path.basename(gameExe),
    gameExeConfigured: Boolean((profile.gameExe || '').trim()),
    configFile: profile.configFile || 'swgemu.cfg',
    patchChannel: profile.patchChannel || profile.id,
  };
}

function getFreeBytesForPath(targetPath) {
  const resolved = path.resolve(targetPath);
  if (process.platform === 'win32') {
    try {
      const drive = path.parse(resolved).root.replace(/\\$/, '');
      if (!drive) return null;
      const out = execSync(
        `wmic logicaldisk where "DeviceID='${drive}'" get FreeSpace /value`,
        { encoding: 'utf8', timeout: 8000 },
      );
      const m = out.match(/FreeSpace=(\d+)/);
      return m ? parseInt(m[1], 10) : null;
    } catch (err) {
      console.warn('disk space wmic:', err.message);
      return null;
    }
  }
  try {
    const { statfsSync } = fs;
    if (typeof statfsSync === 'function') {
      const st = statfsSync(resolved);
      return st.bsize * st.bavail;
    }
  } catch (_) {
    /* ignore */
  }
  return null;
}

function diskSpaceStatus() {
  const requiredGb = Number(config.diskSpaceWarningGb) || 40;
  const dirs = config.profiles.map((p) => p.gameDir).filter(Boolean);
  let minFree = null;
  for (const dir of dirs) {
    const free = getFreeBytesForPath(dir);
    if (free != null && (minFree == null || free < minFree)) {
      minFree = free;
    }
  }
  const freeGb = minFree != null ? minFree / (1024 ** 3) : null;
  return {
    requiredGb,
    freeGb: freeGb != null ? Math.round(freeGb * 10) / 10 : null,
    ok: freeGb == null ? true : freeGb >= requiredGb,
    message:
      freeGb == null
        ? `Prévoir environ ${requiredGb} Go libres pour les deux installations client complètes.`
        : freeGb >= requiredGb
          ? `Espace disque OK (${freeGb} Go libres, ${requiredGb} Go recommandés pour 2 clients).`
          : `Attention : ${freeGb} Go libres — environ ${requiredGb} Go recommandés (2 installations complètes).`,
  };
}

let config = loadConfig();
let mainWindow;
let selectedServerId =
  flattenServers(config.profiles).find((s) => s.id === config.defaultProfileId)?.id
  || flattenServers(config.profiles)[0]?.id
  || 'prime';
/** IP login par galaxie (API :8792 + repli LAN). */
let lastApiHosts = {
  precu: PRECU_HOST_LAN,
  prime: PRIME_HOST_LAN,
};
let lastGoodServerStatus = null;
let statusApiFailStreak = 0;

function getActiveProfile() {
  return getProfileForServer(selectedServerId);
}

function patchManifestUrls(patchChannel) {
  const base = (config.patchServerUrl || '').replace(/\/$/, '');
  const channel = patchChannel || 'precu';
  return [
    `${base}/patches/${channel}/manifest.json`,
    `${base}/manifest.json`,
  ];
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 720,
    frame: false,
    transparent: false,
    backgroundColor: '#0a0e17',
    show: false,
    center: true,
    resizable: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    mainWindow.focus();
  });

  const indexPath = path.join(appDir(), 'index.html');
  mainWindow.loadFile(indexPath).catch((err) => {
    console.error('loadFile failed:', indexPath, err);
    const logPath = path.join(appRoot(), 'launchpad-error.log');
    fs.writeFileSync(
      logPath,
      `index.html introuvable: ${indexPath}\n${err.stack || err}\n`,
      'utf8',
    );
  });

  mainWindow.webContents.once('did-finish-load', () => {
    sendConfigToRenderer();
    setTimeout(checkServerStatus, 500);
  });

  mainWindow.webContents.on('did-fail-load', (_ev, code, desc, url) => {
    console.error('did-fail-load', code, desc, url);
  });
}

function sendConfigToRenderer() {
  if (!mainWindow) return;
  const profile = getActiveProfile();
  const flat = flattenServers(config.profiles);
  mainWindow.webContents.send('config', {
    launchpadVersion: config.launchpadVersion,
    servers: flat,
    defaultServerId: selectedServerId,
    defaultProfileId: config.defaultProfileId,
    profiles: config.profiles.map((p) => profilePathPayload(p)),
    diskSpace: diskSpaceStatus(),
    ...profilePathPayload(profile),
  });
}

function httpGetJson(url, timeoutMs = 4000) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith('https') ? https : http;
    const req = lib.get(url, (res) => {
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(`HTTP ${res.statusCode}`));
      }
      let raw = '';
      res.on('data', (c) => {
        raw += c;
      });
      res.on('end', () => {
        try {
          resolve(JSON.parse(raw));
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(timeoutMs, () => {
      req.destroy();
      reject(new Error('timeout'));
    });
  });
}

async function fetchPatchManifest(patchChannel) {
  const urls = patchManifestUrls(patchChannel);
  let lastErr;
  for (const url of urls) {
    try {
      return await httpGetJson(url, 5000);
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr || new Error('manifest introuvable');
}

function mapStatusApiRows(rows) {
  applyStatusApiHosts(rows);
  for (const r of Array.isArray(rows) ? rows : []) {
    const id = r.id === 'swgemu' ? 'precu' : r.id === 'prime' ? 'prime' : r.id;
    lastApiHosts[id] = resolveApiClientHost(r, id);
  }
  return (Array.isArray(rows) ? rows : []).map((r) => {
    const id = r.id === 'swgemu' ? 'precu' : r.id === 'prime' ? 'prime' : r.id;
    const server = getServer(id);
    const host = lastApiHosts[id] || server?.ip || PRIME_HOST_LAN;
    return {
      id,
      label: r.label,
      host,
      online: Boolean(r.online),
      ready: Boolean(r.ready),
      status: r.status || (r.online ? 'ready' : 'offline'),
      pid: r.pid,
    };
  });
}

async function checkServerStatus() {
  if (!mainWindow) return;
  try {
    const rows = await httpGetJson(config.statusApiUrl, STATUS_API_TIMEOUT_MS);
    const mapped = mapStatusApiRows(rows);
    lastGoodServerStatus = mapped;
    statusApiFailStreak = 0;
    mainWindow.webContents.send('servers-status', { source: 'api', servers: mapped });
    return;
  } catch (err) {
    console.warn('status API:', err.message);
    statusApiFailStreak += 1;
    if (lastGoodServerStatus && statusApiFailStreak < STATUS_API_FAIL_THRESHOLD) {
      mainWindow.webContents.send('servers-status', {
        source: 'stale',
        servers: lastGoodServerStatus,
        stale: true,
      });
      return;
    }
  }
  const fallbackServers = lastGoodServerStatus
    ? lastGoodServerStatus
    : flattenServers(config.profiles).map((s) => ({
        ...s,
        online: false,
        ready: false,
        status: 'offline',
      }));
  mainWindow.webContents.send('servers-status', {
    source: lastGoodServerStatus ? 'stale-fallback' : 'fallback',
    servers: fallbackServers,
    error: !lastGoodServerStatus,
    stale: Boolean(lastGoodServerStatus),
  });
}

setInterval(checkServerStatus, 10000);

function resolveServerLoginEndpoint(server) {
  if (!server) {
    return { ip: PRIME_HOST_LAN, loginPort: 44553 };
  }
  let ip = lastApiHosts[server.id] || server.ip;
  if (server.id === 'precu' && ip === PRIME_HOST_LAN) {
    ip = PRECU_HOST_LAN;
  }
  if (server.id === 'prime' && (!ip || ip === PRECU_HOST_LAN)) {
    ip = PRIME_HOST_LAN;
  }
  const loginPort =
    server.loginPort || (server.id === 'precu' ? 44453 : 44553);
  return { ip, loginPort };
}

function patchLoginConfig(profile, server) {
  const loginCfgPath = path.join(profile.gameDir, 'swgemu_login.cfg');
  if (!fs.existsSync(loginCfgPath)) return;
  const { ip, loginPort } = resolveServerLoginEndpoint(server);
  let text = fs.readFileSync(loginCfgPath, 'utf8');
  text = text.replace(/loginServerAddress\d*=.*/g, `loginServerAddress0=${ip}`);
  text = text.replace(/loginServerPort\d*=.*/g, `loginServerPort0=${loginPort}`);
  fs.writeFileSync(loginCfgPath, text, 'utf8');
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

ipcMain.on('window-control', (event, action) => {
  if (action === 'minimize') mainWindow.minimize();
  if (action === 'close') app.quit();
});

ipcMain.on('select-server', (event, serverId) => {
  const flat = flattenServers(config.profiles);
  if (flat.some((s) => s.id === serverId)) {
    selectedServerId = serverId;
    const profile = getActiveProfile();
    event.reply('active-profile', profilePathPayload(profile));
  }
});

function normalizeGameExeForSave(gameDir, gameExe) {
  const trimmed = (gameExe || '').trim();
  if (!trimmed) return '';
  const absExe = path.isAbsolute(trimmed) ? trimmed : path.join(gameDir, trimmed);
  const rel = path.relative(gameDir, absExe);
  if (rel && !rel.startsWith('..') && !path.isAbsolute(rel)) {
    return rel;
  }
  return absExe;
}

ipcMain.on('save-path-settings', (event, payload) => {
  if (!payload || typeof payload !== 'object') return;
  const profile = getActiveProfile();
  if (!profile) {
    event.reply('path-settings-saved', { ok: false, message: 'Profil introuvable' });
    return;
  }
  if (typeof payload.gameDir === 'string' && payload.gameDir.trim()) {
    profile.gameDir = payload.gameDir.trim();
  }
  if (typeof payload.gameExe === 'string') {
    profile.gameExe = normalizeGameExeForSave(profile.gameDir, payload.gameExe);
  }
  try {
    saveConfig(config);
    const updated = profilePathPayload(profile);
    event.reply('path-settings-saved', { ok: true, ...updated });
  } catch (err) {
    event.reply('path-settings-saved', { ok: false, message: err.message });
  }
});

ipcMain.on('browse-game-dir', async (event) => {
  const profile = getActiveProfile();
  const result = await dialog.showOpenDialog(mainWindow, {
    title: `Dossier client — ${profile.label}`,
    properties: ['openDirectory'],
    defaultPath: profile.gameDir,
  });
  if (result.canceled || !result.filePaths?.[0]) {
    event.reply('browse-result', { canceled: true });
    return;
  }
  event.reply('browse-result', { canceled: false, gameDir: result.filePaths[0] });
});

ipcMain.on('browse-game-exe', async (event) => {
  const profile = getActiveProfile();
  const defaultExe = resolveGameExe(profile);
  const result = await dialog.showOpenDialog(mainWindow, {
    title: `Exécutable — ${profile.label}`,
    properties: ['openFile'],
    defaultPath: profile.gameDir,
    filters: [{ name: 'Client SWG', extensions: ['exe'] }],
  });
  if (result.canceled || !result.filePaths?.[0]) {
    event.reply('browse-result', { canceled: true });
    return;
  }
  const picked = result.filePaths[0];
  event.reply('browse-result', {
    canceled: false,
    gameExe: picked,
    gameDir: path.dirname(picked),
  });
});

ipcMain.on('launch-game', (event, keepOpen) => {
  const server = getServer(selectedServerId);
  const profile = getActiveProfile();
  const gamePath = resolveGameExe(profile);
  const cfgName = profile.configFile || 'swgemu.cfg';
  const cfgPath = path.join(profile.gameDir, cfgName);
  const disk = diskSpaceStatus();

  if (!disk.ok) {
    event.reply('launch-status', {
      error: true,
      message: disk.message,
    });
    return;
  }

  if (process.platform !== 'win32') {
    event.reply('launch-status', {
      error: true,
      message: 'Environnement non-Windows : lancement simulé uniquement.',
    });
    if (!keepOpen) setTimeout(() => app.quit(), 2000);
    return;
  }

  if (!fs.existsSync(gamePath)) {
    event.reply('launch-status', {
      error: true,
      message: `${path.basename(gamePath)} introuvable : ${gamePath}`,
    });
    return;
  }
  if (!fs.existsSync(cfgPath)) {
    event.reply('launch-status', {
      error: true,
      message: `Fichier config introuvable : ${cfgPath}`,
    });
    return;
  }

  try {
    patchLoginConfig(profile, server);
    const args = ['-s', cfgName];
    const gameProcess = spawn(gamePath, args, {
      cwd: profile.gameDir,
      detached: false,
      stdio: 'ignore',
    });
    gameProcess.on('error', (spawnErr) => {
      event.reply('launch-status', {
        error: true,
        message: `Impossible de lancer ${path.basename(gamePath)} : ${spawnErr.message}`,
      });
    });
    gameProcess.on('exit', (code, signal) => {
      if (code !== null && code !== 0) {
        event.reply('launch-status', {
          error: true,
          message: `Client arrêté immédiatement (code ${code}). Voir docs/troubleshoot_lbgemu_launch.md — script recover_prime_client.ps1`,
        });
      }
    });
    setTimeout(() => {
      if (gameProcess.exitCode === null && gameProcess.signalCode === null) {
        gameProcess.unref();
        event.reply('launch-status', {
          error: false,
          message: `${profile.label} → ${server.label} (${server.ip}:${server.loginPort})`,
        });
        if (!keepOpen) app.quit();
      }
    }, 2500);
  } catch (error) {
    event.reply('launch-status', { error: true, message: error.message });
  }
});

ipcMain.on('manual-update-check', () => {
  checkUpdates();
});

function getFileHash(filePath) {
  return new Promise((resolve) => {
    const hash = crypto.createHash('md5');
    const stream = fs.createReadStream(filePath);
    stream.on('error', () => resolve(null));
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

function downloadFile(url, dest, onProgress) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    const lib = url.startsWith('https') ? https : http;
    lib
      .get(url, (response) => {
        if (response.statusCode !== 200) {
          return reject(new Error(`Status: ${response.statusCode}`));
        }
        const len = parseInt(response.headers['content-length'], 10);
        let downloaded = 0;
        response.on('data', (chunk) => {
          downloaded += chunk.length;
          if (len) onProgress(Math.round((100.0 * downloaded) / len));
        });
        response.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
      })
      .on('error', (err) => {
        fs.unlink(dest, () => {});
        reject(err);
      });
  });
}

async function checkUpdates() {
  const profile = getActiveProfile();
  const channel = profile.patchChannel || profile.id;

  mainWindow.webContents.send('patch-status', {
    status: 'checking',
    message: `Vérification des mises à jour (${profile.label})…`,
  });

  try {
    const manifest = await fetchPatchManifest(channel);
    const filesToUpdate = [];
    let targetDir = profile.gameDir;
    if (process.platform !== 'win32') {
      targetDir = path.join(appRoot(), 'test_game_dir', channel);
      if (!fs.existsSync(targetDir)) fs.mkdirSync(targetDir, { recursive: true });
    }

    for (const file of manifest.files || []) {
      const filePath = path.join(targetDir, file.name);
      const localHash = await getFileHash(filePath);
      if (localHash !== file.hash) filesToUpdate.push(file);
    }

    const patchBase = (config.patchServerUrl || '').replace(/\/$/, '');

    if (filesToUpdate.length > 0) {
      mainWindow.webContents.send('patch-status', {
        status: 'patching',
        message: `[${channel}] Téléchargement de ${filesToUpdate.length} fichier(s)…`,
      });
      for (const file of filesToUpdate) {
        const filePath = path.join(targetDir, file.name);
        const dir = path.dirname(filePath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        const urls = [
          `${patchBase}/patches/${channel}/${file.name}`,
          `${patchBase}/${file.name}`,
        ];
        let ok = false;
        let lastErr;
        for (const url of urls) {
          try {
            await downloadFile(url, filePath, (percent) => {
              mainWindow.webContents.send('patch-progress', {
                percent,
                file: file.name,
              });
            });
            ok = true;
            break;
          } catch (err) {
            lastErr = err;
          }
        }
        if (!ok) throw lastErr || new Error(`Échec téléchargement ${file.name}`);
      }
    }

    // swgemu_login.cfg vient du patch serveur — réappliquer IP/port selon la galaxie choisie.
    const server = getServer(selectedServerId);
    patchLoginConfig(profile, server);

    mainWindow.webContents.send('patch-status', {
      status: 'ready',
      message: `[${channel}] Client à jour.`,
    });
  } catch (error) {
    console.error('Patch error:', error);
    mainWindow.webContents.send('patch-status', {
      status: 'error',
      message: `Mise à jour indisponible (${channel}) : ${error.message}`,
    });
  }
}

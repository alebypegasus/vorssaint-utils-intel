import React, { useCallback, useEffect, useState } from 'react';
import {
  Camera,
  Cpu,
  Disc,
  HardDrive,
  Inbox,
  Keyboard,
  Moon,
  Search,
  StickyNote,
  Sun,
  Wifi,
} from 'lucide-react';
import {
  APP_VERSION,
  INITIAL_AGENTS,
  INITIAL_CLIPBOARD,
  INITIAL_MIXER_CHANNELS,
  INITIAL_NOTES,
  INITIAL_SETTINGS,
  INITIAL_SHELF_ITEMS,
  INITIAL_SNIPPETS,
  WALLPAPER_PRESETS,
} from './data/catalog';
import {
  cleanJunkCaches,
  fetchInstalledApps,
  fetchListeningPorts,
  fetchOpenWindows,
  fetchSystemTelemetry,
  fetchWingetUpdates,
  focusWindow,
  installWingetPackage,
  killProcessByPid,
  scanJunkCaches,
  searchWingetPackages,
  setDisplayBrightness,
  setMasterAudio,
  snapActiveWindow,
  toggleKeepAwake,
  triggerUninstallApp,
} from './lib/bridge';
import type {
  AppSettings,
  ClipboardItem,
  InstalledAppEntry,
  JunkCategory,
  ListeningPortEntry,
  MixerAppChannel,
  OpenWindowEntry,
  OverlayId,
  ScratchpadNote,
  SettingsSectionId,
  ShelfItem,
  SystemTelemetry,
  TextSnippet,
  WingetPackage,
} from './types/vorssaint';
import { BrandMark } from './components/BrandMark';
import { DynamicIsland } from './components/DynamicIsland/DynamicIsland';
import { MenuPanel } from './components/MenuPanel/MenuPanel';
import { Overlays } from './components/Overlays/Overlays';
import { SettingsWindow } from './components/Settings/SettingsWindow';

const STORAGE_KEY = 'vorssaint_windows_settings_v1';

function loadSavedSettings(): AppSettings {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return INITIAL_SETTINGS;
    const parsed = JSON.parse(raw) as Partial<AppSettings>;
    return {
      ...INITIAL_SETTINGS,
      ...parsed,
      toggles: { ...INITIAL_SETTINGS.toggles, ...(parsed.toggles ?? {}) },
      installedFeatures: {
        ...INITIAL_SETTINGS.installedFeatures,
        ...(parsed.installedFeatures ?? {}),
      },
      shortcuts: { ...INITIAL_SETTINGS.shortcuts, ...(parsed.shortcuts ?? {}) },
    };
  } catch {
    return INITIAL_SETTINGS;
  }
}

export function App() {
  const [settings, setSettings] = useState<AppSettings>(loadSavedSettings);
  const [telemetry, setTelemetry] = useState<SystemTelemetry>({
    hostName: 'VORSSAINT-WIN11',
    osVersion: 'Windows 11',
    cpuBrand: 'Detecting Processor...',
    cpuPercent: 18,
    cpuCores: [16, 20, 14, 19],
    cpuTempC: 44,
    gpuPercent: 12,
    gpuTempC: 39,
    memoryUsedGb: 10.4,
    memoryTotalGb: 32,
    memoryPressure: 'Normal',
    batteryPercent: 86,
    batteryCharging: true,
    batteryTempC: 27,
    uptimeSeconds: 18200,
    downloadKbPerSec: 128,
    uploadKbPerSec: 24,
    keepAwakeActive: false,
    masterVolume: 68,
    masterMuted: false,
    disks: [],
    networks: [],
    topProcesses: [],
  });
  const [cpuHistory, setCpuHistory] = useState<number[]>([18, 22, 19, 25, 21, 20]);
  const [gpuHistory, setGpuHistory] = useState<number[]>([12, 14, 18, 15, 19, 14]);
  const [memHistory, setMemHistory] = useState<number[]>([38, 39, 39, 40, 40, 41]);
  const [batHistory, setBatHistory] = useState<number[]>([86, 86, 86, 86, 86, 86]);

  const [channels, setChannels] = useState<MixerAppChannel[]>(INITIAL_MIXER_CHANNELS);
  const [clipboard, setClipboard] = useState<ClipboardItem[]>(INITIAL_CLIPBOARD);
  const [snippets, setSnippets] = useState<TextSnippet[]>(INITIAL_SNIPPETS);
  const [shelfItems, setShelfItems] = useState<ShelfItem[]>(INITIAL_SHELF_ITEMS);
  const [notes, setNotes] = useState<ScratchpadNote[]>(INITIAL_NOTES);
  const [openWindows, setOpenWindows] = useState<OpenWindowEntry[]>([]);
  const [ports, setPorts] = useState<ListeningPortEntry[]>([]);
  const [junk, setJunk] = useState<JunkCategory[]>([]);
  const [installedApps, setInstalledApps] = useState<InstalledAppEntry[]>([]);
  const [wingetResults, setWingetResults] = useState<WingetPackage[]>([]);
  const [wingetUpdates, setWingetUpdates] = useState<WingetPackage[]>([]);
  const [activeOverlay, setActiveOverlay] = useState<OverlayId | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const showToast = useCallback((msg: string) => {
    setToast(msg);
    window.setTimeout(() => {
      setToast((prev) => (prev === msg ? null : prev));
    }, 2800);
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', settings.theme);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
    } catch {
      // ignore quota failures
    }
  }, [settings]);

  const refreshTelemetry = useCallback(async () => {
    const next = await fetchSystemTelemetry(
      telemetry.keepAwakeActive,
      telemetry.masterVolume,
      telemetry.masterMuted
    );
    setTelemetry(next);
    setCpuHistory((h) => [...h.slice(-24), Math.round(next.cpuPercent)]);
    setGpuHistory((h) => [...h.slice(-24), Math.round(next.gpuPercent)]);
    const memPct = next.memoryTotalGb > 0 ? Math.round((next.memoryUsedGb / next.memoryTotalGb) * 100) : 35;
    setMemHistory((h) => [...h.slice(-24), memPct]);
    setBatHistory((h) => [...h.slice(-24), next.batteryPercent ?? 100]);
  }, [telemetry.keepAwakeActive, telemetry.masterMuted, telemetry.masterVolume]);

  useEffect(() => {
    refreshTelemetry();
    scanJunkCaches().then(setJunk);
    fetchListeningPorts().then(setPorts);
    fetchOpenWindows().then(setOpenWindows);
    searchWingetPackages('').then(setWingetResults);
    fetchWingetUpdates().then(setWingetUpdates);
    fetchInstalledApps().then(setInstalledApps);

    const timer = window.setInterval(() => {
      refreshTelemetry();
    }, 2000);
    return () => window.clearInterval(timer);
  }, []);

  // Global keyboard shortcuts inside the desktop shell
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        fetchOpenWindows().then(setOpenWindows);
        setActiveOverlay((prev) => (prev === 'commandBar' ? null : 'commandBar'));
      }
      if (e.altKey && e.key.toLowerCase() === 'q') {
        e.preventDefault();
        fetchOpenWindows().then(setOpenWindows);
        setActiveOverlay('appSwitcher');
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  const copyToClipboard = useCallback(
    async (text: string) => {
      try {
        await navigator.clipboard.writeText(text);
        showToast('Copied to Windows Clipboard');
      } catch {
        showToast('Copied inside Vorssaint');
      }
    },
    [showToast]
  );

  const selectedWallpaper = WALLPAPER_PRESETS.find((w) => w.id === settings.selectedWallpaperId);
  const desktopBgStyle = selectedWallpaper ? { background: selectedWallpaper.gradient } : undefined;

  return (
    <div className="workspace-shell" style={desktopBgStyle}>
      {/* Software Night Warmth & Extra Dimmer Simulation Layer */}
      {(settings.softwareDimming > 0 || settings.nightWarmth > 25) && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            pointerEvents: 'none',
            zIndex: 95,
            background: `rgba(${Math.round(settings.nightWarmth * 1.4)}, ${Math.round(settings.nightWarmth * 0.45)}, 0, ${settings.nightWarmth / 320})`,
            boxShadow: `inset 0 0 0 9999px rgba(0, 0, 0, ${settings.softwareDimming / 110})`,
          }}
        />
      )}

      {/* Windows Notification Bar / Top Launcher */}
      <header className="topbar">
        <div className="topbar-left">
          <button
            type="button"
            className="tray-pill"
            onClick={() => setActiveOverlay('about')}
            title="Vorssaint Utils Windows Edition"
          >
            <BrandMark width={18} />
            <strong>Vorssaint</strong>
            <span style={{ color: 'var(--text-muted)', fontSize: 10.5 }}>v{APP_VERSION}</span>
          </button>

          <button
            type="button"
            className="tray-pill"
            onClick={() => {
              fetchOpenWindows().then(setOpenWindows);
              setActiveOverlay('commandBar');
            }}
          >
            <Search size={12} /> Command Bar <span className="tag-badge">Ctrl+K</span>
          </button>

          <button
            type="button"
            className="tray-pill"
            onClick={() => {
              fetchOpenWindows().then(setOpenWindows);
              setActiveOverlay('appSwitcher');
            }}
          >
            <Keyboard size={12} /> Switcher
          </button>

          <button type="button" className="tray-pill" onClick={() => setActiveOverlay('radialMenu')}>
            <Disc size={12} /> Radial
          </button>
          <button type="button" className="tray-pill" onClick={() => setActiveOverlay('fileShelf')}>
            <Inbox size={12} /> Shelf ({shelfItems.length})
          </button>
          <button type="button" className="tray-pill" onClick={() => setActiveOverlay('scratchpad')}>
            <StickyNote size={12} /> Notes
          </button>
          <button type="button" className="tray-pill" onClick={() => setActiveOverlay('screenCapture')}>
            <Camera size={12} /> Capture / OCR
          </button>
        </div>

        <div className="topbar-right">
          <button
            type="button"
            className={`tray-pill ${telemetry.keepAwakeActive ? 'active' : ''}`}
            onClick={async () => {
              const next = await toggleKeepAwake(!telemetry.keepAwakeActive, settings.toggles.keepAwakeDisplay);
              setTelemetry((prev) => ({ ...prev, keepAwakeActive: next }));
              showToast(next ? 'Keep Awake Enabled' : 'Keep Awake Standby');
            }}
          >
            <Moon size={12} />
            {telemetry.keepAwakeActive ? 'Awake' : 'Sleep OK'}
          </button>

          <button
            type="button"
            className="tray-pill tabular"
            onClick={() => setSettings((s) => ({ ...s, activeTab: 'system', activeSubview: 'home' }))}
          >
            <Cpu size={12} style={{ color: 'var(--accent-blue)' }} />
            CPU {Math.round(telemetry.cpuPercent)}%
          </button>

          <button
            type="button"
            className="tray-pill tabular"
            onClick={() => setSettings((s) => ({ ...s, activeTab: 'network', activeSubview: 'home' }))}
          >
            <Wifi size={12} style={{ color: 'var(--accent-green)' }} />
            {telemetry.downloadKbPerSec.toFixed(0)} KB/s
          </button>

          <button
            type="button"
            className="tray-pill tabular"
            onClick={() => setSettings((s) => ({ ...s, activeTab: 'disk', activeSubview: 'home' }))}
          >
            <HardDrive size={12} />
            {(telemetry.disks[0]?.availableGb ?? 412).toFixed(0)} GB free
          </button>

          <button
            type="button"
            className="tray-pill"
            onClick={() => setSettings((s) => ({ ...s, theme: s.theme === 'dark' ? 'light' : 'dark' }))}
            title="Toggle Dark / Light theme"
          >
            <Sun size={12} />
          </button>
        </div>
      </header>

      {/* Top-Center Dynamic Island */}
      <DynamicIsland
        enabled={settings.toggles.dynamicIslandEnabled && settings.installedFeatures.notch !== false}
        agents={INITIAL_AGENTS}
        shelfItems={shelfItems}
        showLyrics={settings.toggles.dynamicIslandLyrics}
        showEqualizer={settings.toggles.dynamicIslandEqualizer}
        showMascot={settings.toggles.dynamicIslandMascot}
        onOpenOverlay={(id) => setActiveOverlay(id)}
      />

      {/* Main Split Desktop Workspace */}
      <div className="desktop-stage" style={{ paddingTop: settings.toggles.dynamicIslandEnabled ? 46 : 16 }}>
        <MenuPanel
          settings={settings}
          telemetry={telemetry}
          cpuHistory={cpuHistory}
          gpuHistory={gpuHistory}
          memHistory={memHistory}
          batHistory={batHistory}
          channels={channels}
          clipboard={clipboard}
          ports={ports}
          junk={junk}
          installedApps={installedApps}
          wingetResults={wingetResults}
          wingetUpdates={wingetUpdates}
          onChangeTab={(activeTab) => setSettings((s) => ({ ...s, activeTab }))}
          onChangeSubview={(activeSubview) => setSettings((s) => ({ ...s, activeSubview }))}
          onToggleKeepAwake={async () => {
            const next = await toggleKeepAwake(!telemetry.keepAwakeActive, settings.toggles.keepAwakeDisplay);
            setTelemetry((prev) => ({ ...prev, keepAwakeActive: next }));
            showToast(next ? 'Keep Windows Awake active' : 'Keep Awake turned off');
          }}
          onChangeKeepAwakeDuration={(keepAwakeDuration) => setSettings((s) => ({ ...s, keepAwakeDuration }))}
          onSetMasterVolume={async (vol) => {
            const res = await setMasterAudio(vol, false);
            setTelemetry((prev) => ({ ...prev, masterVolume: res.volume, masterMuted: res.muted }));
          }}
          onToggleMasterMute={async () => {
            const res = await setMasterAudio(undefined, !telemetry.masterMuted);
            setTelemetry((prev) => ({ ...prev, masterVolume: res.volume, masterMuted: res.muted }));
          }}
          onUpdateChannel={(id, patch) =>
            setChannels((prev) => prev.map((ch) => (ch.id === id ? { ...ch, ...patch } : ch)))
          }
          onSetBrightness={async (brightnessLevel) => {
            setSettings((s) => ({ ...s, brightnessLevel }));
            await setDisplayBrightness(brightnessLevel);
          }}
          onSetWarmth={(nightWarmth) => setSettings((s) => ({ ...s, nightWarmth }))}
          onSetSoftwareDimming={(softwareDimming) => setSettings((s) => ({ ...s, softwareDimming }))}
          onSetFanPreset={(fanPreset) => {
            const rpmMap = { auto: 2200, silent: 1500, balanced: 2450, performance: 4300 };
            setSettings((s) => ({ ...s, fanPreset, fanRpm: rpmMap[fanPreset] }));
          }}
          onSetFanRpm={(fanRpm) => setSettings((s) => ({ ...s, fanRpm }))}
          onSelectWallpaper={(selectedWallpaperId, wallpaperCategory) => {
            setSettings((s) => ({ ...s, selectedWallpaperId, wallpaperCategory }));
            showToast('Applied workspace wallpaper preset');
          }}
          onToggleControl={(key) =>
            setSettings((s) => ({ ...s, toggles: { ...s.toggles, [key]: !s.toggles[key] } }))
          }
          onOpenOverlay={(id) => {
            fetchOpenWindows().then(setOpenWindows);
            setActiveOverlay(id);
          }}
          onFocusSettings={(sec?: SettingsSectionId) => {
            if (sec) setSettings((s) => ({ ...s, activeSettingsSection: sec }));
          }}
          onRefreshPorts={async () => {
            const next = await fetchListeningPorts();
            setPorts(next);
            showToast(`Scanned ${next.length} listening ports`);
          }}
          onKillPid={async (pid) => {
            const ok = await killProcessByPid(pid);
            showToast(ok ? `Terminated PID ${pid}` : `Could not terminate PID ${pid}`);
            fetchListeningPorts().then(setPorts);
            refreshTelemetry();
          }}
          onScanJunk={async () => {
            const res = await scanJunkCaches();
            setJunk(res);
            showToast(`Found ${res.reduce((a, b) => a + b.sizeMb, 0).toFixed(1)} MB across caches`);
          }}
          onCleanJunk={async () => {
            const freed = await cleanJunkCaches(junk.map((j) => j.id));
            showToast(`Reclaimed ${freed.toFixed(1)} MB cleanly`);
            scanJunkCaches().then(setJunk);
          }}
          onRefreshApps={async () => {
            const apps = await fetchInstalledApps();
            setInstalledApps(apps);
            showToast(`Loaded ${apps.length} Windows Registry apps`);
          }}
          onUninstallApp={async (cmd) => {
            const msg = await triggerUninstallApp(cmd);
            showToast(msg);
          }}
          onSearchWinget={async (q) => {
            const pkgs = await searchWingetPackages(q);
            setWingetResults(pkgs);
          }}
          onRefreshWingetUpdates={async () => {
            const upd = await fetchWingetUpdates();
            setWingetUpdates(upd);
            showToast(`${upd.length} updates available via winget`);
          }}
          onInstallWinget={async (id) => {
            const msg = await installWingetPackage(id);
            showToast(msg);
          }}
          onSnapWindow={async (layout) => {
            await snapActiveWindow(layout);
            showToast(`Window snapped: ${layout}`);
          }}
          onClearClipboard={() => {
            setClipboard((prev) => prev.filter((item) => item.pinned));
            showToast('Cleared unpinned clipboard entries');
          }}
          onCopyClipboard={copyToClipboard}
          onPinClipboard={(id) =>
            setClipboard((prev) => prev.map((item) => (item.id === id ? { ...item, pinned: !item.pinned } : item)))
          }
          onToast={showToast}
        />

        <SettingsWindow
          settings={settings}
          telemetry={telemetry}
          snippets={snippets}
          onChangeSection={(activeSettingsSection) => setSettings((s) => ({ ...s, activeSettingsSection }))}
          onChangeTheme={(theme) => setSettings((s) => ({ ...s, theme }))}
          onChangeLocale={(locale) => setSettings((s) => ({ ...s, locale }))}
          onInstallFeature={(id, installed) => {
            setSettings((s) => ({
              ...s,
              installedFeatures: { ...s.installedFeatures, [id]: installed },
            }));
          }}
          onApplyBundle={(featureIds, replace) => {
            setSettings((s) => {
              const nextMap: Record<string, boolean> = replace
                ? Object.fromEntries(Object.keys(s.installedFeatures).map((k) => [k, false]))
                : { ...s.installedFeatures };
              featureIds.forEach((fid) => {
                nextMap[fid] = true;
              });
              return { ...s, installedFeatures: nextMap };
            });
            showToast('Applied feature bundle');
          }}
          onInstallAll={() => {
            setSettings((s) => ({
              ...s,
              installedFeatures: Object.fromEntries(Object.keys(s.installedFeatures).map((k) => [k, true])),
            }));
            showToast('Installed all features');
          }}
          onUninstallAll={() => {
            setSettings((s) => ({
              ...s,
              installedFeatures: Object.fromEntries(Object.keys(s.installedFeatures).map((k) => [k, false])),
            }));
            showToast('Uninstalled optional modules');
          }}
          onToggleControl={(key) =>
            setSettings((s) => ({ ...s, toggles: { ...s.toggles, [key]: !s.toggles[key] } }))
          }
          onUpdateShortcut={(action, combo) =>
            setSettings((s) => ({ ...s, shortcuts: { ...s.shortcuts, [action]: combo } }))
          }
          onSaveSnippets={setSnippets}
          onOpenOverlay={(id) => {
            fetchOpenWindows().then(setOpenWindows);
            setActiveOverlay(id);
          }}
          onExportBackup={() => {
            const payload = JSON.stringify({ settings, snippets }, null, 2);
            copyToClipboard(payload);
            showToast('Copied settings JSON backup to clipboard');
          }}
          onImportBackup={(jsonText) => {
            try {
              const parsed = JSON.parse(jsonText);
              if (parsed.settings) setSettings((s) => ({ ...s, ...parsed.settings }));
              if (Array.isArray(parsed.snippets)) setSnippets(parsed.snippets);
              showToast('Restored Vorssaint configuration backup');
            } catch {
              showToast('Invalid JSON backup payload');
            }
          }}
        />
      </div>

      {/* Interactive Overlays */}
      <Overlays
        activeOverlay={activeOverlay}
        openWindows={openWindows}
        clipboard={clipboard}
        snippets={snippets}
        shelfItems={shelfItems}
        notes={notes}
        keepAwake={telemetry.keepAwakeActive}
        onClose={() => setActiveOverlay(null)}
        onFocusWindow={focusWindow}
        onOpenOverlay={(id) => setActiveOverlay(id)}
        onToggleKeepAwake={async () => {
          const next = await toggleKeepAwake(!telemetry.keepAwakeActive, settings.toggles.keepAwakeDisplay);
          setTelemetry((prev) => ({ ...prev, keepAwakeActive: next }));
          showToast(next ? 'Keep Awake active' : 'Keep Awake off');
        }}
        onCopyText={copyToClipboard}
        onAddShelfItem={(item) => setShelfItems((prev) => [item, ...prev])}
        onRemoveShelfItem={(id) => setShelfItems((prev) => prev.filter((i) => i.id !== id))}
        onSaveNotes={setNotes}
        onSnapWindow={async (layout) => {
          await snapActiveWindow(layout);
          showToast(`Snapped foreground window: ${layout}`);
        }}
        onToast={showToast}
      />

      {/* Toast feedback */}
      {toast && (
        <div
          style={{
            position: 'fixed',
            bottom: 22,
            left: '50%',
            transform: 'translateX(-50%)',
            background: '#111318',
            color: '#fff',
            border: '1px solid rgba(255,255,255,0.16)',
            borderRadius: 999,
            padding: '7px 16px',
            fontSize: 12,
            fontWeight: 600,
            boxShadow: '0 12px 32px rgba(0,0,0,0.45)',
            zIndex: 110,
          }}
        >
          {toast}
        </div>
      )}
    </div>
  );
}

export default App;

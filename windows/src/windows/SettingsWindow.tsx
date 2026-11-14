import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Activity,
  Bot,
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  Clipboard,
  Columns,
  Command,
  Compass,
  Copy,
  Cpu,
  Download,
  ExternalLink,
  FileCheck,
  FileText,
  FolderOpen,
  Inbox,
  Info,
  Keyboard,
  Layers,
  LayoutGrid,
  Link2,
  Lock,
  Moon,
  Network,
  PackageX,
  PanelBottom,
  Pin,
  Pipette,
  Plus,
  RefreshCw,
  Scissors,
  Search,
  ShieldCheck,
  Sliders,
  Sparkles,
  Sun,
  Trash2,
  Volume2,
  VolumeX,
  Zap,
} from 'lucide-react';
import { BrandMark } from '../components/BrandMark';
import { MascotFace } from '../components/MascotFace';
import {
  APP_VERSION,
  FEATURE_BUNDLES,
  FEATURE_CATALOG,
  SIDEBAR_GROUPS,
  UI_LABELS,
} from '../data/catalog';
import {
  captureScreenPng,
  cleanJunkCaches,
  copyToClipboard,
  emptyRecycleBin,
  fetchSystemTelemetry,
  killProcessByPid,
  launchWindowsUtility,
  listAudioSessions,
  listInstalledApps,
  listListeningPorts,
  listOpenWindows,
  lockWorkstation,
  openExternalUrl,
  openOverlay,
  openPathInExplorer,
  pickScreenColor,
  safeListen,
  scanJunkCaches,
  setAppAudio,
  setDisplayBrightness,
  setMasterAudio,
  setWindowsDarkMode,
  snapActiveWindow,
  toggleTrayPanel,
  toggleWindowPin,
  triggerUninstallApp,
  wingetInstall,
  wingetListUpdates,
  wingetSearch,
  focusWindow,
} from '../lib/bridge';
import { useVorssaintStore } from '../lib/store';
import { cleanUrl } from '../lib/urlCleaner';
import type {
  AppAudioSession,
  FeatureGroupId,
  InstalledAppEntry,
  JunkCategory,
  ListeningPortEntry,
  LocaleCode,
  OpenWindowEntry,
  SettingsPageId,
  SystemTelemetry,
  TrayPanelSectionId,
  WingetPackage,
} from '../types/vorssaint';

const PAGE_ICONS: Record<string, React.ReactNode> = {
  sliders: <Sliders size={15} />,
  sparkles: <Sparkles size={15} />,
  panelBottom: <PanelBottom size={15} />,
  pill: <Sparkles size={15} />,
  bot: <Bot size={15} />,
  activity: <Activity size={15} />,
  volume2: <Volume2 size={15} />,
  zap: <Zap size={15} />,
  sun: <Sun size={15} />,
  layoutGrid: <LayoutGrid size={15} />,
  layers: <Layers size={15} />,
  search: <Search size={15} />,
  compass: <Compass size={15} />,
  keyboard: <Keyboard size={15} />,
  clipboard: <Clipboard size={15} />,
  inbox: <Inbox size={15} />,
  fileText: <FileText size={15} />,
  link2: <Link2 size={15} />,
  camera: <Camera size={15} />,
  trash2: <Trash2 size={15} />,
  packageX: <PackageX size={15} />,
  download: <Download size={15} />,
  network: <Network size={15} />,
  cpu: <Cpu size={15} />,
  info: <Info size={15} />,
  fileCheck: <FileCheck size={15} />,
};

const GROUP_LABELS: Record<FeatureGroupId, Record<LocaleCode, string>> = {
  dynamicIsland: { pt: 'Ilha Dinâmica', en: 'Dynamic Island', es: 'Isla Dinámica' },
  mouse: { pt: 'Mouse & Gestos', en: 'Mouse & Gestures', es: 'Ratón y Gestos' },
  windows: { pt: 'Janelas & Snap', en: 'Windows & Snap', es: 'Ventanas' },
  sound: { pt: 'Som & Mixer', en: 'Sound & Mixer', es: 'Sonido' },
  keyboard: { pt: 'Atalhos & Texto', en: 'Shortcuts & Text', es: 'Teclado' },
  energy: { pt: 'Energia & Brilho', en: 'Energy & Display', es: 'Energía' },
  monitor: { pt: 'Monitoramento', en: 'System Monitor', es: 'Monitor' },
  files: { pt: 'Arquivos & Clipboard', en: 'Files & Clipboard', es: 'Archivos' },
  utilities: { pt: 'Utilitários & Dev', en: 'Utilities & Dev', es: 'Utilidades' },
  system: { pt: 'Sistema', en: 'System', es: 'Sistema' },
};

const ACCENT_PRESETS = ['#38bdf8', '#818cf8', '#34d399', '#fbbf24', '#f472b6', '#fb7185'];

export const SettingsWindow: React.FC = () => {
  const {
    settings,
    updateSettings,
    toggleFeature,
    installAllFeatures,
    applyBundle,
    clipboard,
    addClipboardEntry,
    togglePinClipboard,
    clearClipboard,
    shelf,
    removeShelfItem,
    clearShelf,
    snippets,
    saveSnippets,
    captures,
    toggleKeepAwakeState,
  } = useVorssaintStore();

  const labels = UI_LABELS[settings.language] ?? UI_LABELS.pt;
  const accent = settings.accentHex || '#38bdf8';

  const [history, setHistory] = useState<SettingsPageId[]>(['general']);
  const [histIdx, setHistIdx] = useState(0);
  const currentPage = history[histIdx] ?? 'general';

  const [sidebarSearch, setSidebarSearch] = useState('');
  const [featureSearch, setFeatureSearch] = useState('');
  const [featureGroup, setFeatureGroup] = useState<'all' | FeatureGroupId>('all');
  const [hubTab, setHubTab] = useState<'features' | 'permissions'>('features');
  const [toastMsg, setToastMsg] = useState<string | null>(null);

  // Live native states
  const [telemetry, setTelemetry] = useState<SystemTelemetry | null>(null);
  const [audioSessions, setAudioSessions] = useState<AppAudioSession[]>([]);
  const [openWindows, setOpenWindows] = useState<OpenWindowEntry[]>([]);
  const [ports, setPorts] = useState<ListeningPortEntry[]>([]);
  const [junkCats, setJunkCats] = useState<JunkCategory[]>([]);
  const [installedApps, setInstalledApps] = useState<InstalledAppEntry[]>([]);
  const [wingetUpdates, setWingetUpdates] = useState<WingetPackage[]>([]);
  const [wingetResults, setWingetResults] = useState<WingetPackage[]>([]);
  const [wingetQuery, setWingetQuery] = useState('');
  const [loadingPageData, setLoadingPageData] = useState(false);

  // Interactive tool inputs
  const [urlTestInput, setUrlTestInput] = useState(
    'https://github.com/trending?utm_source=twitter&fbclid=IwAR123456'
  );
  const [pickedColor, setPickedColor] = useState<string | null>(null);
  const [newTrigger, setNewTrigger] = useState(';');
  const [newExpansion, setNewExpansion] = useState('');
  const [clipFilter, setClipFilter] = useState('');

  const toast = useCallback((msg: string) => {
    setToastMsg(msg);
    window.setTimeout(() => {
      setToastMsg((c) => (c === msg ? null : c));
    }, 2500);
  }, []);

  const navigate = useCallback(
    (page: SettingsPageId) => {
      setHistory((prev) => {
        const sliced = prev.slice(0, histIdx + 1);
        if (sliced[sliced.length - 1] === page) return sliced;
        const next = [...sliced, page];
        setHistIdx(next.length - 1);
        return next;
      });
    },
    [histIdx]
  );

  useEffect(() => {
    const unsubPromise = safeListen<string>('navigate-settings', (page) => {
      if (page) navigate(page as SettingsPageId);
    });
    return () => {
      void unsubPromise.then((u) => u());
    };
  }, [navigate]);

  const loadPageData = useCallback(async (page: SettingsPageId) => {
    setLoadingPageData(true);
    try {
      const tel = await fetchSystemTelemetry();
      setTelemetry(tel);
      if (page === 'mixer') setAudioSessions(await listAudioSessions());
      if (page === 'switcher' || page === 'windowLayout')
        setOpenWindows(await listOpenWindows());
      if (page === 'portManager') setPorts(await listListeningPorts());
      if (page === 'cleaner') setJunkCats(await scanJunkCaches());
      if (page === 'uninstaller') setInstalledApps(await listInstalledApps());
      if (page === 'appUpdates') setWingetUpdates(await wingetListUpdates());
    } finally {
      setLoadingPageData(false);
    }
  }, []);

  useEffect(() => {
    void loadPageData(currentPage);
  }, [currentPage, loadPageData]);

  useEffect(() => {
    if (!['monitor', 'energy', 'killProcess', 'general'].includes(currentPage)) return;
    const id = window.setInterval(() => {
      void fetchSystemTelemetry().then(setTelemetry).catch(() => {});
    }, 2500);
    return () => window.clearInterval(id);
  }, [currentPage]);

  const installedCount = useMemo(
    () => FEATURE_CATALOG.filter((f) => settings.installedFeatures[f.key]).length,
    [settings.installedFeatures]
  );

  const filteredSidebar = useMemo(() => {
    const q = sidebarSearch.trim().toLowerCase();
    return SIDEBAR_GROUPS.map((g) => ({
      ...g,
      items: g.items.filter(
        (item) =>
          !q ||
          item.title[settings.language].toLowerCase().includes(q) ||
          item.page.toLowerCase().includes(q)
      ),
    })).filter((g) => g.items.length > 0);
  }, [sidebarSearch, settings.language]);

  const filteredFeatures = useMemo(() => {
    const q = featureSearch.trim().toLowerCase();
    return FEATURE_CATALOG.filter((f) => {
      if (featureGroup !== 'all' && f.group !== featureGroup) return false;
      if (!q) return true;
      return (
        f.title[settings.language].toLowerCase().includes(q) ||
        f.summary[settings.language].toLowerCase().includes(q) ||
        f.key.toLowerCase().includes(q)
      );
    });
  }, [featureSearch, featureGroup, settings.language]);

  const urlCleanPreview = cleanUrl(urlTestInput);

  return (
    <div
      className="v-shell"
      style={{
        width: '100vw',
        height: '100vh',
        display: 'grid',
        gridTemplateColumns: '246px 1fr',
        background: 'var(--bg-canvas)',
        overflow: 'hidden',
      }}
    >
      {/* SIDEBAR */}
      <aside
        style={{
          background: 'var(--surface-sidebar)',
          borderRight: '1px solid var(--border-subtle)',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}
      >
        {/* APP BRAND */}
        <div
          style={{
            padding: '16px 14px 12px',
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}
        >
          <BrandMark size={32} badge />
          <div>
            <div style={{ fontSize: 14, fontWeight: 700, letterSpacing: '-0.01em' }}>
              Vorssaint Utils
            </div>
            <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
              Windows v{APP_VERSION} · {installedCount}/{FEATURE_CATALOG.length}
            </div>
          </div>
        </div>

        {/* SEARCH */}
        <div style={{ padding: '0 12px 10px' }}>
          <div style={{ position: 'relative' }}>
            <Search
              size={13}
              color="var(--text-muted)"
              style={{ position: 'absolute', left: 10, top: 10 }}
            />
            <input
              className="v-input"
              value={sidebarSearch}
              onChange={(e) => setSidebarSearch(e.target.value)}
              placeholder={labels.searchSettings}
              style={{ paddingLeft: 30, fontSize: 12 }}
            />
          </div>
        </div>

        {/* NAV GROUPS */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 8px 14px', display: 'flex', flexDirection: 'column', gap: 14 }}>
          {filteredSidebar.map((group) => (
            <div key={group.id} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <div
                style={{
                  fontSize: 10.5,
                  fontWeight: 700,
                  textTransform: 'uppercase',
                  letterSpacing: '0.05em',
                  color: 'var(--text-muted)',
                  padding: '2px 10px 4px',
                }}
              >
                {group.title[settings.language]}
              </div>
              {group.items.map((item) => {
                const active = currentPage === item.page;
                return (
                  <button
                    key={item.page}
                    onClick={() => navigate(item.page)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 9,
                      padding: '7px 10px',
                      borderRadius: 9,
                      border: 'none',
                      background: active ? `${accent}24` : 'transparent',
                      color: active ? 'var(--text-primary)' : 'var(--text-secondary)',
                      fontSize: 12.5,
                      fontWeight: active ? 650 : 500,
                      cursor: 'pointer',
                      textAlign: 'left',
                    }}
                  >
                    <span style={{ color: active ? accent : 'var(--text-muted)', display: 'flex' }}>
                      {PAGE_ICONS[item.icon] ?? <Sliders size={15} />}
                    </span>
                    <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {item.title[settings.language]}
                    </span>
                  </button>
                );
              })}
            </div>
          ))}
        </div>

        {/* SIDEBAR QUICK LAUNCHERS */}
        <div
          style={{
            padding: 10,
            borderTop: '1px solid var(--border-subtle)',
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 6,
          }}
        >
          <button
            className="v-btn"
            style={{ fontSize: 11, padding: '6px 8px', justifyContent: 'center' }}
            onClick={() => void toggleTrayPanel()}
          >
            Painel Tray
          </button>
          <button
            className="v-btn"
            style={{ fontSize: 11, padding: '6px 8px', justifyContent: 'center' }}
            onClick={() => void openOverlay('command')}
          >
            Alt+Space
          </button>
        </div>
      </aside>

      {/* MAIN CONTENT */}
      <main style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* TOP NAVIGATION BAR */}
        <header
          style={{
            height: 52,
            padding: '0 20px',
            borderBottom: '1px solid var(--border-subtle)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexShrink: 0,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <button
              className="v-btn"
              style={{ padding: 6 }}
              disabled={histIdx <= 0}
              onClick={() => setHistIdx((i) => Math.max(0, i - 1))}
            >
              <ChevronLeft size={15} />
            </button>
            <button
              className="v-btn"
              style={{ padding: 6 }}
              disabled={histIdx >= history.length - 1}
              onClick={() => setHistIdx((i) => Math.min(history.length - 1, i + 1))}
            >
              <ChevronRight size={15} />
            </button>
            <h1 style={{ margin: 0, fontSize: 16, fontWeight: 700, letterSpacing: '-0.02em' }}>
              {SIDEBAR_GROUPS.flatMap((g) => g.items).find((i) => i.page === currentPage)
                ?.title[settings.language] ?? currentPage}
            </h1>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {toastMsg && (
              <span
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  padding: '4px 10px',
                  borderRadius: 999,
                  background: `${accent}24`,
                  color: accent,
                }}
              >
                {toastMsg}
              </span>
            )}
            <button
              className="v-btn"
              style={{ padding: '6px 10px', fontSize: 12 }}
              onClick={() => void loadPageData(currentPage)}
            >
              <RefreshCw size={13} className={loadingPageData ? 'animate-spin' : ''} />
              Atualizar
            </button>
          </div>
        </header>

        {/* SCROLLABLE PAGE BODY */}
        <div style={{ flex: 1, overflowY: 'auto', padding: 22 }}>
          <div style={{ maxWidth: 820, display: 'flex', flexDirection: 'column', gap: 16 }}>
            {/* GENERAL */}
            {currentPage === 'general' && (
              <>
                <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 14 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div style={{ fontSize: 14, fontWeight: 700 }}>Idioma da Interface</div>
                      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                        Sincronizado em todas as janelas (Ilha, Bandeja, Overlays e Ajustes)
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      {(['pt', 'en', 'es'] as LocaleCode[]).map((loc) => (
                        <button
                          key={loc}
                          className={`v-btn ${settings.language === loc ? 'v-btn-primary' : ''}`}
                          onClick={() => updateSettings({ language: loc })}
                        >
                          {loc.toUpperCase()}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div style={{ fontSize: 14, fontWeight: 700 }}>Aparência do App</div>
                      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                        Alterne o tema visual do Vorssaint Utils
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      {(['dark', 'light'] as const).map((m) => (
                        <button
                          key={m}
                          className={`v-btn ${settings.appearance === m ? 'v-btn-primary' : ''}`}
                          onClick={() => updateSettings({ appearance: m })}
                        >
                          {m === 'dark' ? 'Escuro' : 'Claro'}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div style={{ fontSize: 14, fontWeight: 700 }}>Modo Escuro Real do Windows</div>
                      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                        Atualiza HKCU AppsUseLightTheme & SystemUsesLightTheme
                      </div>
                    </div>
                    <button
                      className={`v-switch ${telemetry?.darkMode ? 'is-on' : ''}`}
                      onClick={async () => {
                        const ok = await setWindowsDarkMode(!(telemetry?.darkMode ?? true));
                        setTelemetry((p) => (p ? { ...p, darkMode: ok } : p));
                        toast(ok ? 'Windows Dark Mode aplicado' : 'Windows Light Mode aplicado');
                      }}
                    />
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ fontSize: 14, fontWeight: 700 }}>Cor de Destaque</div>
                    <div style={{ display: 'flex', gap: 8 }}>
                      {ACCENT_PRESETS.map((hex) => (
                        <button
                          key={hex}
                          onClick={() => updateSettings({ accentHex: hex })}
                          style={{
                            width: 24,
                            height: 24,
                            borderRadius: 999,
                            background: hex,
                            border:
                              settings.accentHex === hex
                                ? '2.5px solid #fff'
                                : '1px solid rgba(255,255,255,0.2)',
                            cursor: 'pointer',
                          }}
                        />
                      ))}
                    </div>
                  </div>
                </div>

                {/* QUICK ACTIONS ROW */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
                  <button className="v-btn" onClick={() => void openOverlay('command')}>
                    <Command size={14} color={accent} /> Abrir Command Bar
                  </button>
                  <button className="v-btn" onClick={() => void openOverlay('cleaning')}>
                    <ShieldCheck size={14} color="#fbbf24" /> Modo Limpeza de Tela
                  </button>
                  <button className="v-btn" onClick={() => void lockWorkstation()}>
                    <Lock size={14} color="#f87171" /> Bloquear Windows
                  </button>
                </div>
              </>
            )}

            {/* FEATURES HUB (80 FEATURES + 4 BUNDLES + PERMISSIONS) */}
            {currentPage === 'features' && (
              <>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      className={`v-btn ${hubTab === 'features' ? 'v-btn-primary' : ''}`}
                      onClick={() => setHubTab('features')}
                    >
                      {labels.featuresTab} ({installedCount}/{FEATURE_CATALOG.length})
                    </button>
                    <button
                      className={`v-btn ${hubTab === 'permissions' ? 'v-btn-primary' : ''}`}
                      onClick={() => setHubTab('permissions')}
                    >
                      {labels.permissionsTab}
                    </button>
                  </div>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="v-btn" onClick={() => installAllFeatures(true)}>
                      {labels.installAll}
                    </button>
                    <button className="v-btn" onClick={() => installAllFeatures(false)}>
                      {labels.uninstallAll}
                    </button>
                  </div>
                </div>

                {hubTab === 'features' ? (
                  <>
                    {/* BUNDLES */}
                    <div className="v-card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
                      <div>
                        <div style={{ fontSize: 13.5, fontWeight: 700 }}>{labels.bundlesTitle}</div>
                        <div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>{labels.bundlesSub}</div>
                      </div>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                        {FEATURE_BUNDLES.map((b) => (
                          <div
                            key={b.id}
                            style={{
                              padding: 11,
                              borderRadius: 11,
                              background: 'var(--surface-raised)',
                              border: '1px solid var(--border-subtle)',
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                              gap: 10,
                            }}
                          >
                            <div>
                              <div style={{ fontSize: 12.5, fontWeight: 700 }}>
                                {b.title[settings.language]}
                              </div>
                              <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>
                                {b.summary[settings.language]}
                              </div>
                            </div>
                            <button
                              className="v-btn v-btn-primary"
                              style={{ padding: '5px 10px', fontSize: 11.5 }}
                              onClick={() => {
                                applyBundle(b.id);
                                toast(`Pacote aplicado: ${b.title[settings.language]}`);
                              }}
                            >
                              {labels.applyBundle}
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* FILTER BAR */}
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                      <input
                        className="v-input"
                        value={featureSearch}
                        onChange={(e) => setFeatureSearch(e.target.value)}
                        placeholder="Filtrar entre os 80 recursos..."
                        style={{ maxWidth: 260 }}
                      />
                      {(['all', 'dynamicIsland', 'windows', 'sound', 'energy', 'files', 'utilities', 'monitor'] as const).map(
                        (g) => (
                          <button
                            key={g}
                            className={`v-btn ${featureGroup === g ? 'v-btn-primary' : ''}`}
                            style={{ padding: '5px 10px', fontSize: 11 }}
                            onClick={() => setFeatureGroup(g)}
                          >
                            {g === 'all' ? 'Todos' : GROUP_LABELS[g][settings.language]}
                          </button>
                        )
                      )}
                    </div>

                    {/* FEATURE LIST */}
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                      {filteredFeatures.map((feat) => {
                        const enabled = Boolean(settings.installedFeatures[feat.key]);
                        return (
                          <div
                            key={feat.key}
                            className="v-card"
                            style={{
                              padding: 12,
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                              gap: 10,
                            }}
                          >
                            <div style={{ minWidth: 0 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                <span style={{ fontSize: 12.5, fontWeight: 700 }}>
                                  {feat.title[settings.language]}
                                </span>
                                {feat.shortcut && (
                                  <span
                                    style={{
                                      fontSize: 10,
                                      padding: '1px 6px',
                                      borderRadius: 5,
                                      background: 'var(--surface-raised)',
                                      color: 'var(--text-muted)',
                                    }}
                                  >
                                    {feat.shortcut}
                                  </span>
                                )}
                              </div>
                              <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>
                                {feat.summary[settings.language]}
                              </div>
                            </div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              {feat.settingsPage && (
                                <button
                                  className="v-btn"
                                  style={{ padding: '4px 8px', fontSize: 10.5 }}
                                  onClick={() => navigate(feat.settingsPage!)}
                                >
                                  Abrir
                                </button>
                              )}
                              <button
                                className={`v-switch ${enabled ? 'is-on' : ''}`}
                                onClick={() => toggleFeature(feat.key)}
                              />
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </>
                ) : (
                  <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
                    <div style={{ fontSize: 14, fontWeight: 700 }}>Integrações Nativas do Windows</div>
                    {[
                      {
                        title: 'Atalhos Globais Win32 & Controle de Janelas',
                        desc: 'RegisterHotKey, SetWindowPos, HWND_TOPMOST sem necessidade de permissões manuais extras.',
                        ok: true,
                      },
                      {
                        title: 'Áudio CoreAudio por Aplicativo',
                        desc: 'Acesso nativo via IAudioSessionManager2 e IAudioEndpointVolume.',
                        ok: true,
                      },
                      {
                        title: 'Webcam & Privacidade do Windows',
                        desc: 'Usada apenas localmente na visualização de câmera da Ilha Dinâmica.',
                        ok: true,
                      },
                    ].map((perm) => (
                      <div
                        key={perm.title}
                        style={{
                          padding: 12,
                          borderRadius: 11,
                          background: 'var(--surface-raised)',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <div>
                          <div style={{ fontSize: 13, fontWeight: 650 }}>{perm.title}</div>
                          <div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>{perm.desc}</div>
                        </div>
                        <span style={{ color: '#34d399', fontSize: 12, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 4 }}>
                          <Check size={14} /> Pronto
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </>
            )}

            {/* PANEL CONFIG */}
            {currentPage === 'panelConfig' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ fontSize: 14, fontWeight: 700 }}>Seções visíveis no Painel da Bandeja</div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  {(
                    [
                      ['keepAwake', 'Manter Ligado & Mídia'],
                      ['mixer', 'Mixer CoreAudio'],
                      ['brightness', 'Brilho & Luz Noturna'],
                      ['system', 'CPU, RAM & Processos'],
                      ['network', 'Rede RX/TX'],
                      ['disk', 'Discos & Lixeira'],
                      ['power', 'Bateria & Energia'],
                      ['fan', 'Sensores Térmicos'],
                      ['utilities', 'Grade de Utilitários'],
                      ['toggles', 'Alternadores do Sistema'],
                    ] as [TrayPanelSectionId, string][]
                  ).map(([id, title]) => (
                    <div
                      key={id}
                      style={{
                        padding: '10px 12px',
                        borderRadius: 10,
                        background: 'var(--surface-raised)',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                      }}
                    >
                      <span style={{ fontSize: 12.5, fontWeight: 600 }}>{title}</span>
                      <button
                        className={`v-switch ${settings.panelVisibleSections[id] ? 'is-on' : ''}`}
                        onClick={() =>
                          updateSettings({
                            panelVisibleSections: {
                              ...settings.panelVisibleSections,
                              [id]: !settings.panelVisibleSections[id],
                            },
                          })
                        }
                      />
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* DYNAMIC ISLAND SETTINGS */}
            {(currentPage === 'notch' || currentPage === 'notchMascot') && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                  <MascotFace size={46} mood="happy" accent={accent} />
                  <div>
                    <div style={{ fontSize: 15, fontWeight: 700 }}>Ilha Dinâmica Flutuante no Windows</div>
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                      Monitor principal · Topo central · Sempre visível sobre janelas
                    </div>
                  </div>
                </div>

                {[
                  {
                    label: 'Exibir Ilha Dinâmica no topo da tela',
                    val: settings.islandVisible,
                    set: (v: boolean) => updateSettings({ islandVisible: v }),
                  },
                  {
                    label: 'Expandir automaticamente ao passar o mouse',
                    val: settings.islandOpenOnHover,
                    set: (v: boolean) => updateSettings({ islandOpenOnHover: v }),
                  },
                  {
                    label: 'Manter Ilha fixada aberta',
                    val: settings.islandPinned,
                    set: (v: boolean) => updateSettings({ islandPinned: v }),
                  },
                  {
                    label: 'Ativar Mascote Interativo na Ilha',
                    val: settings.islandMascotEnabled,
                    set: (v: boolean) => updateSettings({ islandMascotEnabled: v }),
                  },
                  {
                    label: 'Vidro translúcido (Liquid Glass)',
                    val: settings.islandLiquidGlass,
                    set: (v: boolean) => updateSettings({ islandLiquidGlass: v }),
                  },
                ].map((row) => (
                  <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: 13 }}>{row.label}</span>
                    <button
                      className={`v-switch ${row.val ? 'is-on' : ''}`}
                      onClick={() => row.set(!row.val)}
                    />
                  </div>
                ))}

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 13 }}>Silhueta da Ilha</span>
                  <div style={{ display: 'flex', gap: 6 }}>
                    {(['pill', 'notch'] as const).map((s) => (
                      <button
                        key={s}
                        className={`v-btn ${settings.islandSilhouette === s ? 'v-btn-primary' : ''}`}
                        onClick={() => updateSettings({ islandSilhouette: s })}
                      >
                        {s === 'pill' ? 'Pílula Flutuante' : 'Entalhe no Topo'}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* SYSTEM MONITOR */}
            {currentPage === 'monitor' && (
              <>
                <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <div>
                      <div style={{ fontSize: 14, fontWeight: 700 }}>
                        {telemetry?.hostName} · {telemetry?.osVersion}
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                        {telemetry?.cpuBrand}
                      </div>
                    </div>
                    <div style={{ fontSize: 22, fontWeight: 800, color: accent }}>
                      {Math.round(telemetry?.cpuPercent ?? 0)}%
                    </div>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: 5, height: 52, alignItems: 'end' }}>
                    {(telemetry?.cpuCores ?? []).map((c, idx) => (
                      <div
                        key={idx}
                        title={`Core ${idx}: ${Math.round(c)}%`}
                        style={{
                          height: `${Math.max(12, Math.min(100, c))}%`,
                          background: c > 80 ? '#f87171' : accent,
                          borderRadius: 4,
                        }}
                      />
                    ))}
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
                    <div style={{ padding: 10, borderRadius: 10, background: 'var(--surface-raised)' }}>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>RAM Usada</div>
                      <div style={{ fontSize: 15, fontWeight: 700 }}>
                        {(telemetry?.memoryUsedGb ?? 0).toFixed(1)} / {(telemetry?.memoryTotalGb ?? 0).toFixed(0)} GB
                      </div>
                    </div>
                    <div style={{ padding: 10, borderRadius: 10, background: 'var(--surface-raised)' }}>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>Download</div>
                      <div style={{ fontSize: 15, fontWeight: 700 }}>
                        {(telemetry?.downloadKbPerSec ?? 0).toFixed(1)} KB/s
                      </div>
                    </div>
                    <div style={{ padding: 10, borderRadius: 10, background: 'var(--surface-raised)' }}>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>Upload</div>
                      <div style={{ fontSize: 15, fontWeight: 700 }}>
                        {(telemetry?.uploadKbPerSec ?? 0).toFixed(1)} KB/s
                      </div>
                    </div>
                    <div style={{ padding: 10, borderRadius: 10, background: 'var(--surface-raised)' }}>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>CPU Temp</div>
                      <div style={{ fontSize: 15, fontWeight: 700 }}>
                        {telemetry?.cpuTempC ? `${telemetry.cpuTempC.toFixed(0)}°C` : 'N/A'}
                      </div>
                    </div>
                  </div>
                </div>
              </>
            )}

            {/* MIXER */}
            {currentPage === 'mixer' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <button
                    className="v-btn"
                    onClick={async () => {
                      const res = await setMasterAudio(undefined, !(telemetry?.masterMuted ?? false));
                      setTelemetry((p) => (p ? { ...p, masterVolume: res.volume, masterMuted: res.muted } : p));
                    }}
                  >
                    {telemetry?.masterMuted ? <VolumeX size={15} color="#f87171" /> : <Volume2 size={15} />}
                  </button>
                  <span style={{ fontWeight: 700, minWidth: 120 }}>Volume Principal</span>
                  <input
                    type="range"
                    min={0}
                    max={100}
                    value={telemetry?.masterVolume ?? 65}
                    onChange={(e) => {
                      const v = Number(e.target.value);
                      setTelemetry((p) => (p ? { ...p, masterVolume: v } : p));
                      void setMasterAudio(v, false);
                    }}
                    style={{ flex: 1, accentColor: accent }}
                  />
                  <span style={{ width: 38, textAlign: 'right' }}>{telemetry?.masterVolume ?? 65}%</span>
                </div>

                {audioSessions.map((s) => (
                  <div key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <button
                      className="v-btn"
                      style={{ padding: 6 }}
                      onClick={() => {
                        const m = !s.muted;
                        setAudioSessions((prev) => prev.map((a) => (a.pid === s.pid ? { ...a, muted: m } : a)));
                        void setAppAudio(s.pid, undefined, m);
                      }}
                    >
                      {s.muted ? <VolumeX size={14} color="#f87171" /> : <Volume2 size={14} />}
                    </button>
                    <span style={{ minWidth: 120, fontSize: 13 }}>{s.name}</span>
                    <input
                      type="range"
                      min={0}
                      max={100}
                      value={s.volume}
                      onChange={(e) => {
                        const v = Number(e.target.value);
                        setAudioSessions((prev) =>
                          prev.map((a) => (a.pid === s.pid ? { ...a, volume: v, muted: false } : a))
                        );
                        void setAppAudio(s.pid, v, false);
                      }}
                      style={{ flex: 1, accentColor: accent }}
                    />
                    <span style={{ width: 38, textAlign: 'right' }}>{s.volume}%</span>
                  </div>
                ))}
              </div>
            )}

            {/* ENERGY & BRIGHTNESS */}
            {(currentPage === 'energy' || currentPage === 'brightness') && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: 14, fontWeight: 700 }}>Manter PC Ligado (SetThreadExecutionState)</div>
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                      Atalho global Ctrl+Alt+K
                    </div>
                  </div>
                  <button
                    className={`v-switch ${telemetry?.keepAwakeActive ? 'is-on' : ''}`}
                    onClick={async () => {
                      const ok = await toggleKeepAwakeState(!telemetry?.keepAwakeActive);
                      setTelemetry((p) => (p ? { ...p, keepAwakeActive: ok } : p));
                    }}
                  />
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <Sun size={16} color="#fbbf24" />
                  <span style={{ fontSize: 13 }}>Brilho do Monitor ({settings.brightnessLevel}%)</span>
                  <input
                    type="range"
                    min={5}
                    max={100}
                    value={settings.brightnessLevel}
                    onChange={(e) => {
                      const v = Number(e.target.value);
                      updateSettings({ brightnessLevel: v });
                      void setDisplayBrightness(v);
                    }}
                    style={{ flex: 1, accentColor: '#fbbf24' }}
                  />
                </div>
              </div>
            )}

            {/* WINDOW LAYOUT & SWITCHER */}
            {(currentPage === 'windowLayout' || currentPage === 'switcher') && (
              <>
                <div className="v-card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 700 }}>Snap Rápido na Última Janela Ativa</div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                    {[
                      ['left', 'Metade Esquerda'],
                      ['right', 'Metade Direita'],
                      ['maximize', 'Maximizar Área Útil'],
                      ['topLeft', 'Superior Esquerda'],
                      ['topRight', 'Superior Direita'],
                      ['center', 'Centralizar 72%'],
                    ].map(([preset, title]) => (
                      <button
                        key={preset}
                        className="v-btn"
                        onClick={() => void snapActiveWindow(preset)}
                      >
                        <Columns size={13} color={accent} /> {title}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="v-card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 7 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 700 }}>Janelas Abertas no Windows ({openWindows.length})</div>
                  {openWindows.map((w) => (
                    <div
                      key={w.hwnd}
                      style={{
                        padding: '8px 10px',
                        borderRadius: 9,
                        background: 'var(--surface-raised)',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        gap: 8,
                      }}
                    >
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontSize: 12.5, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {w.title}
                        </div>
                        <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                          {w.processName} · HWND {w.hwnd}
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button className="v-btn" style={{ padding: '4px 9px', fontSize: 11 }} onClick={() => void focusWindow(w.hwnd)}>
                          Focar
                        </button>
                        <button
                          className="v-btn"
                          style={{ padding: '4px 9px', fontSize: 11 }}
                          onClick={async () => {
                            const pinned = await toggleWindowPin(w.hwnd);
                            toast(pinned ? 'Fixada no topo' : 'Desafixada');
                          }}
                        >
                          <Pin size={12} /> Pin
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* COMMAND BAR, RADIAL & SHORTCUTS */}
            {(currentPage === 'commandBar' || currentPage === 'radialMenu' || currentPage === 'shortcuts') && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ fontSize: 14, fontWeight: 700 }}>Atalhos Globais Nativos (RegisterHotKey Win32)</div>
                {[
                  ['Alt + Space', 'Abrir Command Bar Flutuante (Calculadora, URLs, Janelas & Ações)', () => void openOverlay('command')],
                  ['Ctrl + Shift + V', 'Abrir Painel Rápido de Clipboard', () => void openOverlay('clipboard')],
                  ['Ctrl + Shift + Space', 'Abrir Menu Radial de Ferramentas', () => void openOverlay('radial')],
                  ['Ctrl + Alt + M', 'Abrir / Fechar Painel da Bandeja', () => void toggleTrayPanel()],
                  ['Ctrl + Alt + I', 'Expandir / Recolher Ilha Dinâmica', () => updateSettings({ islandVisible: true })],
                  ['Ctrl + Alt + K', 'Alternar Manter Ligado (Keep Awake)', () => void toggleKeepAwakeState(true)],
                ].map(([key, desc, testFn]) => (
                  <div
                    key={String(key)}
                    style={{
                      padding: '9px 12px',
                      borderRadius: 10,
                      background: 'var(--surface-raised)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <span style={{ fontWeight: 700, fontSize: 12.5, color: accent }}>{String(key)}</span>
                      <div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>{String(desc)}</div>
                    </div>
                    <button className="v-btn" style={{ padding: '5px 10px', fontSize: 11 }} onClick={testFn as () => void}>
                      Testar
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* CLIPBOARD */}
            {currentPage === 'clipboard' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'flex', gap: 8 }}>
                  <input
                    className="v-input"
                    value={clipFilter}
                    onChange={(e) => setClipFilter(e.target.value)}
                    placeholder="Pesquisar no histórico capturado..."
                  />
                  <button className="v-btn" onClick={clearClipboard}>
                    Limpar não fixados
                  </button>
                </div>
                {clipboard
                  .filter((c) => !clipFilter.trim() || c.text.toLowerCase().includes(clipFilter.toLowerCase()))
                  .map((c) => (
                    <div
                      key={c.id}
                      style={{
                        padding: '8px 10px',
                        borderRadius: 9,
                        background: 'var(--surface-raised)',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        gap: 8,
                      }}
                    >
                      <span
                        onClick={() => {
                          void copyToClipboard(c.text);
                          toast('Copiado para área de transferência');
                        }}
                        style={{ flex: 1, fontSize: 12.5, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', cursor: 'pointer' }}
                      >
                        {c.text}
                      </span>
                      <button className="v-btn" style={{ padding: '4px 8px' }} onClick={() => togglePinClipboard(c.id)}>
                        <Pin size={12} color={c.pinned ? '#fbbf24' : undefined} />
                      </button>
                    </div>
                  ))}
              </div>
            )}

            {/* SHELF */}
            {currentPage === 'shelf' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: 14, fontWeight: 700 }}>Prateleira de Arquivos da Ilha ({shelf.length})</div>
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                      Arraste arquivos do Windows Explorer sobre a Ilha Dinâmica no topo da tela
                    </div>
                  </div>
                  {shelf.length > 0 && (
                    <button className="v-btn" onClick={clearShelf}>
                      Limpar tudo
                    </button>
                  )}
                </div>
                {shelf.map((item) => (
                  <div
                    key={item.id}
                    style={{
                      padding: '8px 11px',
                      borderRadius: 9,
                      background: 'var(--surface-raised)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600 }}>{item.name}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {item.path} · {item.sizeLabel}
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="v-btn" style={{ padding: '4px 8px' }} onClick={() => void openPathInExplorer(item.path)}>
                        <FolderOpen size={12} /> Abrir
                      </button>
                      <button className="v-btn" style={{ padding: '4px 8px' }} onClick={() => removeShelfItem(item.id)}>
                        <Trash2 size={12} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* TEXT SNIPPETS */}
            {currentPage === 'textSnippets' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr auto', gap: 8 }}>
                  <input className="v-input" value={newTrigger} onChange={(e) => setNewTrigger(e.target.value)} placeholder=";atalho" />
                  <input className="v-input" value={newExpansion} onChange={(e) => setNewExpansion(e.target.value)} placeholder="Texto completo do snippet..." />
                  <button
                    className="v-btn v-btn-primary"
                    onClick={() => {
                      if (!newExpansion.trim()) return;
                      saveSnippets([
                        { id: `s-${Date.now()}`, trigger: newTrigger || ';tip', expansion: newExpansion, category: 'Geral' },
                        ...snippets,
                      ]);
                      setNewExpansion('');
                      toast('Snippet salvo');
                    }}
                  >
                    <Plus size={14} /> Adicionar
                  </button>
                </div>
                {snippets.map((s) => (
                  <div
                    key={s.id}
                    style={{
                      padding: '8px 11px',
                      borderRadius: 9,
                      background: 'var(--surface-raised)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <span style={{ fontWeight: 700, color: accent }}>{s.trigger}</span>
                      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{s.expansion}</div>
                    </div>
                    <button
                      className="v-btn"
                      onClick={() => {
                        void copyToClipboard(s.expansion);
                        toast('Snippet copiado');
                      }}
                    >
                      <Copy size={12} /> Copiar
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* URL CLEANER */}
            {currentPage === 'urlCleaner' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 13.5, fontWeight: 700 }}>
                    Limpar URLs automaticamente ao copiar (Ctrl+C)
                  </span>
                  <button
                    className={`v-switch ${settings.autoCleanUrls ? 'is-on' : ''}`}
                    onClick={() => updateSettings({ autoCleanUrls: !settings.autoCleanUrls })}
                  />
                </div>
                <input
                  className="v-input"
                  value={urlTestInput}
                  onChange={(e) => setUrlTestInput(e.target.value)}
                />
                {urlCleanPreview.valid && (
                  <div style={{ padding: 11, borderRadius: 10, background: 'var(--surface-raised)', fontSize: 12.5 }}>
                    <div style={{ color: '#34d399', wordBreak: 'break-all' }}>{urlCleanPreview.cleaned}</div>
                    <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>
                      Trackers removidos: {urlCleanPreview.removedCount}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* SCREENSHOT & COLOR PICKER */}
            {currentPage === 'screenshot' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', gap: 10 }}>
                  <button
                    className="v-btn v-btn-primary"
                    onClick={async () => {
                      const res = await captureScreenPng();
                      if (res) toast(`Salva em ${res.path}`);
                    }}
                  >
                    <Scissors size={14} /> Capturar Tela PNG
                  </button>
                  <button
                    className="v-btn"
                    onClick={async () => {
                      const c = await pickScreenColor();
                      setPickedColor(c.hex);
                      await copyToClipboard(c.hex);
                      addClipboardEntry(c.hex);
                      toast(`Cor copiada: ${c.hex}`);
                    }}
                  >
                    <Pipette size={14} color="#f472b6" /> Capturar Cor sob Cursor {pickedColor ? `(${pickedColor})` : ''}
                  </button>
                  <button className="v-btn" onClick={() => void launchWindowsUtility('ms-screenclip:')}>
                    Recorte Nativo Windows
                  </button>
                </div>
                {captures.map((cap) => (
                  <div
                    key={cap.path}
                    style={{
                      padding: '8px 10px',
                      borderRadius: 9,
                      background: 'var(--surface-raised)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600 }}>{cap.fileName}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {cap.width}x{cap.height} · {cap.sizeKb} KB
                      </div>
                    </div>
                    <button className="v-btn" onClick={() => void openPathInExplorer(cap.path)}>
                      <FolderOpen size={12} /> Explorer
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* CLEANER */}
            {currentPage === 'cleaner' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 14, fontWeight: 700 }}>Limpeza de Temporários do Windows</span>
                  <button
                    className="v-btn"
                    onClick={async () => {
                      await emptyRecycleBin();
                      toast('Lixeira esvaziada');
                    }}
                  >
                    <Trash2 size={13} /> Esvaziar Lixeira
                  </button>
                </div>
                {junkCats.map((cat) => (
                  <div
                    key={cat.id}
                    style={{
                      padding: '9px 11px',
                      borderRadius: 9,
                      background: 'var(--surface-raised)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 600 }}>{cat.label}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {cat.path} · {cat.fileCount} arquivos ({cat.sizeMb.toFixed(1)} MB)
                      </div>
                    </div>
                    <button
                      className="v-btn v-btn-primary"
                      onClick={async () => {
                        const rem = await cleanJunkCaches([cat.id]);
                        toast(`${rem} arquivos removidos`);
                        setJunkCats(await scanJunkCaches());
                      }}
                    >
                      Limpar
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* UNINSTALLER */}
            {currentPage === 'uninstaller' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={{ fontSize: 14, fontWeight: 700 }}>
                  Aplicativos Instalados no Registro ({installedApps.length})
                </div>
                {installedApps.slice(0, 40).map((app, i) => (
                  <div
                    key={`${app.name}-${i}`}
                    style={{
                      padding: '8px 11px',
                      borderRadius: 9,
                      background: 'var(--surface-raised)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      gap: 10,
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600 }}>{app.name}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {app.publisher || 'Windows'} · v{app.version}
                      </div>
                    </div>
                    <button className="v-btn" onClick={() => void triggerUninstallApp(app.uninstallString)}>
                      Desinstalar
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* WINGET */}
            {currentPage === 'appUpdates' && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', gap: 8 }}>
                  <input
                    className="v-input"
                    value={wingetQuery}
                    onChange={(e) => setWingetQuery(e.target.value)}
                    placeholder="Buscar pacote no Winget (ex: vscode, 7zip, ffmpeg)..."
                  />
                  <button
                    className="v-btn v-btn-primary"
                    onClick={async () => {
                      if (!wingetQuery.trim()) return;
                      setWingetResults(await wingetSearch(wingetQuery));
                    }}
                  >
                    Buscar Winget
                  </button>
                </div>

                {wingetResults.length > 0 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                    <div style={{ fontSize: 12.5, fontWeight: 700 }}>Resultados da Busca</div>
                    {wingetResults.slice(0, 12).map((pkg) => (
                      <div
                        key={pkg.id}
                        style={{
                          padding: '8px 10px',
                          borderRadius: 9,
                          background: 'var(--surface-raised)',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <div>
                          <div style={{ fontSize: 12.5, fontWeight: 600 }}>{pkg.name}</div>
                          <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            {pkg.id} · v{pkg.version}
                          </div>
                        </div>
                        <button
                          className="v-btn v-btn-primary"
                          onClick={async () => {
                            toast(`Instalando ${pkg.name}...`);
                            await wingetInstall(pkg.id, false);
                            toast(`${pkg.name} instalado`);
                          }}
                        >
                          Instalar
                        </button>
                      </div>
                    ))}
                  </div>
                )}

                <div style={{ fontSize: 12.5, fontWeight: 700 }}>
                  Atualizações Disponíveis ({wingetUpdates.length})
                </div>
                {wingetUpdates.map((u) => (
                  <div
                    key={u.id}
                    style={{
                      padding: '8px 10px',
                      borderRadius: 9,
                      background: 'var(--surface-raised)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600 }}>{u.name}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {u.version} → {u.availableVersion}
                      </div>
                    </div>
                    <button
                      className="v-btn v-btn-primary"
                      onClick={async () => {
                        toast(`Atualizando ${u.name}...`);
                        await wingetInstall(u.id, true);
                        toast(`${u.name} atualizado`);
                      }}
                    >
                      Atualizar
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* PORT MANAGER & KILL PROCESS */}
            {(currentPage === 'portManager' || currentPage === 'killProcess') && (
              <div className="v-card" style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={{ fontSize: 14, fontWeight: 700 }}>
                  {currentPage === 'portManager'
                    ? `Portas em Escuta (${ports.length})`
                    : 'Top Processos por Uso de CPU'}
                </div>
                {currentPage === 'portManager'
                  ? ports.map((p, i) => (
                      <div
                        key={`${p.port}-${p.pid}-${i}`}
                        style={{
                          padding: '8px 10px',
                          borderRadius: 9,
                          background: 'var(--surface-raised)',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <div>
                          <div style={{ fontSize: 12.5, fontWeight: 700 }}>
                            :{p.port} · {p.processName}
                          </div>
                          <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            {p.protocol} {p.localAddress} · PID {p.pid}
                          </div>
                        </div>
                        <button
                          className="v-btn"
                          style={{ color: '#f87171' }}
                          onClick={async () => {
                            await killProcessByPid(p.pid);
                            toast(`PID ${p.pid} encerrado`);
                            setPorts(await listListeningPorts());
                          }}
                        >
                          Encerrar PID
                        </button>
                      </div>
                    ))
                  : (telemetry?.topProcesses ?? []).map((proc) => (
                      <div
                        key={proc.pid}
                        style={{
                          padding: '8px 10px',
                          borderRadius: 9,
                          background: 'var(--surface-raised)',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <div>
                          <div style={{ fontSize: 12.5, fontWeight: 700 }}>
                            {proc.name} (PID {proc.pid})
                          </div>
                          <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            CPU {proc.cpuPercent.toFixed(1)}% · Memória {proc.memoryMb} MB
                          </div>
                        </div>
                        <button
                          className="v-btn"
                          style={{ color: '#f87171' }}
                          onClick={async () => {
                            await killProcessByPid(proc.pid);
                            toast(`${proc.name} encerrado`);
                            void loadPageData('killProcess');
                          }}
                        >
                          Finalizar
                        </button>
                      </div>
                    ))}
              </div>
            )}

            {/* ABOUT & RELEASE NOTES */}
            {(currentPage === 'about' || currentPage === 'releaseNotes') && (
              <div className="v-card" style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                  <BrandMark size={52} badge />
                  <div>
                    <div style={{ fontSize: 18, fontWeight: 800 }}>Vorssaint Utils · Windows Edition</div>
                    <div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>
                      Versão {APP_VERSION} · Arquitetura nativa multi-janela (Tauri v2 + Win32)
                    </div>
                  </div>
                </div>
                <div style={{ fontSize: 13, lineHeight: 1.6, color: 'var(--text-secondary)' }}>
                  • Ilha Dinâmica flutuante independente no topo do monitor principal com redimensionamento dinâmico, arrasto nativo de arquivos do Explorer e 11 módulos interativos.
                  <br />
                  • Painel da Bandeja do Sistema ancorado acima da barra de tarefas do Windows.
                  <br />
                  • Overlays globais nativos: Alt+Space (Command Bar), Ctrl+Shift+V (Clipboard), Ctrl+Shift+Space (Menu Radial) e Modo Limpeza.
                  <br />
                  • CoreAudio Mixer por app, SetThreadExecutionState Keep Awake, Brilho WMI, Snap/Pin HWND, Port Manager (netstat), Limpador de Temporários e Winget.
                </div>
                <div>
                  <button
                    className="v-btn"
                    onClick={() =>
                      void openExternalUrl('https://github.com/alebypegasus/vorssaint-utils-intel')
                    }
                  >
                    <ExternalLink size={13} /> Repositório GitHub Vorssaint
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
};

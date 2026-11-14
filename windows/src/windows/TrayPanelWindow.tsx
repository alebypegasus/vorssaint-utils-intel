import React, { useCallback, useEffect, useState } from 'react';
import {
  Activity,
  AppWindow,
  ArrowDown,
  ArrowUp,
  BatteryCharging,
  ChevronLeft,
  ChevronRight,
  Columns,
  Command,
  Cpu,
  Download,
  ExternalLink,
  Fan,
  FolderOpen,
  HardDrive,
  Link2,
  Lock,
  Maximize2,
  Moon,
  Network,
  Package,
  Palette,
  Pause,
  Pin,
  Pipette,
  Play,
  Power,
  RefreshCw,
  Scissors,
  Settings,
  ShieldAlert,
  SkipBack,
  SkipForward,
  Sliders,
  Sparkles,
  Sun,
  Terminal,
  Trash2,
  Volume2,
  VolumeX,
  Wifi,
  Wrench,
  XCircle,
  Zap,
} from 'lucide-react';
import { BrandMark } from '../components/BrandMark';
import { APP_VERSION, UI_LABELS } from '../data/catalog';
import {
  captureScreenPng,
  cleanJunkCaches,
  copyToClipboard,
  emptyRecycleBin,
  fetchSystemTelemetry,
  hideTrayPanel,
  killProcessByPid,
  launchWindowsUtility,
  listAudioSessions,
  listInstalledApps,
  listListeningPorts,
  lockWorkstation,
  openOverlay,
  openPathInExplorer,
  openSettingsWindow,
  pickScreenColor,
  quitApp,
  safeListen,
  scanJunkCaches,
  sendMediaAction,
  setAppAudio,
  setDisplayBrightness,
  setMasterAudio,
  setWindowsDarkMode,
  snapActiveWindow,
  toggleWindowPin,
  triggerUninstallApp,
  wingetInstall,
  wingetListUpdates,
} from '../lib/bridge';
import { useVorssaintStore } from '../lib/store';
import { cleanUrl } from '../lib/urlCleaner';
import type {
  AppAudioSession,
  InstalledAppEntry,
  JunkCategory,
  ListeningPortEntry,
  SystemTelemetry,
  TrayPanelSectionId,
  WingetPackage,
} from '../types/vorssaint';

type InlineToolId =
  | null
  | 'cleaner'
  | 'ports'
  | 'uninstaller'
  | 'winget'
  | 'urlCleaner'
  | 'windowSnap';

const SECTION_META: {
  id: TrayPanelSectionId;
  label: string;
  icon: React.ReactNode;
}[] = [
  { id: 'keepAwake', label: 'Energia', icon: <Zap size={14} /> },
  { id: 'mixer', label: 'Mixer', icon: <Volume2 size={14} /> },
  { id: 'brightness', label: 'Tela', icon: <Sun size={14} /> },
  { id: 'system', label: 'Sistema', icon: <Cpu size={14} /> },
  { id: 'network', label: 'Rede', icon: <Wifi size={14} /> },
  { id: 'disk', label: 'Discos', icon: <HardDrive size={14} /> },
  { id: 'power', label: 'Bateria', icon: <BatteryCharging size={14} /> },
  { id: 'fan', label: 'Térmico', icon: <Fan size={14} /> },
  { id: 'utilities', label: 'Tools', icon: <Wrench size={14} /> },
  { id: 'toggles', label: 'Toggles', icon: <Sliders size={14} /> },
];

export const TrayPanelWindow: React.FC = () => {
  const { settings, updateSettings, addClipboardEntry, toggleKeepAwakeState } =
    useVorssaintStore();
  const labels = UI_LABELS[settings.language] ?? UI_LABELS.pt;
  const accent = settings.accentHex || '#38bdf8';

  const visibleTabs = SECTION_META.filter(
    (t) => settings.panelVisibleSections[t.id] !== false
  );
  const [activeTab, setActiveTab] = useState<TrayPanelSectionId>(
    visibleTabs[0]?.id ?? 'keepAwake'
  );
  const [inlineTool, setInlineTool] = useState<InlineToolId>(null);
  const [telemetry, setTelemetry] = useState<SystemTelemetry | null>(null);
  const [audioSessions, setAudioSessions] = useState<AppAudioSession[]>([]);
  const [awakeDuration, setAwakeDuration] = useState<string>('Indefinido');
  const [feedback, setFeedback] = useState<string | null>(null);

  // Inline tool states
  const [junkList, setJunkList] = useState<JunkCategory[]>([]);
  const [ports, setPorts] = useState<ListeningPortEntry[]>([]);
  const [apps, setApps] = useState<InstalledAppEntry[]>([]);
  const [updates, setUpdates] = useState<WingetPackage[]>([]);
  const [toolBusy, setToolBusy] = useState(false);
  const [urlInput, setUrlInput] = useState('');

  const notify = useCallback((msg: string) => {
    setFeedback(msg);
    window.setTimeout(() => {
      setFeedback((curr) => (curr === msg ? null : curr));
    }, 2400);
  }, []);

  const refreshAll = useCallback(async () => {
    try {
      const [tel, sessions] = await Promise.all([
        fetchSystemTelemetry(),
        listAudioSessions(),
      ]);
      setTelemetry(tel);
      setAudioSessions(sessions);
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    void refreshAll();
    const timer = window.setInterval(() => {
      void fetchSystemTelemetry().then(setTelemetry).catch(() => {});
    }, 2500);
    const unsubPromise = safeListen('panel-opened', () => {
      void refreshAll();
    });
    return () => {
      window.clearInterval(timer);
      void unsubPromise.then((u) => u());
    };
  }, [refreshAll]);

  const openTool = async (tool: InlineToolId) => {
    setInlineTool(tool);
    setToolBusy(true);
    try {
      if (tool === 'cleaner') setJunkList(await scanJunkCaches());
      if (tool === 'ports') setPorts(await listListeningPorts());
      if (tool === 'uninstaller') setApps(await listInstalledApps());
      if (tool === 'winget') setUpdates(await wingetListUpdates());
    } finally {
      setToolBusy(false);
    }
  };

  return (
    <div
      style={{
        width: '100vw',
        height: '100vh',
        padding: 8,
        background: 'transparent',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div
        className="v-shell"
        style={{
          flex: 1,
          borderRadius: 18,
          background:
            settings.appearance === 'light'
              ? 'rgba(248, 250, 252, 0.96)'
              : 'rgba(13, 15, 22, 0.96)',
          border: '1px solid var(--border-strong)',
          boxShadow: '0 22px 48px rgba(0, 0, 0, 0.55)',
          backdropFilter: 'blur(26px)',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}
      >
        {/* TOP HEADER */}
        <div
          style={{
            padding: '11px 14px',
            borderBottom: '1px solid var(--border-subtle)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
            <BrandMark size={28} badge />
            <div>
              <div style={{ fontSize: 13, fontWeight: 700, lineHeight: 1.15 }}>
                Vorssaint Utils
              </div>
              <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                Windows {APP_VERSION} · CPU {Math.round(telemetry?.cpuPercent ?? 0)}%
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            <button
              title="Command Bar (Alt+Space)"
              onClick={() => {
                void hideTrayPanel();
                void openOverlay('command');
              }}
              className="v-btn"
              style={{ padding: '5px 8px', fontSize: 11 }}
            >
              <Command size={13} />
            </button>
            <button
              title="Menu Radial (Ctrl+Shift+Space)"
              onClick={() => {
                void hideTrayPanel();
                void openOverlay('radial');
              }}
              className="v-btn"
              style={{ padding: '5px 8px', fontSize: 11 }}
            >
              <Palette size={13} />
            </button>
            <button
              title={labels.settingsBtn}
              onClick={() => {
                void hideTrayPanel();
                void openSettingsWindow('panelConfig');
              }}
              className="v-btn"
              style={{ padding: '5px 8px', fontSize: 11 }}
            >
              <Settings size={13} />
            </button>
          </div>
        </div>

        {/* SECTION ICON TABS */}
        <div
          style={{
            padding: '8px 10px',
            borderBottom: '1px solid var(--border-subtle)',
            display: 'flex',
            gap: 4,
            overflowX: 'auto',
            scrollbarWidth: 'none',
            flexShrink: 0,
          }}
        >
          {visibleTabs.map((tab) => {
            const active = !inlineTool && activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => {
                  setInlineTool(null);
                  setActiveTab(tab.id);
                }}
                style={{
                  padding: '6px 9px',
                  borderRadius: 9,
                  border: active ? `1px solid ${accent}55` : '1px solid transparent',
                  background: active ? `${accent}20` : 'transparent',
                  color: active ? 'var(--text-primary)' : 'var(--text-secondary)',
                  fontSize: 11,
                  fontWeight: 600,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 5,
                  cursor: 'pointer',
                  whiteSpace: 'nowrap',
                }}
              >
                <span style={{ color: active ? accent : 'inherit', display: 'flex' }}>
                  {tab.icon}
                </span>
                {tab.label}
              </button>
            );
          })}
        </div>

        {/* FEEDBACK PILL */}
        {feedback && (
          <div
            style={{
              margin: '8px 12px 0',
              padding: '6px 10px',
              borderRadius: 9,
              background: `${accent}22`,
              border: `1px solid ${accent}44`,
              fontSize: 11.5,
              fontWeight: 600,
              textAlign: 'center',
            }}
          >
            {feedback}
          </div>
        )}

        {/* CONTENT SCROLL AREA */}
        <div style={{ flex: 1, padding: 12, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {/* INLINE TOOL SUB-VIEWS */}
          {inlineTool && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <button
                  className="v-btn"
                  style={{ padding: '4px 9px', fontSize: 11.5 }}
                  onClick={() => setInlineTool(null)}
                >
                  <ChevronLeft size={13} /> Voltar
                </button>
                <span style={{ fontSize: 12, fontWeight: 700, textTransform: 'capitalize' }}>
                  {inlineTool}
                </span>
              </div>

              {toolBusy && (
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                  Carregando dados reais do Windows...
                </div>
              )}

              {inlineTool === 'cleaner' && !toolBusy && (
                <>
                  {junkList.map((cat) => (
                    <div key={cat.id} className="v-card" style={{ padding: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontSize: 12, fontWeight: 600 }}>{cat.label}</div>
                        <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                          {cat.fileCount} arquivos · {cat.sizeMb.toFixed(1)} MB
                        </div>
                      </div>
                      <button
                        className="v-btn v-btn-primary"
                        style={{ padding: '5px 9px', fontSize: 11 }}
                        onClick={async () => {
                          const removed = await cleanJunkCaches([cat.id]);
                          notify(`${removed} itens limpos`);
                          setJunkList(await scanJunkCaches());
                        }}
                      >
                        Limpar
                      </button>
                    </div>
                  ))}
                </>
              )}

              {inlineTool === 'ports' && !toolBusy && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {ports.slice(0, 24).map((p, idx) => (
                    <div key={`${p.port}-${p.pid}-${idx}`} className="v-card" style={{ padding: '7px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <div>
                        <div style={{ fontSize: 12, fontWeight: 700 }}>
                          :{p.port} · {p.processName}
                        </div>
                        <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                          {p.protocol} {p.localAddress} · PID {p.pid}
                        </div>
                      </div>
                      <button
                        className="v-btn"
                        style={{ padding: '4px 8px', fontSize: 11, color: '#f87171' }}
                        onClick={async () => {
                          await killProcessByPid(p.pid);
                          notify(`PID ${p.pid} encerrado`);
                          setPorts(await listListeningPorts());
                        }}
                      >
                        Kill
                      </button>
                    </div>
                  ))}
                </div>
              )}

              {inlineTool === 'uninstaller' && !toolBusy && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {apps.slice(0, 20).map((app, i) => (
                    <div key={`${app.name}-${i}`} className="v-card" style={{ padding: '7px 10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontSize: 12, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {app.name}
                        </div>
                        <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                          {app.publisher || 'Windows'} · {app.version}
                        </div>
                      </div>
                      <button
                        className="v-btn"
                        style={{ padding: '4px 8px', fontSize: 11 }}
                        onClick={() => void triggerUninstallApp(app.uninstallString)}
                      >
                        Desinstalar
                      </button>
                    </div>
                  ))}
                </div>
              )}

              {inlineTool === 'winget' && !toolBusy && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {updates.length === 0 ? (
                    <div className="v-card" style={{ padding: 12, fontSize: 12 }}>
                      Todos os aplicativos verificados via winget estão em dia.
                    </div>
                  ) : (
                    updates.map((pkg) => (
                      <div key={pkg.id} className="v-card" style={{ padding: '8px 10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontSize: 12, fontWeight: 600 }}>{pkg.name}</div>
                          <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                            {pkg.version} → {pkg.availableVersion}
                          </div>
                        </div>
                        <button
                          className="v-btn v-btn-primary"
                          style={{ padding: '4px 9px', fontSize: 11 }}
                          onClick={async () => {
                            notify(`Atualizando ${pkg.name}...`);
                            await wingetInstall(pkg.id, true);
                            notify(`${pkg.name} atualizado`);
                          }}
                        >
                          Atualizar
                        </button>
                      </div>
                    ))
                  )}
                </div>
              )}

              {inlineTool === 'urlCleaner' && (
                <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                  <input
                    className="v-input"
                    value={urlInput}
                    onChange={(e) => setUrlInput(e.target.value)}
                    placeholder="Cole uma URL com utm_source, fbclid..."
                  />
                  {(() => {
                    const res = cleanUrl(urlInput);
                    return res.valid ? (
                      <>
                        <div style={{ fontSize: 11, color: '#34d399', wordBreak: 'break-all' }}>
                          {res.cleaned}
                        </div>
                        <button
                          className="v-btn v-btn-primary"
                          onClick={() => {
                            void copyToClipboard(res.cleaned);
                            notify(`Copiada (-${res.removedCount} trackers)`);
                          }}
                        >
                          Copiar URL Limpa
                        </button>
                      </>
                    ) : (
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        Informe uma URL válida começando com https://
                      </div>
                    );
                  })()}
                </div>
              )}

              {inlineTool === 'windowSnap' && (
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  {[
                    { id: 'left', label: 'Metade Esquerda' },
                    { id: 'right', label: 'Metade Direita' },
                    { id: 'topLeft', label: 'Quadrante Sup. Esq' },
                    { id: 'topRight', label: 'Quadrante Sup. Dir' },
                    { id: 'maximize', label: 'Maximizar Área Útil' },
                    { id: 'center', label: 'Centralizar (72%)' },
                  ].map((preset) => (
                    <button
                      key={preset.id}
                      className="v-btn"
                      style={{ justifyContent: 'flex-start' }}
                      onClick={() => {
                        void hideTrayPanel();
                        void snapActiveWindow(preset.id);
                      }}
                    >
                      <Columns size={13} color={accent} />
                      {preset.label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* TAB 1: KEEP AWAKE */}
          {!inlineTool && activeTab === 'keepAwake' && (
            <>
              <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div
                      style={{
                        width: 34,
                        height: 34,
                        borderRadius: 10,
                        background: telemetry?.keepAwakeActive
                          ? 'rgba(251,191,36,0.2)'
                          : 'var(--surface-raised)',
                        display: 'grid',
                        placeItems: 'center',
                      }}
                    >
                      <Zap size={17} color={telemetry?.keepAwakeActive ? '#fbbf24' : 'var(--text-muted)'} />
                    </div>
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 700 }}>Manter PC Ligado</div>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {telemetry?.keepAwakeActive ? `Ativo (${awakeDuration})` : 'Suspensão normal do Windows'}
                      </div>
                    </div>
                  </div>
                  <button
                    className={`v-switch ${telemetry?.keepAwakeActive ? 'is-on' : ''}`}
                    onClick={async () => {
                      const next = !telemetry?.keepAwakeActive;
                      const ok = await toggleKeepAwakeState(next);
                      setTelemetry((p) => (p ? { ...p, keepAwakeActive: ok } : p));
                      notify(ok ? 'Keep Awake ativado' : 'Keep Awake desativado');
                    }}
                  />
                </div>

                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 12 }}>
                  <span>Impedir também desligamento da tela</span>
                  <button
                    className={`v-switch ${settings.keepDisplayOn ? 'is-on' : ''}`}
                    onClick={() => updateSettings({ keepDisplayOn: !settings.keepDisplayOn })}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
                  {['30m', '1h', '3h', 'Indefinido'].map((d) => (
                    <button
                      key={d}
                      className={`v-btn ${awakeDuration === d ? 'v-btn-primary' : ''}`}
                      style={{ justifyContent: 'center', padding: '5px 6px', fontSize: 11 }}
                      onClick={async () => {
                        setAwakeDuration(d);
                        const ok = await toggleKeepAwakeState(true);
                        setTelemetry((p) => (p ? { ...p, keepAwakeActive: ok } : p));
                        notify(`Mantendo ligado (${d})`);
                      }}
                    >
                      {d}
                    </button>
                  ))}
                </div>
              </div>

              {/* NOW PLAYING MEDIA MINI CARD */}
              <div className="v-card" style={{ padding: 11, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 11, fontWeight: 600, color: accent }}>Mídia do Windows</div>
                  <div style={{ fontSize: 12, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {telemetry?.mediaSession?.title || 'Controle universal de mídia'}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 4 }}>
                  <button className="v-btn" style={{ padding: 6 }} onClick={() => void sendMediaAction('prev')}>
                    <SkipBack size={13} />
                  </button>
                  <button className="v-btn v-btn-primary" style={{ padding: 6 }} onClick={() => void sendMediaAction('playPause')}>
                    {telemetry?.mediaSession?.isPlaying ? <Pause size={13} /> : <Play size={13} />}
                  </button>
                  <button className="v-btn" style={{ padding: 6 }} onClick={() => void sendMediaAction('next')}>
                    <SkipForward size={13} />
                  </button>
                </div>
              </div>
            </>
          )}

          {/* TAB 2: AUDIO MIXER */}
          {!inlineTool && activeTab === 'mixer' && (
            <>
              <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 12.5, fontWeight: 700 }}>Volume Principal</span>
                  <span style={{ fontSize: 12, fontWeight: 700 }}>
                    {telemetry?.masterMuted ? 'Mudo' : `${telemetry?.masterVolume ?? 65}%`}
                  </span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <button
                    className="v-btn"
                    style={{ padding: 6 }}
                    onClick={async () => {
                      const res = await setMasterAudio(undefined, !(telemetry?.masterMuted ?? false));
                      setTelemetry((p) => (p ? { ...p, masterVolume: res.volume, masterMuted: res.muted } : p));
                    }}
                  >
                    {telemetry?.masterMuted ? <VolumeX size={14} color="#f87171" /> : <Volume2 size={14} />}
                  </button>
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
                </div>
              </div>

              <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 9 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 12.5, fontWeight: 700 }}>Volume por App</span>
                  <button className="v-btn" style={{ padding: '4px 8px', fontSize: 11 }} onClick={() => void refreshAll()}>
                    <RefreshCw size={11} />
                  </button>
                </div>
                {audioSessions.length === 0 ? (
                  <div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>
                    Nenhuma sessão CoreAudio ativa no momento.
                  </div>
                ) : (
                  audioSessions.map((s) => (
                    <div key={s.id} style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11.5 }}>
                        <span style={{ fontWeight: 600 }}>{s.name}</span>
                        <span style={{ color: 'var(--text-muted)' }}>{s.muted ? 'Mudo' : `${s.volume}%`}</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <button
                          className="v-btn"
                          style={{ padding: 5 }}
                          onClick={() => {
                            const nextMuted = !s.muted;
                            setAudioSessions((prev) =>
                              prev.map((a) => (a.pid === s.pid ? { ...a, muted: nextMuted } : a))
                            );
                            void setAppAudio(s.pid, undefined, nextMuted);
                          }}
                        >
                          {s.muted ? <VolumeX size={12} color="#f87171" /> : <Volume2 size={12} />}
                        </button>
                        <input
                          type="range"
                          min={0}
                          max={100}
                          value={s.volume}
                          onChange={(e) => {
                            const vol = Number(e.target.value);
                            setAudioSessions((prev) =>
                              prev.map((a) => (a.pid === s.pid ? { ...a, volume: vol, muted: false } : a))
                            );
                            void setAppAudio(s.pid, vol, false);
                          }}
                          style={{ flex: 1, accentColor: accent }}
                        />
                      </div>
                    </div>
                  ))
                )}
              </div>
            </>
          )}

          {/* TAB 3: BRIGHTNESS */}
          {!inlineTool && activeTab === 'brightness' && (
            <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12.5, fontWeight: 700 }}>
                <span>Brilho do Monitor</span>
                <span>{settings.brightnessLevel}%</span>
              </div>
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
                style={{ width: '100%', accentColor: '#fbbf24' }}
              />
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
                {[25, 50, 75, 100].map((lvl) => (
                  <button
                    key={lvl}
                    className="v-btn"
                    style={{ justifyContent: 'center', fontSize: 11.5 }}
                    onClick={() => {
                      updateSettings({ brightnessLevel: lvl });
                      void setDisplayBrightness(lvl);
                    }}
                  >
                    {lvl}%
                  </button>
                ))}
              </div>
              <button
                className="v-btn"
                onClick={() => void launchWindowsUtility('ms-settings:nightlight')}
              >
                <Moon size={13} color="#fbbf24" />
                Abrir Luz Noturna do Windows
              </button>
            </div>
          )}

          {/* TAB 4: SYSTEM TELEMETRY */}
          {!inlineTool && activeTab === 'system' && (
            <>
              <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, fontWeight: 700 }}>
                  <span>{telemetry?.cpuBrand || 'Processador'}</span>
                  <span>{Math.round(telemetry?.cpuPercent ?? 0)}%</span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 4, height: 32, alignItems: 'end' }}>
                  {(telemetry?.cpuCores ?? []).slice(0, 16).map((c, idx) => (
                    <div
                      key={idx}
                      style={{
                        height: `${Math.max(14, Math.min(100, c))}%`,
                        background: c > 80 ? '#f87171' : accent,
                        borderRadius: 3,
                      }}
                    />
                  ))}
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, fontSize: 11.5 }}>
                  <div>
                    <div style={{ color: 'var(--text-muted)' }}>Memória</div>
                    <div style={{ fontWeight: 700 }}>
                      {(telemetry?.memoryUsedGb ?? 0).toFixed(1)}/{(telemetry?.memoryTotalGb ?? 0).toFixed(0)} GB
                    </div>
                  </div>
                  <div>
                    <div style={{ color: 'var(--text-muted)' }}>Pressão</div>
                    <div style={{ fontWeight: 700 }}>{telemetry?.memoryPressure ?? 'Normal'}</div>
                  </div>
                  <div>
                    <div style={{ color: 'var(--text-muted)' }}>GPU</div>
                    <div style={{ fontWeight: 700 }}>{Math.round(telemetry?.gpuPercent ?? 0)}%</div>
                  </div>
                </div>
              </div>

              <div className="v-card" style={{ padding: 11, display: 'flex', flexDirection: 'column', gap: 7 }}>
                <div style={{ fontSize: 12, fontWeight: 700 }}>Processos com maior uso</div>
                {(telemetry?.topProcesses ?? []).slice(0, 6).map((proc) => (
                  <div
                    key={proc.pid}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      fontSize: 11.5,
                      gap: 6,
                    }}
                  >
                    <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>
                      {proc.name}
                    </span>
                    <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>
                      {proc.cpuPercent.toFixed(1)}% · {proc.memoryMb} MB
                    </span>
                    <button
                      title="Encerrar processo"
                      onClick={async () => {
                        await killProcessByPid(proc.pid);
                        notify(`Encerrado: ${proc.name}`);
                        void refreshAll();
                      }}
                      style={{ border: 'none', background: 'transparent', color: '#f87171', cursor: 'pointer' }}
                    >
                      <XCircle size={13} />
                    </button>
                  </div>
                ))}
              </div>
            </>
          )}

          {/* TAB 5: NETWORK */}
          {!inlineTool && activeTab === 'network' && (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                <div className="v-card" style={{ padding: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: 'var(--text-muted)' }}>
                    <ArrowDown size={13} color="#34d399" /> Download
                  </div>
                  <div style={{ fontSize: 18, fontWeight: 700, marginTop: 4 }}>
                    {(telemetry?.downloadKbPerSec ?? 0).toFixed(1)} KB/s
                  </div>
                </div>
                <div className="v-card" style={{ padding: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: 'var(--text-muted)' }}>
                    <ArrowUp size={13} color="#38bdf8" /> Upload
                  </div>
                  <div style={{ fontSize: 18, fontWeight: 700, marginTop: 4 }}>
                    {(telemetry?.uploadKbPerSec ?? 0).toFixed(1)} KB/s
                  </div>
                </div>
              </div>

              {(telemetry?.networks ?? []).map((n) => (
                <div key={n.name} className="v-card" style={{ padding: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: 12, fontWeight: 600 }}>{n.name}</div>
                    <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                      Total ↓ {n.totalRxMb.toFixed(0)} MB · ↑ {n.totalTxMb.toFixed(0)} MB
                    </div>
                  </div>
                  <Network size={15} color={accent} />
                </div>
              ))}
            </>
          )}

          {/* TAB 6: DISKS */}
          {!inlineTool && activeTab === 'disk' && (
            <>
              {(telemetry?.disks ?? []).map((d) => (
                <div key={d.mount} className="v-card" style={{ padding: 11, display: 'flex', flexDirection: 'column', gap: 7 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 700 }}>
                        {d.mount} {d.name ? `(${d.name})` : ''}
                      </div>
                      <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                        {d.availableGb.toFixed(1)} GB livres de {d.totalGb.toFixed(0)} GB ({d.fileSystem})
                      </div>
                    </div>
                    <button
                      className="v-btn"
                      style={{ padding: '4px 8px', fontSize: 11 }}
                      onClick={() => void openPathInExplorer(d.mount)}
                    >
                      <FolderOpen size={12} /> Abrir
                    </button>
                  </div>
                  <div style={{ height: 6, borderRadius: 999, background: 'var(--surface-raised)', overflow: 'hidden' }}>
                    <div
                      style={{
                        width: `${Math.min(100, d.usedPercent)}%`,
                        height: '100%',
                        background: d.usedPercent > 88 ? '#f87171' : accent,
                      }}
                    />
                  </div>
                </div>
              ))}
              <button
                className="v-btn"
                onClick={async () => {
                  await emptyRecycleBin();
                  notify('Lixeira do Windows esvaziada');
                }}
              >
                <Trash2 size={14} color="#f87171" /> Esvaziar Lixeira do Windows
              </button>
            </>
          )}

          {/* TAB 7: POWER / BATTERY */}
          {!inlineTool && activeTab === 'power' && (
            <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700 }}>
                    {telemetry?.batteryPercent !== null && telemetry?.batteryPercent !== undefined
                      ? `Bateria: ${telemetry.batteryPercent}%`
                      : 'Energia AC (Desktop)'}
                  </div>
                  <div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>
                    {telemetry?.batteryCharging ? 'Carregando na tomada' : 'Operação padrão'} · Uptime{' '}
                    {Math.floor((telemetry?.uptimeSeconds ?? 0) / 3600)}h
                  </div>
                </div>
                <Power size={20} color="#34d399" />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                <button className="v-btn" onClick={() => void lockWorkstation()}>
                  <Lock size={13} color="#f87171" /> Bloquear PC
                </button>
                <button
                  className="v-btn"
                  onClick={() => void launchWindowsUtility('ms-settings:powersleep')}
                >
                  <ExternalLink size={13} /> Energia do Windows
                </button>
              </div>
            </div>
          )}

          {/* TAB 8: THERMALS / FAN */}
          {!inlineTool && activeTab === 'fan' && (
            <div className="v-card" style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ fontSize: 12.5, fontWeight: 700 }}>Sensores Térmicos & Carga</div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                <div style={{ padding: 10, borderRadius: 10, background: 'var(--surface-raised)' }}>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>CPU Temp</div>
                  <div style={{ fontSize: 18, fontWeight: 700 }}>
                    {telemetry?.cpuTempC ? `${telemetry.cpuTempC.toFixed(0)}°C` : 'Indisponível'}
                  </div>
                </div>
                <div style={{ padding: 10, borderRadius: 10, background: 'var(--surface-raised)' }}>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>GPU Temp</div>
                  <div style={{ fontSize: 18, fontWeight: 700 }}>
                    {telemetry?.gpuTempC ? `${telemetry.gpuTempC.toFixed(0)}°C` : 'Indisponível'}
                  </div>
                </div>
              </div>
              <div style={{ fontSize: 11.5, color: 'var(--text-muted)' }}>
                Uso atual de CPU: {Math.round(telemetry?.cpuPercent ?? 0)}% · GPU:{' '}
                {Math.round(telemetry?.gpuPercent ?? 0)}%
              </div>
            </div>
          )}

          {/* TAB 9: UTILITIES GRID */}
          {!inlineTool && activeTab === 'utilities' && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              {[
                {
                  label: 'Captura PNG',
                  icon: <Scissors size={14} color="#34d399" />,
                  onClick: async () => {
                    const shot = await captureScreenPng();
                    if (shot) notify(`Captura salva: ${shot.fileName}`);
                  },
                },
                {
                  label: 'Conta-gotas Win32',
                  icon: <Pipette size={14} color="#f472b6" />,
                  onClick: async () => {
                    const c = await pickScreenColor();
                    await copyToClipboard(c.hex);
                    addClipboardEntry(c.hex);
                    notify(`Cor copiada: ${c.hex}`);
                  },
                },
                {
                  label: 'Organizar Janelas',
                  icon: <Maximize2 size={14} color="#38bdf8" />,
                  onClick: () => void openTool('windowSnap'),
                },
                {
                  label: 'Limpar Cache / Temp',
                  icon: <Sparkles size={14} color="#fbbf24" />,
                  onClick: () => void openTool('cleaner'),
                },
                {
                  label: 'Gerenciador de Portas',
                  icon: <Network size={14} color="#a78bfa" />,
                  onClick: () => void openTool('ports'),
                },
                {
                  label: 'Desinstalador Apps',
                  icon: <AppWindow size={14} color="#fb7185" />,
                  onClick: () => void openTool('uninstaller'),
                },
                {
                  label: 'Atualizações Winget',
                  icon: <Download size={14} color="#2dd4bf" />,
                  onClick: () => void openTool('winget'),
                },
                {
                  label: 'Limpador de URL',
                  icon: <Link2 size={14} color="#60a5fa" />,
                  onClick: () => void openTool('urlCleaner'),
                },
                {
                  label: 'Clipboard Panel',
                  icon: <Package size={14} color="#facc15" />,
                  onClick: () => {
                    void hideTrayPanel();
                    void openOverlay('clipboard');
                  },
                },
                {
                  label: 'Modo Limpeza',
                  icon: <ShieldAlert size={14} color="#f87171" />,
                  onClick: () => {
                    void hideTrayPanel();
                    void openOverlay('cleaning');
                  },
                },
              ].map((tool) => (
                <button
                  key={tool.label}
                  className="v-btn"
                  style={{ justifyContent: 'space-between', padding: '9px 10px' }}
                  onClick={() => void tool.onClick()}
                >
                  <span style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                    {tool.icon}
                    {tool.label}
                  </span>
                  <ChevronRight size={12} color="var(--text-muted)" />
                </button>
              ))}
            </div>
          )}

          {/* TAB 10: TOGGLES */}
          {!inlineTool && activeTab === 'toggles' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div className="v-card" style={{ padding: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: 12.5, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Moon size={14} color="#818cf8" /> Modo Escuro do Windows
                </span>
                <button
                  className={`v-switch ${telemetry?.darkMode ? 'is-on' : ''}`}
                  onClick={async () => {
                    const next = !(telemetry?.darkMode ?? true);
                    const ok = await setWindowsDarkMode(next);
                    setTelemetry((p) => (p ? { ...p, darkMode: ok } : p));
                    notify(ok ? 'Windows Dark Mode ativado' : 'Windows Light Mode ativado');
                  }}
                />
              </div>

              <div className="v-card" style={{ padding: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: 12.5, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Sparkles size={14} color={accent} /> Ilha Dinâmica no Topo
                </span>
                <button
                  className={`v-switch ${settings.islandVisible ? 'is-on' : ''}`}
                  onClick={() => updateSettings({ islandVisible: !settings.islandVisible })}
                />
              </div>

              <button
                className="v-btn"
                onClick={async () => {
                  const pinned = await toggleWindowPin();
                  notify(pinned ? 'Janela ativa fixada no topo' : 'Janela desafixada');
                }}
              >
                <Pin size={14} color={accent} /> Fixar/Desafixar janela ativa sempre no topo
              </button>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 7 }}>
                <button className="v-btn" onClick={() => void launchWindowsUtility('taskmgr')}>
                  <Activity size={13} /> Task Manager
                </button>
                <button className="v-btn" onClick={() => void launchWindowsUtility('wt')}>
                  <Terminal size={13} /> Windows Terminal
                </button>
                <button className="v-btn" onClick={() => void launchWindowsUtility('ms-settings:sound')}>
                  <Volume2 size={13} /> Som Windows
                </button>
                <button className="v-btn" onClick={() => void launchWindowsUtility('ms-settings:display')}>
                  <Sun size={13} /> Tela Windows
                </button>
              </div>
            </div>
          )}
        </div>

        {/* FOOTER */}
        <div
          style={{
            padding: '9px 12px',
            borderTop: '1px solid var(--border-subtle)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <button
            className="v-btn"
            style={{ padding: '6px 12px', fontSize: 12 }}
            onClick={() => {
              void hideTrayPanel();
              void openSettingsWindow('general');
            }}
          >
            <Settings size={13} /> {labels.settingsBtn}
          </button>

          <button
            className="v-btn"
            style={{ padding: '6px 12px', fontSize: 12, color: '#fca5a5' }}
            onClick={() => void quitApp()}
          >
            <Power size={13} /> {labels.quitBtn}
          </button>
        </div>
      </div>
    </div>
  );
};

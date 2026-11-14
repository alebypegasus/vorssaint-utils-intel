import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Activity,
  Bot,
  Calendar as CalendarIcon,
  Camera,
  Check,
  ChevronUp,
  Clipboard,
  Copy,
  ExternalLink,
  FileCode,
  FileImage,
  FileText,
  FolderOpen,
  Grid,
  LayoutGrid,
  Link2,
  Lock,
  Moon,
  Music,
  Pause,
  Pin,
  PinOff,
  Pipette,
  Play,
  Plus,
  RefreshCw,
  RotateCcw,
  Scissors,
  Search,
  Settings,
  SkipBack,
  SkipForward,
  Sliders,
  Sparkles,
  StickyNote,
  Sun,
  Terminal,
  Timer as TimerIcon,
  Trash2,
  UploadCloud,
  Volume2,
  VolumeX,
  Zap,
} from 'lucide-react';
import { BrandMark } from '../components/BrandMark';
import { MascotFace } from '../components/MascotFace';
import { ISLAND_MODULE_META, UI_LABELS } from '../data/catalog';
import {
  captureScreenPng,
  copyToClipboard,
  fetchSystemTelemetry,
  focusWindow,
  listAudioSessions,
  listOpenWindows,
  lockWorkstation,
  openExternalUrl,
  openOverlay,
  openPathInExplorer,
  openSettingsWindow,
  pickScreenColor,
  safeListen,
  sendMediaAction,
  setAppAudio,
  setDisplayBrightness,
  setIslandBounds,
  setMasterAudio,
  setWindowsDarkMode,
  toggleTrayPanel,
  toggleWindowPin,
} from '../lib/bridge';
import { useVorssaintStore } from '../lib/store';
import { cleanUrl, isLikelyUrl } from '../lib/urlCleaner';
import type {
  AppAudioSession,
  IslandModuleId,
  OpenWindowEntry,
  SystemTelemetry,
} from '../types/vorssaint';

function formatTimerClock(totalSec: number): string {
  const s = Math.max(0, Math.floor(totalSec));
  const hrs = Math.floor(s / 3600);
  const mins = Math.floor((s % 3600) / 60);
  const secs = s % 60;
  if (hrs > 0) {
    return `${hrs}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }
  return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

function evalSafeMath(expr: string): string | null {
  const cleaned = expr.replace(/^=/, '').trim();
  if (!cleaned || !/^[0-9+\-*/().%\s]+$/.test(cleaned)) return null;
  try {
    const fn = new Function(`"use strict"; return (${cleaned});`);
    const res = fn();
    if (typeof res === 'number' && Number.isFinite(res)) {
      return Number.isInteger(res) ? String(res) : res.toFixed(4).replace(/\.?0+$/, '');
    }
    return null;
  } catch {
    return null;
  }
}

const MODULE_ICONS: Record<IslandModuleId, React.ReactNode> = {
  controls: <Sliders size={14} />,
  music: <Music size={14} />,
  files: <FolderOpen size={14} />,
  timer: <TimerIcon size={14} />,
  clipboard: <Clipboard size={14} />,
  mixer: <Volume2 size={14} />,
  scratchpad: <StickyNote size={14} />,
  calendar: <CalendarIcon size={14} />,
  system: <Activity size={14} />,
  camera: <Camera size={14} />,
  agents: <Bot size={14} />,
};

export const IslandWindow: React.FC = () => {
  const {
    settings,
    updateSettings,
    clipboard,
    addClipboardEntry,
    togglePinClipboard,
    clearClipboard,
    shelf,
    removeShelfItem,
    clearShelf,
    notes,
    saveNotes,
    timer,
    updateTimer,
    agents,
    toggleKeepAwakeState,
  } = useVorssaintStore();

  const labels = UI_LABELS[settings.language] ?? UI_LABELS.pt;

  const [expanded, setExpanded] = useState(false);
  const [draggingOver, setDraggingOver] = useState(false);
  const [activeModule, setActiveModule] = useState<IslandModuleId>('controls');
  const [showGallery, setShowGallery] = useState(false);
  const [galleryQuery, setGalleryQuery] = useState('');
  const [showInlineCmd, setShowInlineCmd] = useState(false);
  const [cmdQuery, setCmdQuery] = useState('');
  const [statusToast, setStatusToast] = useState<string | null>(null);
  const [telemetry, setTelemetry] = useState<SystemTelemetry | null>(null);
  const [audioSessions, setAudioSessions] = useState<AppAudioSession[]>([]);
  const [openWindows, setOpenWindows] = useState<OpenWindowEntry[]>([]);
  const [look, setLook] = useState({ x: 0, y: 0 });
  const [clipSearch, setClipSearch] = useState('');
  const [activeNoteId, setActiveNoteId] = useState<string>(notes[0]?.id ?? '');
  const [cameraMirrored, setCameraMirrored] = useState(true);
  const [cameraError, setCameraError] = useState<string | null>(null);

  const hoverOpenRef = useRef<number | null>(null);
  const hoverCloseRef = useRef<number | null>(null);
  const editingTextRef = useRef(false);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  const toast = useCallback((msg: string) => {
    setStatusToast(msg);
    window.setTimeout(() => {
      setStatusToast((curr) => (curr === msg ? null : curr));
    }, 2400);
  }, []);

  // Poll system telemetry smoothly
  const refreshTelemetry = useCallback(async () => {
    try {
      const t = await fetchSystemTelemetry();
      setTelemetry(t);
    } catch {
      // ignore transient poll failures
    }
  }, []);

  useEffect(() => {
    void refreshTelemetry();
    const id = window.setInterval(() => {
      void refreshTelemetry();
    }, expanded ? 2000 : 5000);
    return () => window.clearInterval(id);
  }, [expanded, refreshTelemetry]);

  // Refresh audio sessions when mixer tab active
  const refreshMixer = useCallback(async () => {
    try {
      const list = await listAudioSessions();
      setAudioSessions(list);
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    if (expanded && activeModule === 'mixer') {
      void refreshMixer();
    }
    if (expanded && showInlineCmd) {
      void listOpenWindows().then(setOpenWindows).catch(() => {});
    }
  }, [expanded, activeModule, showInlineCmd, refreshMixer]);

  // Shared Timer / Stopwatch 1s tick
  useEffect(() => {
    if (!timer.running) return;
    const id = window.setInterval(() => {
      updateTimer((prev) => {
        if (!prev.running) return prev;
        if (prev.mode === 'timer') {
          const nextRem = Math.max(0, prev.remainingSec - 1);
          return {
            ...prev,
            remainingSec: nextRem,
            running: nextRem > 0,
          };
        }
        return {
          ...prev,
          elapsedSec: prev.elapsedSec + 1,
        };
      });
    }, 1000);
    return () => window.clearInterval(id);
  }, [timer.running, updateTimer]);

  // Webcam stream lifecycle when camera module is active
  useEffect(() => {
    if (!expanded || activeModule !== 'camera') {
      if (videoRef.current?.srcObject) {
        const tracks = (videoRef.current.srcObject as MediaStream).getTracks();
        tracks.forEach((t) => t.stop());
        videoRef.current.srcObject = null;
      }
      return;
    }

    let cancelled = false;
    setCameraError(null);
    navigator.mediaDevices
      ?.getUserMedia({ video: { width: 640, height: 360 } })
      .then((stream) => {
        if (cancelled) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
        }
      })
      .catch(() => {
        if (!cancelled) {
          setCameraError('Webcam indisponível ou permissão de câmera negada no Windows.');
        }
      });

    return () => {
      cancelled = true;
      if (videoRef.current?.srcObject) {
        const tracks = (videoRef.current.srcObject as MediaStream).getTracks();
        tracks.forEach((t) => t.stop());
        videoRef.current.srcObject = null;
      }
    };
  }, [expanded, activeModule]);

  // Listen to native Win32 / Tauri events for Dynamic Island
  useEffect(() => {
    const unsubs: (() => void)[] = [];

    safeListen('toggle-island-expand', () => {
      setExpanded((e) => !e);
    }).then((u) => unsubs.push(u));

    safeListen<boolean>('island-drag-state', (dragging) => {
      setDraggingOver(dragging);
      if (dragging) {
        setExpanded(true);
        setShowGallery(false);
        setActiveModule('files');
      }
    }).then((u) => unsubs.push(u));

    safeListen('island-files-dropped', () => {
      setDraggingOver(false);
      setExpanded(true);
      setShowGallery(false);
      setActiveModule('files');
      toast('Arquivos guardados na Prateleira');
    }).then((u) => unsubs.push(u));

    safeListen<boolean>('keep-awake-changed', (active) => {
      setTelemetry((prev) => (prev ? { ...prev, keepAwakeActive: active } : prev));
    }).then((u) => unsubs.push(u));

    return () => {
      unsubs.forEach((u) => u());
    };
  }, [toast]);

  // Resize Win32 Island bounds cleanly when collapsed/expanded state changes
  const compactWidth = useMemo(() => {
    let w = 248;
    if (telemetry?.mediaSession?.isPlaying) w += 92;
    if (timer.running) w += 64;
    if (shelf.length > 0) w += 34;
    return Math.min(430, w);
  }, [telemetry?.mediaSession?.isPlaying, timer.running, shelf.length]);

  useEffect(() => {
    if (!expanded) {
      void setIslandBounds(compactWidth, 40, false);
    } else {
      const h = showInlineCmd ? 408 : 374;
      void setIslandBounds(716, h, editingTextRef.current || showInlineCmd || showGallery);
    }
  }, [expanded, compactWidth, showInlineCmd, showGallery]);

  const requestInputFocus = useCallback(() => {
    editingTextRef.current = true;
    void setIslandBounds(716, showInlineCmd ? 408 : 374, true);
  }, [showInlineCmd]);

  const handleMouseEnter = () => {
    if (hoverCloseRef.current) {
      window.clearTimeout(hoverCloseRef.current);
      hoverCloseRef.current = null;
    }
    if (!expanded && settings.islandOpenOnHover) {
      hoverOpenRef.current = window.setTimeout(() => {
        setExpanded(true);
      }, 140);
    }
  };

  const handleMouseLeave = () => {
    if (hoverOpenRef.current) {
      window.clearTimeout(hoverOpenRef.current);
      hoverOpenRef.current = null;
    }
    if (
      expanded &&
      settings.islandOpenOnHover &&
      !settings.islandPinned &&
      !draggingOver &&
      !editingTextRef.current &&
      !showInlineCmd
    ) {
      hoverCloseRef.current = window.setTimeout(() => {
        setExpanded(false);
        setShowGallery(false);
      }, 340);
    }
  };

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    const y = ((e.clientY - rect.top) / rect.height) * 2 - 1;
    setLook({ x, y });
  };

  const mascotMood = useMemo(() => {
    if (draggingOver) return 'dragging' as const;
    if (telemetry?.mediaSession?.isPlaying) return 'happy' as const;
    if (!expanded && !telemetry?.keepAwakeActive) return 'idle' as const;
    return 'happy' as const;
  }, [draggingOver, telemetry?.mediaSession?.isPlaying, expanded, telemetry?.keepAwakeActive]);

  const isNotchStyle = settings.islandSilhouette === 'notch';
  const accent = settings.accentHex || '#38bdf8';

  const currentNote = notes.find((n) => n.id === activeNoteId) ?? notes[0];
  const runningAgentsCount = agents.filter((a) => a.status === 'running').length;

  const calendarGrid = useMemo(() => {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth();
    const firstDay = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const cells: (number | null)[] = Array(firstDay).fill(null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(d);
    return {
      monthLabel: now.toLocaleDateString(settings.language === 'en' ? 'en-US' : 'pt-BR', {
        month: 'long',
        year: 'numeric',
      }),
      today: now.getDate(),
      cells,
    };
  }, [settings.language]);

  const mathPreview = evalSafeMath(cmdQuery);
  const urlPreview = isLikelyUrl(cmdQuery) ? cleanUrl(cmdQuery) : null;

  const filteredClipboard = clipboard.filter((c) =>
    !clipSearch.trim() ? true : c.text.toLowerCase().includes(clipSearch.toLowerCase())
  );

  const filteredGallery = ISLAND_MODULE_META.filter((m) =>
    !galleryQuery.trim()
      ? true
      : m.title[settings.language].toLowerCase().includes(galleryQuery.toLowerCase())
  );

  const shellRadius = expanded
    ? isNotchStyle
      ? '0 0 26px 26px'
      : '24px'
    : isNotchStyle
    ? '0 0 18px 18px'
    : '999px';

  return (
    <div
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      onMouseMove={handleMouseMove}
      style={{
        width: '100vw',
        height: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        paddingTop: isNotchStyle ? 0 : expanded ? 6 : 4,
        background: 'transparent',
        overflow: 'hidden',
      }}
    >
      {/* OUTER DYNAMIC ISLAND CONTAINER */}
      <div
        style={{
          width: expanded ? 'calc(100vw - 12px)' : 'calc(100vw - 8px)',
          height: expanded ? 'calc(100vh - 12px)' : 34,
          borderRadius: shellRadius,
          background: settings.islandLiquidGlass
            ? 'linear-gradient(180deg, rgba(16, 18, 26, 0.94) 0%, rgba(10, 12, 18, 0.97) 100%)'
            : '#090b10',
          border: draggingOver
            ? `1.5px solid ${accent}`
            : '1px solid rgba(255, 255, 255, 0.14)',
          boxShadow: draggingOver
            ? `0 10px 30px ${accent}45`
            : '0 10px 32px rgba(0, 0, 0, 0.55), inset 0 1px 0 rgba(255,255,255,0.08)',
          backdropFilter: 'blur(26px) saturate(160%)',
          color: '#f8fafc',
          display: 'flex',
          flexDirection: 'column',
          transition: 'border-color 180ms ease, box-shadow 180ms ease',
          overflow: 'hidden',
        }}
      >
        {/* COMPACT RESTING STRIP */}
        {!expanded && (
          <div
            onClick={() => setExpanded(true)}
            style={{
              height: '100%',
              padding: '0 12px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 8,
              cursor: 'pointer',
              userSelect: 'none',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, minWidth: 0 }}>
              {settings.islandMascotEnabled ? (
                <MascotFace size={20} look={look} mood={mascotMood} accent={accent} />
              ) : (
                <BrandMark size={16} light />
              )}
              <span
                style={{
                  fontSize: 11.5,
                  fontWeight: 600,
                  letterSpacing: '-0.01em',
                  color: 'rgba(248, 250, 252, 0.92)',
                  whiteSpace: 'nowrap',
                }}
              >
                {telemetry?.mediaSession?.isPlaying
                  ? telemetry.mediaSession.title.slice(0, 22)
                  : 'Vorssaint'}
              </span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexShrink: 0 }}>
              {telemetry?.mediaSession?.isPlaying && (
                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 12 }}>
                  <span className="eq-bar" style={{ background: accent }} />
                  <span className="eq-bar" style={{ background: accent }} />
                  <span className="eq-bar" style={{ background: accent }} />
                </div>
              )}

              {timer.running && (
                <span
                  style={{
                    fontSize: 11,
                    fontWeight: 700,
                    fontVariantNumeric: 'tabular-nums',
                    color: '#fb923c',
                    background: 'rgba(251, 146, 60, 0.14)',
                    padding: '1px 6px',
                    borderRadius: 999,
                  }}
                >
                  {formatTimerClock(timer.mode === 'timer' ? timer.remainingSec : timer.elapsedSec)}
                </span>
              )}

              {shelf.length > 0 && (
                <span
                  style={{
                    fontSize: 10.5,
                    fontWeight: 700,
                    color: '#fbbf24',
                    background: 'rgba(251, 191, 36, 0.16)',
                    padding: '1px 6px',
                    borderRadius: 999,
                  }}
                >
                  {shelf.length}
                </span>
              )}

              {telemetry?.keepAwakeActive && (
                <Zap size={12} color="#fbbf24" fill="#fbbf24" />
              )}

              {runningAgentsCount > 0 && (
                <span
                  title="Agentes IA ativos"
                  style={{
                    width: 6,
                    height: 6,
                    borderRadius: 999,
                    background: accent,
                    boxShadow: `0 0 8px ${accent}`,
                  }}
                />
              )}
            </div>
          </div>
        )}

        {/* EXPANDED DYNAMIC ISLAND */}
        {expanded && (
          <>
            {/* HEADER BAR */}
            <div
              style={{
                height: 44,
                padding: '0 12px',
                borderBottom: '1px solid rgba(255,255,255,0.08)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: 8,
                flexShrink: 0,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
                {settings.islandMascotEnabled ? (
                  <MascotFace size={23} look={look} mood={mascotMood} accent={accent} />
                ) : (
                  <BrandMark size={18} light />
                )}

                {/* SCROLLABLE MODULE PILLS */}
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 4,
                    overflowX: 'auto',
                    scrollbarWidth: 'none',
                  }}
                >
                  {ISLAND_MODULE_META.slice(0, 7).map((mod) => {
                    const active = !showGallery && activeModule === mod.id;
                    return (
                      <button
                        key={mod.id}
                        onClick={() => {
                          setShowGallery(false);
                          setActiveModule(mod.id);
                          editingTextRef.current = false;
                        }}
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                          padding: '5px 9px',
                          borderRadius: 999,
                          border: active
                            ? `1px solid ${mod.accent}55`
                            : '1px solid transparent',
                          background: active ? `${mod.accent}22` : 'rgba(255,255,255,0.04)',
                          color: active ? '#ffffff' : 'rgba(255,255,255,0.68)',
                          fontSize: 11.5,
                          fontWeight: 600,
                          cursor: 'pointer',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        <span style={{ color: active ? mod.accent : 'inherit', display: 'flex' }}>
                          {MODULE_ICONS[mod.id]}
                        </span>
                        {mod.title[settings.language]}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* RIGHT UTILITY CONTROLS */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
                <button
                  title={labels.sectionsTitle}
                  onClick={() => {
                    setShowGallery((g) => !g);
                    editingTextRef.current = false;
                  }}
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: 8,
                    border: '1px solid rgba(255,255,255,0.1)',
                    background: showGallery ? `${accent}30` : 'rgba(255,255,255,0.06)',
                    color: '#fff',
                    display: 'grid',
                    placeItems: 'center',
                    cursor: 'pointer',
                  }}
                >
                  <LayoutGrid size={13} />
                </button>
                <button
                  title="Comando Rápido"
                  onClick={() => {
                    setShowInlineCmd((v) => !v);
                    editingTextRef.current = !showInlineCmd;
                  }}
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: 8,
                    border: '1px solid rgba(255,255,255,0.1)',
                    background: showInlineCmd ? `${accent}30` : 'rgba(255,255,255,0.06)',
                    color: '#fff',
                    display: 'grid',
                    placeItems: 'center',
                    cursor: 'pointer',
                  }}
                >
                  <Terminal size={13} />
                </button>
                <button
                  title={settings.islandPinned ? 'Desafixar Ilha' : 'Fixar Ilha aberta'}
                  onClick={() => updateSettings({ islandPinned: !settings.islandPinned })}
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: 8,
                    border: '1px solid rgba(255,255,255,0.1)',
                    background: settings.islandPinned ? `${accent}30` : 'rgba(255,255,255,0.06)',
                    color: settings.islandPinned ? accent : '#fff',
                    display: 'grid',
                    placeItems: 'center',
                    cursor: 'pointer',
                  }}
                >
                  {settings.islandPinned ? <Pin size={13} /> : <PinOff size={13} />}
                </button>
                <button
                  title="Painel da Bandeja"
                  onClick={() => void toggleTrayPanel()}
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: 8,
                    border: '1px solid rgba(255,255,255,0.1)',
                    background: 'rgba(255,255,255,0.06)',
                    color: '#fff',
                    display: 'grid',
                    placeItems: 'center',
                    cursor: 'pointer',
                  }}
                >
                  <Grid size={13} />
                </button>
                <button
                  title={labels.settingsBtn}
                  onClick={() => void openSettingsWindow('notch')}
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: 8,
                    border: '1px solid rgba(255,255,255,0.1)',
                    background: 'rgba(255,255,255,0.06)',
                    color: '#fff',
                    display: 'grid',
                    placeItems: 'center',
                    cursor: 'pointer',
                  }}
                >
                  <Settings size={13} />
                </button>
                <button
                  title={labels.collapseIsland}
                  onClick={() => {
                    editingTextRef.current = false;
                    setShowInlineCmd(false);
                    setShowGallery(false);
                    setExpanded(false);
                  }}
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: 8,
                    border: '1px solid rgba(255,255,255,0.1)',
                    background: 'rgba(255,255,255,0.06)',
                    color: '#fff',
                    display: 'grid',
                    placeItems: 'center',
                    cursor: 'pointer',
                  }}
                >
                  <ChevronUp size={14} />
                </button>
              </div>
            </div>

            {/* OPTIONAL INLINE COMMAND BAR */}
            {showInlineCmd && (
              <div
                style={{
                  padding: '8px 12px',
                  borderBottom: '1px solid rgba(255,255,255,0.08)',
                  background: 'rgba(0,0,0,0.28)',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 6,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Search size={14} color={accent} />
                  <input
                    className="v-input"
                    value={cmdQuery}
                    onFocus={requestInputFocus}
                    onChange={(e) => setCmdQuery(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Escape') {
                        setShowInlineCmd(false);
                        editingTextRef.current = false;
                      } else if (e.key === 'Enter' && mathPreview) {
                        void copyToClipboard(mathPreview);
                        toast(`Copiado: ${mathPreview}`);
                      } else if (e.key === 'Enter' && urlPreview?.valid) {
                        void copyToClipboard(urlPreview.cleaned);
                        toast(`URL limpa copiada (${urlPreview.removedCount} trackers)`);
                      } else if (e.key === 'Enter' && cmdQuery.trim()) {
                        const match = openWindows.find((w) =>
                          w.title.toLowerCase().includes(cmdQuery.toLowerCase())
                        );
                        if (match) {
                          void focusWindow(match.hwnd);
                          toast(`Focado: ${match.title.slice(0, 28)}`);
                        }
                      }
                    }}
                    placeholder={labels.commandPlaceholder}
                    style={{
                      padding: '6px 10px',
                      fontSize: 12,
                      background: 'rgba(255,255,255,0.06)',
                      color: '#fff',
                      borderColor: 'rgba(255,255,255,0.14)',
                    }}
                  />
                  {mathPreview && (
                    <span
                      style={{
                        padding: '4px 10px',
                        borderRadius: 8,
                        background: `${accent}26`,
                        color: accent,
                        fontWeight: 700,
                        fontSize: 12,
                        whiteSpace: 'nowrap',
                      }}
                    >
                      = {mathPreview}
                    </span>
                  )}
                  {urlPreview?.valid && urlPreview.removedCount > 0 && (
                    <button
                      onClick={() => {
                        void copyToClipboard(urlPreview.cleaned);
                        toast('URL limpa copiada');
                      }}
                      style={{
                        padding: '5px 10px',
                        borderRadius: 8,
                        border: 'none',
                        background: '#34d399',
                        color: '#06120e',
                        fontSize: 11.5,
                        fontWeight: 700,
                        cursor: 'pointer',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      Limpar URL (-{urlPreview.removedCount})
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* TOAST BAR */}
            {statusToast && (
              <div
                style={{
                  position: 'absolute',
                  bottom: 10,
                  right: 14,
                  zIndex: 40,
                  background: '#111827',
                  border: `1px solid ${accent}66`,
                  color: '#fff',
                  padding: '5px 11px',
                  borderRadius: 999,
                  fontSize: 11.5,
                  fontWeight: 600,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  boxShadow: '0 8px 20px rgba(0,0,0,0.45)',
                }}
              >
                <Check size={12} color={accent} />
                {statusToast}
              </div>
            )}

            {/* BODY */}
            <div style={{ flex: 1, padding: 12, overflowY: 'auto', position: 'relative' }}>
              {/* SECTIONS GALLERY (NotchSectionsView parity) */}
              {showGallery ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <Search size={14} color="rgba(255,255,255,0.55)" />
                    <input
                      className="v-input"
                      value={galleryQuery}
                      onFocus={requestInputFocus}
                      onChange={(e) => setGalleryQuery(e.target.value)}
                      placeholder={labels.sectionsTitle}
                      style={{
                        padding: '6px 10px',
                        fontSize: 12,
                        background: 'rgba(255,255,255,0.06)',
                        color: '#fff',
                        borderColor: 'rgba(255,255,255,0.12)',
                      }}
                    />
                  </div>
                  <div
                    style={{
                      display: 'grid',
                      gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
                      gap: 8,
                    }}
                  >
                    {filteredGallery.map((mod) => (
                      <button
                        key={mod.id}
                        onClick={() => {
                          setActiveModule(mod.id);
                          setShowGallery(false);
                          editingTextRef.current = false;
                        }}
                        style={{
                          padding: '10px 10px',
                          borderRadius: 12,
                          border:
                            activeModule === mod.id
                              ? `1px solid ${mod.accent}`
                              : '1px solid rgba(255,255,255,0.08)',
                          background:
                            activeModule === mod.id
                              ? `${mod.accent}20`
                              : 'rgba(255,255,255,0.04)',
                          color: '#fff',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          cursor: 'pointer',
                          textAlign: 'left',
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span
                            style={{
                              width: 26,
                              height: 26,
                              borderRadius: 8,
                              background: `${mod.accent}26`,
                              color: mod.accent,
                              display: 'grid',
                              placeItems: 'center',
                            }}
                          >
                            {MODULE_ICONS[mod.id]}
                          </span>
                          <span style={{ fontSize: 12, fontWeight: 600 }}>
                            {mod.title[settings.language]}
                          </span>
                        </div>
                        <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)' }}>
                          {mod.shortcut}
                        </span>
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                <>
                  {/* 1. CONTROLS */}
                  {activeModule === 'controls' && (
                    <div
                      style={{
                        display: 'grid',
                        gridTemplateColumns: '1.15fr 1fr',
                        gap: 12,
                        height: '100%',
                      }}
                    >
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                          <button
                            onClick={async () => {
                              const next = !telemetry?.keepAwakeActive;
                              const res = await toggleKeepAwakeState(next);
                              setTelemetry((p) => (p ? { ...p, keepAwakeActive: res } : p));
                              toast(res ? 'Manter Ligado ativado' : 'Manter Ligado desligado');
                            }}
                            style={{
                              padding: '10px 12px',
                              borderRadius: 12,
                              border: telemetry?.keepAwakeActive
                                ? '1px solid rgba(251, 191, 36, 0.5)'
                                : '1px solid rgba(255,255,255,0.09)',
                              background: telemetry?.keepAwakeActive
                                ? 'rgba(251, 191, 36, 0.16)'
                                : 'rgba(255,255,255,0.04)',
                              color: '#fff',
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                              cursor: 'pointer',
                              textAlign: 'left',
                            }}
                          >
                            <Zap size={16} color="#fbbf24" />
                            <div>
                              <div style={{ fontSize: 12, fontWeight: 600 }}>Manter Ligado</div>
                              <div style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.58)' }}>
                                {telemetry?.keepAwakeActive ? 'PC desperto' : 'Normal'}
                              </div>
                            </div>
                          </button>

                          <button
                            onClick={async () => {
                              const next = !(telemetry?.darkMode ?? true);
                              const ok = await setWindowsDarkMode(next);
                              setTelemetry((p) => (p ? { ...p, darkMode: ok } : p));
                              toast(ok ? 'Modo Escuro do Windows' : 'Modo Claro do Windows');
                            }}
                            style={{
                              padding: '10px 12px',
                              borderRadius: 12,
                              border: '1px solid rgba(255,255,255,0.09)',
                              background: 'rgba(255,255,255,0.04)',
                              color: '#fff',
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                              cursor: 'pointer',
                              textAlign: 'left',
                            }}
                          >
                            {telemetry?.darkMode ? (
                              <Moon size={16} color="#818cf8" />
                            ) : (
                              <Sun size={16} color="#fbbf24" />
                            )}
                            <div>
                              <div style={{ fontSize: 12, fontWeight: 600 }}>Tema Windows</div>
                              <div style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.58)' }}>
                                {telemetry?.darkMode ? 'Escuro' : 'Claro'}
                              </div>
                            </div>
                          </button>
                        </div>

                        {/* SLIDERS: MASTER VOLUME & BRIGHTNESS */}
                        <div
                          style={{
                            padding: '10px 12px',
                            borderRadius: 12,
                            background: 'rgba(255,255,255,0.04)',
                            border: '1px solid rgba(255,255,255,0.08)',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: 10,
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                            <button
                              onClick={async () => {
                                const res = await setMasterAudio(
                                  undefined,
                                  !(telemetry?.masterMuted ?? false)
                                );
                                setTelemetry((p) =>
                                  p
                                    ? { ...p, masterVolume: res.volume, masterMuted: res.muted }
                                    : p
                                );
                              }}
                              style={{
                                border: 'none',
                                background: 'transparent',
                                color: '#fff',
                                cursor: 'pointer',
                                display: 'flex',
                              }}
                            >
                              {telemetry?.masterMuted ? <VolumeX size={15} /> : <Volume2 size={15} />}
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
                            <span style={{ fontSize: 11.5, width: 32, textAlign: 'right' }}>
                              {telemetry?.masterVolume ?? 65}%
                            </span>
                          </div>

                          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                            <Sun size={15} color="#fbbf24" />
                            <input
                              type="range"
                              min={10}
                              max={100}
                              value={settings.brightnessLevel}
                              onChange={(e) => {
                                const v = Number(e.target.value);
                                updateSettings({ brightnessLevel: v });
                                void setDisplayBrightness(v);
                              }}
                              style={{ flex: 1, accentColor: '#fbbf24' }}
                            />
                            <span style={{ fontSize: 11.5, width: 32, textAlign: 'right' }}>
                              {settings.brightnessLevel}%
                            </span>
                          </div>
                        </div>

                        {/* QUICK TELEMETRY SUMMARY */}
                        <div
                          style={{
                            padding: '8px 12px',
                            borderRadius: 12,
                            background: 'rgba(255,255,255,0.03)',
                            border: '1px solid rgba(255,255,255,0.07)',
                            display: 'flex',
                            justifyContent: 'space-between',
                            fontSize: 11.5,
                            color: 'rgba(255,255,255,0.75)',
                          }}
                        >
                          <span>CPU {Math.round(telemetry?.cpuPercent ?? 0)}%</span>
                          <span>
                            RAM {(telemetry?.memoryUsedGb ?? 0).toFixed(1)}/
                            {(telemetry?.memoryTotalGb ?? 0).toFixed(0)} GB
                          </span>
                          <span>
                            ↓ {(telemetry?.downloadKbPerSec ?? 0).toFixed(0)} KB/s
                          </span>
                        </div>
                      </div>

                      {/* QUICK ACTIONS GRID */}
                      <div
                        style={{
                          display: 'grid',
                          gridTemplateColumns: '1fr 1fr',
                          gap: 8,
                          alignContent: 'start',
                        }}
                      >
                        {[
                          {
                            label: 'Captura PNG',
                            icon: <Scissors size={14} color="#34d399" />,
                            action: async () => {
                              const shot = await captureScreenPng();
                              if (shot) toast(`Salva: ${shot.fileName}`);
                            },
                          },
                          {
                            label: 'Conta-gotas',
                            icon: <Pipette size={14} color="#f472b6" />,
                            action: async () => {
                              const c = await pickScreenColor();
                              await copyToClipboard(c.hex);
                              addClipboardEntry(c.hex);
                              toast(`Cor copiada: ${c.hex}`);
                            },
                          },
                          {
                            label: 'Fixar Janela',
                            icon: <Pin size={14} color="#38bdf8" />,
                            action: async () => {
                              const pinned = await toggleWindowPin();
                              toast(pinned ? 'Janela fixada no topo' : 'Janela desafixada');
                            },
                          },
                          {
                            label: 'Command Bar',
                            icon: <Terminal size={14} color="#a78bfa" />,
                            action: () => void openOverlay('command'),
                          },
                          {
                            label: 'Modo Limpeza',
                            icon: <Sparkles size={14} color="#fbbf24" />,
                            action: () => void openOverlay('cleaning'),
                          },
                          {
                            label: 'Bloquear PC',
                            icon: <Lock size={14} color="#f87171" />,
                            action: () => void lockWorkstation(),
                          },
                        ].map((btn) => (
                          <button
                            key={btn.label}
                            onClick={() => void btn.action()}
                            style={{
                              padding: '10px 10px',
                              borderRadius: 11,
                              border: '1px solid rgba(255,255,255,0.09)',
                              background: 'rgba(255,255,255,0.04)',
                              color: '#fff',
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                              fontSize: 12,
                              fontWeight: 600,
                              cursor: 'pointer',
                            }}
                          >
                            {btn.icon}
                            {btn.label}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* 2. MUSIC / MEDIA */}
                  {activeModule === 'music' && (
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        gap: 16,
                        height: '100%',
                        padding: '8px 6px',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 14, minWidth: 0 }}>
                        <div
                          style={{
                            width: 68,
                            height: 68,
                            borderRadius: 16,
                            background: `linear-gradient(135deg, ${accent}40, rgba(244,114,182,0.32))`,
                            border: '1px solid rgba(255,255,255,0.16)',
                            display: 'grid',
                            placeItems: 'center',
                            flexShrink: 0,
                          }}
                        >
                          <Music size={28} color="#fff" />
                        </div>
                        <div style={{ minWidth: 0 }}>
                          <div
                            style={{
                              fontSize: 14,
                              fontWeight: 700,
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                              whiteSpace: 'nowrap',
                              maxWidth: 320,
                            }}
                          >
                            {telemetry?.mediaSession?.title || 'Nenhuma mídia em reprodução'}
                          </div>
                          <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)', marginTop: 3 }}>
                            {telemetry?.mediaSession?.artist ||
                              'Abra Spotify, YouTube Music ou Player do Windows'}
                          </div>
                          <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
                            <span
                              style={{
                                fontSize: 10.5,
                                fontWeight: 600,
                                padding: '2px 8px',
                                borderRadius: 999,
                                background: 'rgba(255,255,255,0.08)',
                              }}
                            >
                              {telemetry?.mediaSession?.appName || 'Windows Media Keys'}
                            </span>
                          </div>
                        </div>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <button
                          onClick={() => void sendMediaAction('prev')}
                          style={{
                            width: 38,
                            height: 38,
                            borderRadius: 999,
                            border: '1px solid rgba(255,255,255,0.12)',
                            background: 'rgba(255,255,255,0.06)',
                            color: '#fff',
                            display: 'grid',
                            placeItems: 'center',
                            cursor: 'pointer',
                          }}
                        >
                          <SkipBack size={16} />
                        </button>
                        <button
                          onClick={() => void sendMediaAction('playPause')}
                          style={{
                            width: 46,
                            height: 46,
                            borderRadius: 999,
                            border: 'none',
                            background: accent,
                            color: '#06121a',
                            display: 'grid',
                            placeItems: 'center',
                            cursor: 'pointer',
                          }}
                        >
                          {telemetry?.mediaSession?.isPlaying ? (
                            <Pause size={18} />
                          ) : (
                            <Play size={18} />
                          )}
                        </button>
                        <button
                          onClick={() => void sendMediaAction('next')}
                          style={{
                            width: 38,
                            height: 38,
                            borderRadius: 999,
                            border: '1px solid rgba(255,255,255,0.12)',
                            background: 'rgba(255,255,255,0.06)',
                            color: '#fff',
                            display: 'grid',
                            placeItems: 'center',
                            cursor: 'pointer',
                          }}
                        >
                          <SkipForward size={16} />
                        </button>
                      </div>
                    </div>
                  )}

                  {/* 3. FILE SHELF */}
                  {activeModule === 'files' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                      <div
                        style={{
                          padding: draggingOver ? '22px 14px' : '12px 14px',
                          borderRadius: 12,
                          border: `1.5px dashed ${draggingOver ? accent : 'rgba(255,255,255,0.18)'}`,
                          background: draggingOver ? `${accent}1a` : 'rgba(255,255,255,0.03)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          gap: 10,
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                          <UploadCloud size={18} color={accent} />
                          <div>
                            <div style={{ fontSize: 12.5, fontWeight: 600 }}>
                              Prateleira da Ilha ({shelf.length} arquivos)
                            </div>
                            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.58)' }}>
                              Arraste qualquer arquivo do Windows Explorer diretamente sobre a Ilha
                            </div>
                          </div>
                        </div>
                        {shelf.length > 0 && (
                          <button
                            onClick={clearShelf}
                            style={{
                              padding: '5px 10px',
                              borderRadius: 8,
                              border: '1px solid rgba(255,255,255,0.12)',
                              background: 'rgba(255,255,255,0.06)',
                              color: '#fca5a5',
                              fontSize: 11,
                              fontWeight: 600,
                              cursor: 'pointer',
                            }}
                          >
                            Limpar
                          </button>
                        )}
                      </div>

                      {shelf.length > 0 && (
                        <div
                          style={{
                            display: 'grid',
                            gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
                            gap: 8,
                          }}
                        >
                          {shelf.map((item) => (
                            <div
                              key={item.id}
                              style={{
                                padding: 9,
                                borderRadius: 11,
                                border: '1px solid rgba(255,255,255,0.1)',
                                background: 'rgba(255,255,255,0.04)',
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 6,
                              }}
                            >
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                {item.kind === 'image' ? (
                                  <FileImage size={14} color="#34d399" />
                                ) : item.kind === 'code' ? (
                                  <FileCode size={14} color="#60a5fa" />
                                ) : (
                                  <FileText size={14} color="#fbbf24" />
                                )}
                                <span
                                  style={{
                                    fontSize: 11.5,
                                    fontWeight: 600,
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis',
                                    whiteSpace: 'nowrap',
                                    flex: 1,
                                  }}
                                >
                                  {item.name}
                                </span>
                              </div>
                              <div
                                style={{
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'space-between',
                                  fontSize: 10.5,
                                  color: 'rgba(255,255,255,0.55)',
                                }}
                              >
                                <span>{item.sizeLabel}</span>
                                <div style={{ display: 'flex', gap: 6 }}>
                                  <button
                                    title="Abrir no Explorer"
                                    onClick={() => void openPathInExplorer(item.path)}
                                    style={{
                                      border: 'none',
                                      background: 'transparent',
                                      color: accent,
                                      cursor: 'pointer',
                                    }}
                                  >
                                    <ExternalLink size={12} />
                                  </button>
                                  <button
                                    title="Copiar caminho"
                                    onClick={() => {
                                      void copyToClipboard(item.path);
                                      toast('Caminho copiado');
                                    }}
                                    style={{
                                      border: 'none',
                                      background: 'transparent',
                                      color: '#cbd5e1',
                                      cursor: 'pointer',
                                    }}
                                  >
                                    <Copy size={12} />
                                  </button>
                                  <button
                                    title="Remover"
                                    onClick={() => removeShelfItem(item.id)}
                                    style={{
                                      border: 'none',
                                      background: 'transparent',
                                      color: '#f87171',
                                      cursor: 'pointer',
                                    }}
                                  >
                                    <Trash2 size={12} />
                                  </button>
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  )}

                  {/* 4. TIMER / POMODORO */}
                  {activeModule === 'timer' && (
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        gap: 16,
                        height: '100%',
                        padding: '4px 8px',
                      }}
                    >
                      <div>
                        <div style={{ display: 'flex', gap: 6, marginBottom: 8 }}>
                          {(['timer', 'stopwatch'] as const).map((m) => (
                            <button
                              key={m}
                              onClick={() =>
                                updateTimer((p) => ({ ...p, mode: m, running: false }))
                              }
                              style={{
                                padding: '4px 10px',
                                borderRadius: 999,
                                border: '1px solid rgba(255,255,255,0.1)',
                                background:
                                  timer.mode === m ? `${accent}26` : 'rgba(255,255,255,0.05)',
                                color: timer.mode === m ? '#fff' : 'rgba(255,255,255,0.65)',
                                fontSize: 11.5,
                                fontWeight: 600,
                                cursor: 'pointer',
                              }}
                            >
                              {m === 'timer' ? 'Timer / Foco' : 'Cronômetro'}
                            </button>
                          ))}
                        </div>

                        <div
                          style={{
                            fontSize: 42,
                            fontWeight: 700,
                            fontVariantNumeric: 'tabular-nums',
                            letterSpacing: '-0.03em',
                          }}
                        >
                          {formatTimerClock(
                            timer.mode === 'timer' ? timer.remainingSec : timer.elapsedSec
                          )}
                        </div>
                      </div>

                      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'flex-end' }}>
                        {timer.mode === 'timer' && (
                          <div style={{ display: 'flex', gap: 6 }}>
                            {[5, 15, 25, 45].map((mins) => (
                              <button
                                key={mins}
                                onClick={() =>
                                  updateTimer((p) => ({
                                    ...p,
                                    presetMinutes: mins,
                                    remainingSec: mins * 60,
                                    running: false,
                                  }))
                                }
                                style={{
                                  padding: '5px 10px',
                                  borderRadius: 8,
                                  border: '1px solid rgba(255,255,255,0.1)',
                                  background:
                                    timer.presetMinutes === mins
                                      ? `${accent}22`
                                      : 'rgba(255,255,255,0.04)',
                                  color: '#fff',
                                  fontSize: 11.5,
                                  fontWeight: 600,
                                  cursor: 'pointer',
                                }}
                              >
                                {mins}m
                              </button>
                            ))}
                          </div>
                        )}

                        <div style={{ display: 'flex', gap: 8 }}>
                          <button
                            onClick={() =>
                              updateTimer((p) => ({ ...p, running: !p.running }))
                            }
                            style={{
                              padding: '8px 16px',
                              borderRadius: 10,
                              border: 'none',
                              background: timer.running ? '#f59e0b' : accent,
                              color: '#081018',
                              fontWeight: 700,
                              fontSize: 12.5,
                              cursor: 'pointer',
                            }}
                          >
                            {timer.running ? 'Pausar' : 'Iniciar'}
                          </button>
                          <button
                            onClick={() =>
                              updateTimer((p) => ({
                                ...p,
                                running: false,
                                remainingSec: p.presetMinutes * 60,
                                elapsedSec: 0,
                                laps: [],
                              }))
                            }
                            style={{
                              padding: '8px 12px',
                              borderRadius: 10,
                              border: '1px solid rgba(255,255,255,0.12)',
                              background: 'rgba(255,255,255,0.06)',
                              color: '#fff',
                              cursor: 'pointer',
                            }}
                          >
                            <RotateCcw size={14} />
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 5. CLIPBOARD */}
                  {activeModule === 'clipboard' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      <div style={{ display: 'flex', gap: 8 }}>
                        <input
                          className="v-input"
                          value={clipSearch}
                          onFocus={requestInputFocus}
                          onChange={(e) => setClipSearch(e.target.value)}
                          placeholder="Filtrar histórico do Windows Clipboard..."
                          style={{
                            padding: '6px 10px',
                            fontSize: 12,
                            background: 'rgba(255,255,255,0.06)',
                            color: '#fff',
                            borderColor: 'rgba(255,255,255,0.12)',
                          }}
                        />
                        <button
                          onClick={clearClipboard}
                          style={{
                            padding: '0 10px',
                            borderRadius: 8,
                            border: '1px solid rgba(255,255,255,0.12)',
                            background: 'rgba(255,255,255,0.05)',
                            color: '#fca5a5',
                            fontSize: 11,
                            cursor: 'pointer',
                          }}
                        >
                          Limpar
                        </button>
                      </div>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                        {filteredClipboard.slice(0, 6).map((item) => {
                          const urlClean =
                            item.kind === 'url' ? cleanUrl(item.text) : null;
                          return (
                            <div
                              key={item.id}
                              style={{
                                padding: '6px 10px',
                                borderRadius: 9,
                                border: '1px solid rgba(255,255,255,0.08)',
                                background: 'rgba(255,255,255,0.04)',
                                display: 'flex',
                                alignItems: 'center',
                                gap: 8,
                              }}
                            >
                              {item.kind === 'color' && (
                                <span
                                  style={{
                                    width: 14,
                                    height: 14,
                                    borderRadius: 4,
                                    background: item.text.trim(),
                                    border: '1px solid rgba(255,255,255,0.3)',
                                  }}
                                />
                              )}
                              <span
                                onClick={() => {
                                  void copyToClipboard(item.text);
                                  toast('Copiado');
                                }}
                                style={{
                                  flex: 1,
                                  fontSize: 11.5,
                                  overflow: 'hidden',
                                  textOverflow: 'ellipsis',
                                  whiteSpace: 'nowrap',
                                  cursor: 'pointer',
                                }}
                              >
                                {item.text}
                              </span>
                              {urlClean?.valid && urlClean.removedCount > 0 && (
                                <button
                                  title="Copiar URL limpa"
                                  onClick={() => {
                                    void copyToClipboard(urlClean.cleaned);
                                    toast(`URL limpa (-${urlClean.removedCount} trackers)`);
                                  }}
                                  style={{
                                    padding: '2px 7px',
                                    borderRadius: 6,
                                    border: 'none',
                                    background: 'rgba(52,211,153,0.18)',
                                    color: '#34d399',
                                    fontSize: 10.5,
                                    cursor: 'pointer',
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: 3,
                                  }}
                                >
                                  <Link2 size={10} /> Limpar
                                </button>
                              )}
                              <button
                                onClick={() => togglePinClipboard(item.id)}
                                style={{
                                  border: 'none',
                                  background: 'transparent',
                                  color: item.pinned ? '#fbbf24' : 'rgba(255,255,255,0.45)',
                                  cursor: 'pointer',
                                }}
                              >
                                <Pin size={12} />
                              </button>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}

                  {/* 6. PER-APP MIXER */}
                  {activeModule === 'mixer' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: 12, fontWeight: 600 }}>
                          CoreAudio Mixer do Windows ({audioSessions.length} apps ativos)
                        </span>
                        <button
                          onClick={() => void refreshMixer()}
                          style={{
                            border: 'none',
                            background: 'rgba(255,255,255,0.08)',
                            color: '#fff',
                            borderRadius: 7,
                            padding: '4px 8px',
                            fontSize: 11,
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: 4,
                          }}
                        >
                          <RefreshCw size={11} /> Atualizar
                        </button>
                      </div>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                        {audioSessions.length === 0 ? (
                          <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.55)' }}>
                            Nenhum app reproduzindo áudio no momento.
                          </div>
                        ) : (
                          audioSessions.map((sess) => (
                            <div
                              key={sess.id}
                              style={{
                                padding: '8px 10px',
                                borderRadius: 10,
                                background: 'rgba(255,255,255,0.04)',
                                border: '1px solid rgba(255,255,255,0.08)',
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 6,
                              }}
                            >
                              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11.5 }}>
                                <span style={{ fontWeight: 600 }}>{sess.name}</span>
                                <span>{sess.muted ? 'Mudo' : `${sess.volume}%`}</span>
                              </div>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                <button
                                  onClick={() => {
                                    const m = !sess.muted;
                                    setAudioSessions((prev) =>
                                      prev.map((a) => (a.pid === sess.pid ? { ...a, muted: m } : a))
                                    );
                                    void setAppAudio(sess.pid, undefined, m);
                                  }}
                                  style={{
                                    border: 'none',
                                    background: 'transparent',
                                    color: sess.muted ? '#f87171' : '#fff',
                                    cursor: 'pointer',
                                  }}
                                >
                                  {sess.muted ? <VolumeX size={13} /> : <Volume2 size={13} />}
                                </button>
                                <input
                                  type="range"
                                  min={0}
                                  max={100}
                                  value={sess.volume}
                                  onChange={(e) => {
                                    const v = Number(e.target.value);
                                    setAudioSessions((prev) =>
                                      prev.map((a) =>
                                        a.pid === sess.pid ? { ...a, volume: v, muted: false } : a
                                      )
                                    );
                                    void setAppAudio(sess.pid, v, false);
                                  }}
                                  style={{ flex: 1, accentColor: accent }}
                                />
                              </div>
                            </div>
                          ))
                        )}
                      </div>
                    </div>
                  )}

                  {/* 7. SCRATCHPAD */}
                  {activeModule === 'scratchpad' && (
                    <div style={{ display: 'grid', gridTemplateColumns: '175px 1fr', gap: 10, height: '100%' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                        <button
                          onClick={() => {
                            const id = `n-${Date.now()}`;
                            const next = [
                              { id, title: 'Nova Nota', body: '', updatedAt: Date.now() },
                              ...notes,
                            ];
                            saveNotes(next);
                            setActiveNoteId(id);
                          }}
                          style={{
                            padding: '6px 10px',
                            borderRadius: 8,
                            border: 'none',
                            background: accent,
                            color: '#06121a',
                            fontWeight: 700,
                            fontSize: 11.5,
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: 5,
                          }}
                        >
                          <Plus size={13} /> Nova Nota
                        </button>
                        {notes.map((n) => (
                          <button
                            key={n.id}
                            onClick={() => setActiveNoteId(n.id)}
                            style={{
                              padding: '7px 9px',
                              borderRadius: 8,
                              border: '1px solid rgba(255,255,255,0.08)',
                              background:
                                currentNote?.id === n.id
                                  ? 'rgba(255,255,255,0.12)'
                                  : 'rgba(255,255,255,0.03)',
                              color: '#fff',
                              textAlign: 'left',
                              fontSize: 11.5,
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                              whiteSpace: 'nowrap',
                              cursor: 'pointer',
                            }}
                          >
                            {n.title || 'Sem título'}
                          </button>
                        ))}
                      </div>

                      {currentNote && (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                          <div style={{ display: 'flex', gap: 6 }}>
                            <input
                              className="v-input"
                              value={currentNote.title}
                              onFocus={requestInputFocus}
                              onChange={(e) => {
                                const title = e.target.value;
                                saveNotes(
                                  notes.map((n) =>
                                    n.id === currentNote.id
                                      ? { ...n, title, updatedAt: Date.now() }
                                      : n
                                  )
                                );
                              }}
                              style={{
                                padding: '5px 9px',
                                fontSize: 12,
                                fontWeight: 600,
                                background: 'rgba(255,255,255,0.06)',
                                color: '#fff',
                                borderColor: 'rgba(255,255,255,0.12)',
                              }}
                            />
                            <button
                              onClick={() => {
                                void copyToClipboard(currentNote.body);
                                toast('Nota copiada');
                              }}
                              style={{
                                padding: '0 10px',
                                borderRadius: 8,
                                border: '1px solid rgba(255,255,255,0.12)',
                                background: 'rgba(255,255,255,0.06)',
                                color: '#fff',
                                cursor: 'pointer',
                              }}
                            >
                              <Copy size={12} />
                            </button>
                          </div>
                          <textarea
                            value={currentNote.body}
                            onFocus={requestInputFocus}
                            onChange={(e) => {
                              const body = e.target.value;
                              saveNotes(
                                notes.map((n) =>
                                  n.id === currentNote.id
                                    ? { ...n, body, updatedAt: Date.now() }
                                    : n
                                )
                              );
                            }}
                            style={{
                              flex: 1,
                              minHeight: 190,
                              borderRadius: 10,
                              border: '1px solid rgba(255,255,255,0.12)',
                              background: 'rgba(255,255,255,0.04)',
                              color: '#f1f5f9',
                              padding: 9,
                              fontSize: 12,
                              resize: 'none',
                              outline: 'none',
                              fontFamily: 'inherit',
                            }}
                          />
                        </div>
                      )}
                    </div>
                  )}

                  {/* 8. CALENDAR */}
                  {activeModule === 'calendar' && (
                    <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 14 }}>
                      <div>
                        <div
                          style={{
                            fontSize: 13,
                            fontWeight: 700,
                            textTransform: 'capitalize',
                            marginBottom: 8,
                          }}
                        >
                          {calendarGrid.monthLabel}
                        </div>
                        <div
                          style={{
                            display: 'grid',
                            gridTemplateColumns: 'repeat(7, 1fr)',
                            gap: 4,
                            textAlign: 'center',
                            fontSize: 11,
                          }}
                        >
                          {['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((d, i) => (
                            <span key={i} style={{ color: 'rgba(255,255,255,0.45)', fontWeight: 700 }}>
                              {d}
                            </span>
                          ))}
                          {calendarGrid.cells.map((day, idx) => (
                            <span
                              key={idx}
                              style={{
                                padding: '4px 0',
                                borderRadius: 7,
                                background:
                                  day === calendarGrid.today
                                    ? accent
                                    : day
                                    ? 'rgba(255,255,255,0.03)'
                                    : 'transparent',
                                color: day === calendarGrid.today ? '#06121a' : '#fff',
                                fontWeight: day === calendarGrid.today ? 800 : 500,
                              }}
                            >
                              {day ?? ''}
                            </span>
                          ))}
                        </div>
                      </div>
                      <div
                        style={{
                          padding: 12,
                          borderRadius: 12,
                          background: 'rgba(255,255,255,0.04)',
                          border: '1px solid rgba(255,255,255,0.08)',
                          display: 'flex',
                          flexDirection: 'column',
                          justifyContent: 'space-between',
                        }}
                      >
                        <div>
                          <div style={{ fontSize: 26, fontWeight: 700 }}>
                            {new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                          </div>
                          <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)', marginTop: 4 }}>
                            Uptime: {Math.floor((telemetry?.uptimeSeconds ?? 0) / 3600)}h{' '}
                            {Math.floor(((telemetry?.uptimeSeconds ?? 0) % 3600) / 60)}m
                          </div>
                        </div>
                        <button
                          onClick={() => void openExternalUrl('https://calendar.google.com')}
                          style={{
                            padding: '8px 12px',
                            borderRadius: 9,
                            border: '1px solid rgba(255,255,255,0.12)',
                            background: 'rgba(255,255,255,0.06)',
                            color: '#fff',
                            fontSize: 11.5,
                            fontWeight: 600,
                            cursor: 'pointer',
                          }}
                        >
                          Abrir Agenda Online
                        </button>
                      </div>
                    </div>
                  )}

                  {/* 9. SYSTEM */}
                  {activeModule === 'system' && (
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                      <div
                        style={{
                          padding: 10,
                          borderRadius: 12,
                          background: 'rgba(255,255,255,0.04)',
                          border: '1px solid rgba(255,255,255,0.08)',
                          display: 'flex',
                          flexDirection: 'column',
                          gap: 8,
                        }}
                      >
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, fontWeight: 600 }}>
                          <span>CPU Total</span>
                          <span>{Math.round(telemetry?.cpuPercent ?? 0)}%</span>
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 4, height: 34, alignItems: 'end' }}>
                          {(telemetry?.cpuCores ?? []).slice(0, 16).map((c, idx) => (
                            <div
                              key={idx}
                              title={`Core ${idx}: ${Math.round(c)}%`}
                              style={{
                                height: `${Math.max(12, Math.min(100, c))}%`,
                                background: c > 80 ? '#f87171' : accent,
                                borderRadius: 3,
                              }}
                            />
                          ))}
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11.5, color: 'rgba(255,255,255,0.7)' }}>
                          <span>RAM: {(telemetry?.memoryUsedGb ?? 0).toFixed(1)} GB</span>
                          <span>GPU: {Math.round(telemetry?.gpuPercent ?? 0)}%</span>
                          <span>Temp: {telemetry?.cpuTempC ? `${telemetry.cpuTempC.toFixed(0)}°C` : 'N/A'}</span>
                        </div>
                      </div>

                      <div
                        style={{
                          padding: 10,
                          borderRadius: 12,
                          background: 'rgba(255,255,255,0.04)',
                          border: '1px solid rgba(255,255,255,0.08)',
                          display: 'flex',
                          flexDirection: 'column',
                          gap: 6,
                        }}
                      >
                        <div style={{ fontSize: 12, fontWeight: 600 }}>Processos em destaque</div>
                        {(telemetry?.topProcesses ?? []).slice(0, 4).map((p) => (
                          <div
                            key={p.pid}
                            style={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              fontSize: 11.5,
                              color: 'rgba(255,255,255,0.8)',
                            }}
                          >
                            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 160 }}>
                              {p.name}
                            </span>
                            <span>
                              {p.cpuPercent.toFixed(1)}% · {p.memoryMb} MB
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* 10. CAMERA MIRROR */}
                  {activeModule === 'camera' && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 14, height: '100%' }}>
                      <div
                        style={{
                          width: 340,
                          height: 220,
                          borderRadius: 14,
                          overflow: 'hidden',
                          background: '#05070b',
                          border: '1px solid rgba(255,255,255,0.12)',
                          display: 'grid',
                          placeItems: 'center',
                        }}
                      >
                        {cameraError ? (
                          <div style={{ padding: 14, textAlign: 'center', fontSize: 12, color: '#94a3b8' }}>
                            {cameraError}
                          </div>
                        ) : (
                          <video
                            ref={videoRef}
                            autoPlay
                            playsInline
                            muted
                            style={{
                              width: '100%',
                              height: '100%',
                              objectFit: 'cover',
                              transform: cameraMirrored ? 'scaleX(-1)' : undefined,
                            }}
                          />
                        )}
                      </div>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                        <div style={{ fontSize: 13, fontWeight: 700 }}>Espelho Rápido de Webcam</div>
                        <div style={{ fontSize: 11.5, color: 'rgba(255,255,255,0.6)', maxWidth: 220 }}>
                          Verifique enquadramento e iluminação antes de entrar em reuniões no Teams, Meet ou Zoom.
                        </div>
                        <button
                          onClick={() => setCameraMirrored((m) => !m)}
                          style={{
                            padding: '8px 12px',
                            borderRadius: 9,
                            border: '1px solid rgba(255,255,255,0.14)',
                            background: 'rgba(255,255,255,0.06)',
                            color: '#fff',
                            fontSize: 12,
                            cursor: 'pointer',
                          }}
                        >
                          Inverter Espelho: {cameraMirrored ? 'Ativo' : 'Normal'}
                        </button>
                      </div>
                    </div>
                  )}

                  {/* 11. AI AGENTS WATCHDOG */}
                  {activeModule === 'agents' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: 12.5, fontWeight: 700 }}>
                          Watchdog de Agentes de Código (Claude / Codex / Gemini)
                        </span>
                        <button
                          onClick={() => void openOverlay('command')}
                          style={{
                            padding: '5px 10px',
                            borderRadius: 8,
                            border: 'none',
                            background: accent,
                            color: '#06121a',
                            fontSize: 11,
                            fontWeight: 700,
                            cursor: 'pointer',
                          }}
                        >
                          Command Bar
                        </button>
                      </div>
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                        {agents.map((ag) => (
                          <div
                            key={ag.id}
                            style={{
                              padding: 10,
                              borderRadius: 11,
                              background: 'rgba(255,255,255,0.04)',
                              border: '1px solid rgba(255,255,255,0.09)',
                              display: 'flex',
                              flexDirection: 'column',
                              gap: 6,
                            }}
                          >
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                              <span style={{ fontSize: 12, fontWeight: 700 }}>{ag.name}</span>
                              <span
                                style={{
                                  fontSize: 10,
                                  fontWeight: 700,
                                  padding: '2px 7px',
                                  borderRadius: 999,
                                  background:
                                    ag.status === 'running'
                                      ? 'rgba(56,189,248,0.2)'
                                      : ag.status === 'done'
                                      ? 'rgba(52,211,153,0.2)'
                                      : 'rgba(251,191,36,0.2)',
                                  color:
                                    ag.status === 'running'
                                      ? '#38bdf8'
                                      : ag.status === 'done'
                                      ? '#34d399'
                                      : '#fbbf24',
                                }}
                              >
                                {ag.status}
                              </span>
                            </div>
                            <div style={{ fontSize: 11.5, color: 'rgba(255,255,255,0.72)' }}>
                              {ag.task}
                            </div>
                            <div style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.45)' }}>
                              {ag.provider} · {ag.elapsedSec}s
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>

            {/* FOOTER QUICK ACTIONS BAR */}
            <div
              style={{
                height: 30,
                padding: '0 12px',
                borderTop: '1px solid rgba(255,255,255,0.07)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                fontSize: 11,
                color: 'rgba(255,255,255,0.55)',
              }}
            >
              <span>
                Janela ativa: {telemetry?.activeWindowTitle?.slice(0, 38) || 'Desktop'}
              </span>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <button
                  onClick={() => {
                    setShowGallery(false);
                    setActiveModule('calendar');
                  }}
                  style={{ border: 'none', background: 'transparent', color: 'inherit', cursor: 'pointer', fontSize: 11 }}
                >
                  Agenda
                </button>
                <button
                  onClick={() => {
                    setShowGallery(false);
                    setActiveModule('system');
                  }}
                  style={{ border: 'none', background: 'transparent', color: 'inherit', cursor: 'pointer', fontSize: 11 }}
                >
                  Sistema
                </button>
                <button
                  onClick={() => {
                    setShowGallery(false);
                    setActiveModule('camera');
                  }}
                  style={{ border: 'none', background: 'transparent', color: 'inherit', cursor: 'pointer', fontSize: 11 }}
                >
                  Webcam
                </button>
                <button
                  onClick={() => {
                    setShowGallery(false);
                    setActiveModule('agents');
                  }}
                  style={{ border: 'none', background: 'transparent', color: 'inherit', cursor: 'pointer', fontSize: 11 }}
                >
                  Agentes
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

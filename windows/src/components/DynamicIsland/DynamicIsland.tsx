import React, { useEffect, useState } from 'react';
import {
  AudioLines,
  Bell,
  Bot,
  Calendar,
  Camera,
  ChevronDown,
  ChevronUp,
  FolderDown,
  Pause,
  Play,
  SkipBack,
  SkipForward,
  Smile,
  Timer,
} from 'lucide-react';
import type { DynamicIslandAgent, ShelfItem } from '../../types/vorssaint';

type IslandTab = 'music' | 'agents' | 'timer' | 'calendar' | 'downloads' | 'camera' | 'notifications';

interface DynamicIslandProps {
  enabled: boolean;
  agents: DynamicIslandAgent[];
  shelfItems: ShelfItem[];
  showLyrics: boolean;
  showEqualizer: boolean;
  showMascot: boolean;
  onOpenOverlay: (id: 'fileShelf') => void;
}

export function DynamicIsland({
  enabled,
  agents,
  shelfItems,
  showLyrics,
  showEqualizer,
  showMascot,
  onOpenOverlay,
}: DynamicIslandProps) {
  const [expanded, setExpanded] = useState(false);
  const [activeTab, setActiveTab] = useState<IslandTab>('music');
  const [playing, setPlaying] = useState(true);
  const [timerRunning, setTimerRunning] = useState(true);
  const [timerSeconds, setTimerSeconds] = useState(1495);

  useEffect(() => {
    if (!timerRunning) return;
    const t = window.setInterval(() => {
      setTimerSeconds((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => window.clearInterval(t);
  }, [timerRunning]);

  if (!enabled) return null;

  const mins = String(Math.floor(timerSeconds / 60)).padStart(2, '0');
  const secs = String(timerSeconds % 60).padStart(2, '0');
  const activeAgentCount = agents.filter((a) => a.state === 'active').length;

  return (
    <div className="island-anchor">
      <div
        className="island-pill"
        style={{
          width: expanded ? 488 : 268,
          padding: expanded ? '10px 14px 12px' : '6px 12px',
          borderRadius: expanded ? 20 : 999,
        }}
      >
        {/* Compact Pill Bar */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 10,
            cursor: 'pointer',
          }}
          onClick={() => setExpanded((e) => !e)}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, minWidth: 0 }}>
            <span
              style={{
                width: 18,
                height: 18,
                borderRadius: 6,
                background: 'rgba(10, 132, 255, 0.25)',
                color: '#60a5fa',
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              {showEqualizer && playing ? <AudioLines size={11} /> : <Bot size={11} />}
            </span>
            <span style={{ fontSize: 11.5, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {activeAgentCount > 0 ? `${activeAgentCount} AI Agents` : 'Midnight Telemetry'}
            </span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="tabular" style={{ fontSize: 11, color: '#30d158', fontWeight: 600 }}>
              {mins}:{secs}
            </span>
            {showMascot && <Smile size={13} style={{ color: '#facc15' }} />}
            {expanded ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
          </div>
        </div>

        {/* Expanded Interactive View */}
        {expanded && (
          <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
              {(
                [
                  ['music', 'Now Playing', AudioLines],
                  ['agents', 'AI Agents', Bot],
                  ['timer', 'Timer', Timer],
                  ['calendar', 'Agenda', Calendar],
                  ['downloads', 'Shelf', FolderDown],
                  ['camera', 'Mirror', Camera],
                  ['notifications', 'Alerts', Bell],
                ] as const
              ).map(([id, label, Icon]) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => setActiveTab(id)}
                  style={{
                    height: 24,
                    padding: '0 8px',
                    borderRadius: 8,
                    border: 'none',
                    cursor: 'pointer',
                    fontSize: 11,
                    fontWeight: 600,
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 4,
                    background: activeTab === id ? '#0a84ff' : 'rgba(255,255,255,0.08)',
                    color: '#fff',
                  }}
                >
                  <Icon size={11} />
                  {label}
                </button>
              ))}
            </div>

            {activeTab === 'music' && (
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 12.5, fontWeight: 600 }}>Vorssaint Lo-Fi Studio</div>
                  <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.65)' }}>
                    {showLyrics ? '♪ "Native frames at 120Hz in silent orbit"' : 'Spotify Desktop · Sony WH'}
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <button type="button" className="btn" style={{ width: 28, padding: 0 }} onClick={() => setPlaying(true)}>
                    <SkipBack size={13} />
                  </button>
                  <button
                    type="button"
                    className="btn btn-primary"
                    style={{ width: 32, padding: 0 }}
                    onClick={() => setPlaying((p) => !p)}
                  >
                    {playing ? <Pause size={13} /> : <Play size={13} />}
                  </button>
                  <button type="button" className="btn" style={{ width: 28, padding: 0 }} onClick={() => setPlaying(true)}>
                    <SkipForward size={13} />
                  </button>
                </div>
              </div>
            )}

            {activeTab === 'agents' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {agents.map((ag) => (
                  <div
                    key={ag.id}
                    style={{
                      background: 'rgba(255,255,255,0.06)',
                      borderRadius: 10,
                      padding: '6px 9px',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 12, fontWeight: 600 }}>
                        {ag.name} <span style={{ fontSize: 10.5, opacity: 0.65 }}>({ag.model})</span>
                      </div>
                      <div style={{ fontSize: 10.5, opacity: 0.72 }}>{ag.taskSummary}</div>
                    </div>
                    <div className="tabular" style={{ textAlign: 'right', fontSize: 10.5 }}>
                      <div style={{ color: ag.state === 'active' ? '#30d158' : '#a1a6b0', fontWeight: 600 }}>
                        {ag.state === 'active' ? '● Running' : 'Idle'}
                      </div>
                      <div>{(ag.tokensUsed / 1000).toFixed(1)}k tok</div>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {activeTab === 'timer' && (
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div className="tabular" style={{ fontSize: 22, fontWeight: 700 }}>
                    {mins}:{secs}
                  </div>
                  <div style={{ fontSize: 10.5, opacity: 0.65 }}>Focus Sprint Timer</div>
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  {[5, 15, 25].map((m) => (
                    <button
                      key={m}
                      type="button"
                      className="btn"
                      onClick={() => {
                        setTimerSeconds(m * 60);
                        setTimerRunning(true);
                      }}
                    >
                      {m}m
                    </button>
                  ))}
                  <button
                    type="button"
                    className="btn btn-primary"
                    onClick={() => setTimerRunning((r) => !r)}
                  >
                    {timerRunning ? 'Pause' : 'Start'}
                  </button>
                </div>
              </div>
            )}

            {activeTab === 'calendar' && (
              <div style={{ fontSize: 11.5, display: 'flex', justifyContent: 'space-between' }}>
                <div>
                  <div style={{ fontWeight: 600 }}>Windows Beta Release Triage</div>
                  <div style={{ opacity: 0.68 }}>10:30 – 11:00 · Teams / Calendar Sync</div>
                </div>
                <span className="tag-badge green">In 18m</span>
              </div>
            )}

            {activeTab === 'downloads' && (
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ fontSize: 11.5 }}>
                  <strong>{shelfItems.length} pinned files</strong> ready in floating shelf
                </div>
                <button type="button" className="btn btn-primary" onClick={() => onOpenOverlay('fileShelf')}>
                  Open Shelf
                </button>
              </div>
            )}

            {activeTab === 'camera' && (
              <div
                style={{
                  height: 74,
                  borderRadius: 10,
                  background: 'radial-gradient(circle at 50% 45%, #1c2432, #0d1016)',
                  border: '1px solid rgba(255,255,255,0.1)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                  fontSize: 11.5,
                  color: 'rgba(255,255,255,0.75)',
                }}
              >
                <Camera size={16} />
                Webcam Framing Preview · Studio Lighting OK
              </div>
            )}

            {activeTab === 'notifications' && (
              <div style={{ fontSize: 11.5, opacity: 0.85 }}>
                GitHub Actions sync verified · Win32 SetThreadExecutionState standby.
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

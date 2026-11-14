import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Camera,
  Check,
  CircleDot,
  Clipboard,
  Copy,
  Disc,
  FilePlus2,
  Inbox,
  Keyboard,
  LockOpen,
  Monitor,
  Pipette,
  ScanText,
  Search,
  StickyNote,
  Terminal,
  Trash2,
  Video,
  X,
} from 'lucide-react';
import type {
  ClipboardItem,
  OpenWindowEntry,
  OverlayId,
  ScratchpadNote,
  ShelfItem,
  TextSnippet,
} from '../../types/vorssaint';
import { APP_VERSION } from '../../data/catalog';
import { BrandMark, Switch } from '../BrandMark';

interface OverlaysProps {
  activeOverlay: OverlayId | null;
  openWindows: OpenWindowEntry[];
  clipboard: ClipboardItem[];
  snippets: TextSnippet[];
  shelfItems: ShelfItem[];
  notes: ScratchpadNote[];
  keepAwake: boolean;
  onClose: () => void;
  onFocusWindow: (hwnd: number) => void;
  onOpenOverlay: (id: OverlayId) => void;
  onToggleKeepAwake: () => void;
  onCopyText: (text: string) => void;
  onAddShelfItem: (item: ShelfItem) => void;
  onRemoveShelfItem: (id: string) => void;
  onSaveNotes: (notes: ScratchpadNote[]) => void;
  onSnapWindow: (layout: string) => void;
  onToast: (msg: string) => void;
}

// Safe recursive-descent arithmetic evaluator (no eval / Function)
function evaluateMathExpression(raw: string): number | null {
  const cleaned = raw.trim().replace(/^=/, '').replace(/\s+/g, '');
  if (!cleaned || !/^[0-9+\-*/().]+$/.test(cleaned)) return null;
  let pos = 0;

  function peek(): string {
    return cleaned[pos] ?? '';
  }

  function parseNumber(): number | null {
    const start = pos;
    if (peek() === '-') pos++;
    let hasDigit = false;
    while (/[0-9.]/.test(peek())) {
      hasDigit = true;
      pos++;
    }
    if (!hasDigit) return null;
    const val = Number(cleaned.slice(start, pos));
    return Number.isFinite(val) ? val : null;
  }

  function parseFactor(): number | null {
    if (peek() === '(') {
      pos++;
      const inner = parseExpr();
      if (inner === null || peek() !== ')') return null;
      pos++;
      return inner;
    }
    if (peek() === '+') {
      pos++;
      return parseFactor();
    }
    if (peek() === '-') {
      pos++;
      const f = parseFactor();
      return f === null ? null : -f;
    }
    return parseNumber();
  }

  function parseTerm(): number | null {
    let left = parseFactor();
    if (left === null) return null;
    while (peek() === '*' || peek() === '/') {
      const op = cleaned[pos++];
      const right = parseFactor();
      if (right === null) return null;
      if (op === '*') left *= right;
      else {
        if (right === 0) return null;
        left /= right;
      }
    }
    return left;
  }

  function parseExpr(): number | null {
    let left = parseTerm();
    if (left === null) return null;
    while (peek() === '+' || peek() === '-') {
      const op = cleaned[pos++];
      const right = parseTerm();
      if (right === null) return null;
      left = op === '+' ? left + right : left - right;
    }
    return left;
  }

  const out = parseExpr();
  return out !== null && pos === cleaned.length ? out : null;
}

function tryUnitConversion(raw: string): string | null {
  const m = raw
    .trim()
    .toLowerCase()
    .match(/^(-?\d+(?:\.\d+)?)\s*(c|f|km|mi|kg|lb|px|rem|gb|mb)\s+(?:to|in)\s+(c|f|km|mi|kg|lb|px|rem|gb|mb)$/);
  if (!m) return null;
  const val = Number(m[1]);
  const from = m[2];
  const to = m[3];
  if (from === 'c' && to === 'f') return `${((val * 9) / 5 + 32).toFixed(2)} °F`;
  if (from === 'f' && to === 'c') return `${(((val - 32) * 5) / 9).toFixed(2)} °C`;
  if (from === 'km' && to === 'mi') return `${(val * 0.621371).toFixed(3)} mi`;
  if (from === 'mi' && to === 'km') return `${(val / 0.621371).toFixed(3)} km`;
  if (from === 'kg' && to === 'lb') return `${(val * 2.20462).toFixed(2)} lb`;
  if (from === 'lb' && to === 'kg') return `${(val / 2.20462).toFixed(2)} kg`;
  if (from === 'px' && to === 'rem') return `${(val / 16).toFixed(3)} rem (base 16px)`;
  if (from === 'rem' && to === 'px') return `${(val * 16).toFixed(1)} px`;
  if (from === 'gb' && to === 'mb') return `${(val * 1024).toFixed(0)} MB`;
  if (from === 'mb' && to === 'gb') return `${(val / 1024).toFixed(3)} GB`;
  return null;
}

export function Overlays(props: OverlaysProps) {
  const { activeOverlay, onClose } = props;
  const [query, setQuery] = useState('');
  const [activeNoteId, setActiveNoteId] = useState(props.notes[0]?.id ?? 'n1');
  const [markdownPreview, setMarkdownPreview] = useState(false);

  // Capture Studio state
  const [captureTab, setCaptureTab] = useState<'screenshot' | 'ocr' | 'picker' | 'recorder'>('screenshot');
  const [pickedColor, setPickedColor] = useState('#0A84FF');
  const [ocrSample, setOcrSample] = useState(
    'Vorssaint Utils v3.7.8 — Windows Native Engine (Win32 + Tauri v2 + Rust)'
  );
  const [isRecording, setIsRecording] = useState(false);
  const [recordFormat, setRecordFormat] = useState<'MP4' | 'GIF'>('MP4');
  const [highlightClicks, setHighlightClicks] = useState(true);
  const [showKeystrokes, setShowKeystrokes] = useState(true);
  const [recordSecs, setRecordSecs] = useState(0);

  // Cleaning Mode hold-to-unlock
  const [unlockProgress, setUnlockProgress] = useState(0);
  const holdIntervalRef = useRef<number | null>(null);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && activeOverlay && activeOverlay !== 'cleaningMode') {
        onClose();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [activeOverlay, onClose]);

  useEffect(() => {
    if (!isRecording) return;
    const t = window.setInterval(() => setRecordSecs((s) => s + 1), 1000);
    return () => window.clearInterval(t);
  }, [isRecording]);

  const mathResult = useMemo(() => evaluateMathExpression(query), [query]);
  const unitResult = useMemo(() => tryUnitConversion(query), [query]);

  if (!activeOverlay) return null;

  const startUnlockHold = () => {
    if (holdIntervalRef.current) window.clearInterval(holdIntervalRef.current);
    holdIntervalRef.current = window.setInterval(() => {
      setUnlockProgress((prev) => {
        if (prev + 10 >= 100) {
          if (holdIntervalRef.current) window.clearInterval(holdIntervalRef.current);
          holdIntervalRef.current = null;
          setUnlockProgress(0);
          onClose();
          props.onToast('Keyboard unlocked');
          return 0;
        }
        return prev + 10;
      });
    }, 90);
  };

  const stopUnlockHold = () => {
    if (holdIntervalRef.current) {
      window.clearInterval(holdIntervalRef.current);
      holdIntervalRef.current = null;
    }
    setUnlockProgress(0);
  };

  const hexToRgb = (hex: string) => {
    const clean = hex.replace('#', '');
    const num = parseInt(clean.length === 6 ? clean : '0a84ff', 16);
    const r = (num >> 16) & 255;
    const g = (num >> 8) & 255;
    const b = num & 255;
    return `rgb(${r}, ${g}, ${b})`;
  };

  const activeNote = props.notes.find((n) => n.id === activeNoteId) ?? props.notes[0];

  return (
    <div className="overlay-backdrop" onClick={() => activeOverlay !== 'cleaningMode' && onClose()}>
      {/* 1. COMMAND BAR */}
      {activeOverlay === 'commandBar' && (
        <div
          className="overlay-card"
          style={{ width: 620 }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ padding: '12px 14px', borderBottom: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', gap: 10 }}>
            <Search size={16} style={{ color: 'var(--accent-blue)' }} />
            <input
              autoFocus
              className="input-field"
              style={{ border: 'none', background: 'transparent', fontSize: 14, padding: 0 }}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search open windows, quick actions, math (e.g. 1280/16), or units (24C to F)..."
            />
            <span className="tag-badge">ESC</span>
          </div>
          <div style={{ maxHeight: 390, overflowY: 'auto', padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
            {mathResult !== null && (
              <div
                className="panel-card panel-card-clickable"
                style={{ borderColor: 'var(--accent-blue)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                onClick={() => props.onCopyText(String(mathResult))}
              >
                <div>
                  <div style={{ fontSize: 11, color: 'var(--accent-blue)', fontWeight: 700 }}>CALCULATOR</div>
                  <div className="tabular" style={{ fontSize: 20, fontWeight: 700 }}>= {mathResult}</div>
                </div>
                <span className="btn btn-primary">Copy Result</span>
              </div>
            )}

            {unitResult && (
              <div
                className="panel-card panel-card-clickable"
                style={{ borderColor: 'var(--accent-green)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                onClick={() => props.onCopyText(unitResult)}
              >
                <div>
                  <div style={{ fontSize: 11, color: 'var(--accent-green)', fontWeight: 700 }}>UNIT CONVERTER</div>
                  <div className="tabular" style={{ fontSize: 18, fontWeight: 700 }}>{unitResult}</div>
                </div>
                <span className="btn btn-primary">Copy</span>
              </div>
            )}

            <div style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--text-muted)', letterSpacing: '0.07em' }}>
              QUICK ACTIONS
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 6 }}>
              {[
                { label: 'Toggle Keep Awake', action: () => { props.onToggleKeepAwake(); onClose(); } },
                { label: 'Snap Active Window Left 1/2', action: () => { props.onSnapWindow('left'); onClose(); } },
                { label: 'Open Screen Capture & OCR', action: () => props.onOpenOverlay('screenCapture') },
                { label: 'Lock Keyboard (Cleaning)', action: () => props.onOpenOverlay('cleaningMode') },
                { label: 'Open Floating File Shelf', action: () => props.onOpenOverlay('fileShelf') },
                { label: 'Open Scratchpad', action: () => props.onOpenOverlay('scratchpad') },
              ]
                .filter((a) => !query || a.label.toLowerCase().includes(query.toLowerCase()))
                .map((a) => (
                  <button key={a.label} type="button" className="panel-card panel-card-clickable" style={{ textAlign: 'left', fontSize: 12, fontWeight: 500, color: 'var(--text-primary)' }} onClick={a.action}>
                    {a.label}
                  </button>
                ))}
            </div>

            <div style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--text-muted)', letterSpacing: '0.07em' }}>
              OPEN WINDOWS ({props.openWindows.length})
            </div>
            {props.openWindows
              .filter((w) => !query || `${w.title} ${w.processName}`.toLowerCase().includes(query.toLowerCase()))
              .slice(0, 8)
              .map((w) => (
                <div
                  key={w.hwnd}
                  className="panel-card panel-card-clickable"
                  style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                  onClick={() => {
                    props.onFocusWindow(w.hwnd);
                    onClose();
                  }}
                >
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: 12.5, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{w.title}</div>
                    <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>{w.processName} · PID {w.pid}</div>
                  </div>
                  <span className="tag-badge blue">Focus</span>
                </div>
              ))}

            {props.snippets.length > 0 && (
              <>
                <div style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--text-muted)', letterSpacing: '0.07em' }}>
                  TEXT SNIPPETS
                </div>
                {props.snippets
                  .filter((s) => !query || `${s.trigger} ${s.expansion}`.toLowerCase().includes(query.toLowerCase()))
                  .map((s) => (
                    <div
                      key={s.id}
                      className="panel-card panel-card-clickable"
                      style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                      onClick={() => {
                        props.onCopyText(s.expansion);
                        onClose();
                      }}
                    >
                      <div>
                        <span className="tag-badge blue" style={{ marginRight: 8 }}>{s.trigger}</span>
                        <span style={{ fontSize: 12 }}>{s.expansion}</span>
                      </div>
                      <Copy size={13} style={{ color: 'var(--text-muted)' }} />
                    </div>
                  ))}
              </>
            )}
          </div>
        </div>
      )}

      {/* 2. APP SWITCHER (ALT+TAB PREVIEW DECK) */}
      {activeOverlay === 'appSwitcher' && (
        <div className="overlay-card" style={{ width: 680, padding: 16 }} onClick={(e) => e.stopPropagation()}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Monitor size={16} style={{ color: 'var(--accent-blue)' }} />
              <strong style={{ fontSize: 14 }}>Vorssaint Window Switcher (Alt+Tab)</strong>
            </div>
            <button type="button" className="btn" onClick={onClose}>
              <X size={13} />
            </button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, maxHeight: 420, overflowY: 'auto' }}>
            {props.openWindows.map((win) => (
              <button
                key={win.hwnd}
                type="button"
                className="panel-card panel-card-clickable"
                style={{ textAlign: 'left', display: 'flex', flexDirection: 'column', gap: 8, color: 'var(--text-primary)' }}
                onClick={() => {
                  props.onFocusWindow(win.hwnd);
                  onClose();
                }}
              >
                <div
                  style={{
                    height: 62,
                    borderRadius: 8,
                    background: 'var(--surface-input)',
                    border: '1px solid var(--border-subtle)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'var(--accent-blue)',
                    fontSize: 11,
                    fontWeight: 600,
                  }}
                >
                  {win.processName}
                </div>
                <div style={{ fontSize: 12, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {win.title}
                </div>
                <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>PID {win.pid} · Click to raise</div>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* 3. RADIAL MENU */}
      {activeOverlay === 'radialMenu' && (
        <div
          className="overlay-card"
          style={{ width: 420, padding: 20, alignItems: 'center', gap: 14 }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ width: '100%', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <strong style={{ fontSize: 14, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
              <Disc size={16} style={{ color: 'var(--accent-blue)' }} /> Radial Quick Wheel
            </strong>
            <button type="button" className="btn" onClick={onClose}>
              <X size={13} />
            </button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, width: '100%' }}>
            {[
              { label: 'Command Bar', fn: () => props.onOpenOverlay('commandBar') },
              { label: 'Snap Left 1/2', fn: () => { props.onSnapWindow('left'); onClose(); } },
              { label: 'Capture / OCR', fn: () => props.onOpenOverlay('screenCapture') },
              { label: 'Keep Awake', fn: () => { props.onToggleKeepAwake(); onClose(); } },
              { label: 'Vorssaint Core', fn: onClose, center: true },
              { label: 'Snap Right 1/2', fn: () => { props.onSnapWindow('right'); onClose(); } },
              { label: 'File Shelf', fn: () => props.onOpenOverlay('fileShelf') },
              { label: 'Scratchpad', fn: () => props.onOpenOverlay('scratchpad') },
              { label: 'Clean Mode', fn: () => props.onOpenOverlay('cleaningMode') },
            ].map((cell) => (
              <button
                key={cell.label}
                type="button"
                className={cell.center ? 'btn btn-primary' : 'panel-card panel-card-clickable'}
                style={{
                  height: 76,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  textAlign: 'center',
                  fontSize: 12,
                  fontWeight: 600,
                  borderRadius: cell.center ? '50%' : 12,
                  color: cell.center ? '#fff' : 'var(--text-primary)',
                }}
                onClick={cell.fn}
              >
                {cell.label}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* 4. FLOATING FILE SHELF */}
      {activeOverlay === 'fileShelf' && (
        <div
          className="overlay-card"
          style={{ width: 520, padding: 16, gap: 12 }}
          onClick={(e) => e.stopPropagation()}
          onDragOver={(e) => e.preventDefault()}
          onDrop={(e) => {
            e.preventDefault();
            const dropped = Array.from(e.dataTransfer.files);
            if (dropped.length > 0) {
              dropped.forEach((f, idx) =>
                props.onAddShelfItem({
                  id: `sh-${Date.now()}-${idx}`,
                  name: f.name,
                  kind: f.type.startsWith('image') ? 'image' : 'file',
                  sizeLabel: `${Math.max(1, Math.round(f.size / 1024))} KB`,
                  addedAt: 'Just now',
                })
              );
              props.onToast(`Added ${dropped.length} file(s) to Shelf`);
            }
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <strong style={{ fontSize: 14, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
              <Inbox size={16} style={{ color: 'var(--accent-blue)' }} /> Floating File Shelf
            </strong>
            <div style={{ display: 'flex', gap: 6 }}>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() =>
                  props.onAddShelfItem({
                    id: `sh-${Date.now()}`,
                    name: `clip-bundle-${props.shelfItems.length + 1}.txt`,
                    kind: 'snippet',
                    sizeLabel: '2.1 KB',
                    addedAt: 'Just now',
                  })
                }
              >
                <FilePlus2 size={13} /> Pin Clipboard File
              </button>
              <button type="button" className="btn" onClick={onClose}>
                <X size={13} />
              </button>
            </div>
          </div>

          <div
            style={{
              border: '1.5px dashed var(--border-strong)',
              borderRadius: 12,
              padding: 16,
              textAlign: 'center',
              fontSize: 12,
              color: 'var(--text-secondary)',
            }}
          >
            Drag & drop files from Windows Explorer here to hold them while switching apps or virtual desktops.
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 260, overflowY: 'auto' }}>
            {props.shelfItems.map((item) => (
              <div key={item.id} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: 12.5, fontWeight: 600 }}>{item.name}</div>
                  <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                    {item.kind.toUpperCase()} · {item.sizeLabel} · {item.addedAt}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button type="button" className="btn" onClick={() => props.onCopyText(item.name)}>
                    Copy Path
                  </button>
                  <button type="button" className="btn btn-danger" onClick={() => props.onRemoveShelfItem(item.id)}>
                    <Trash2 size={12} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 5. SCRATCHPAD */}
      {activeOverlay === 'scratchpad' && (
        <div className="overlay-card" style={{ width: 640, height: 480 }} onClick={(e) => e.stopPropagation()}>
          <div className="window-titlebar">
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <StickyNote size={15} style={{ color: 'var(--accent-blue)' }} />
              <strong style={{ fontSize: 13 }}>Floating Markdown Scratchpad</strong>
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              <button type="button" className="btn" onClick={() => setMarkdownPreview((p) => !p)}>
                {markdownPreview ? 'Edit' : 'Preview'}
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => {
                  const nextId = `n-${Date.now()}`;
                  props.onSaveNotes([
                    ...props.notes,
                    { id: nextId, title: `Note ${props.notes.length + 1}`, content: '# New Note\n', updatedAt: 'Just now' },
                  ]);
                  setActiveNoteId(nextId);
                }}
              >
                + Tab
              </button>
              <button type="button" className="btn" onClick={onClose}>
                <X size={13} />
              </button>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 4, padding: '8px 12px', borderBottom: '1px solid var(--border-subtle)', overflowX: 'auto' }}>
            {props.notes.map((n) => (
              <button
                key={n.id}
                type="button"
                className={`btn ${activeNote?.id === n.id ? 'btn-primary' : ''}`}
                onClick={() => setActiveNoteId(n.id)}
              >
                {n.title}
              </button>
            ))}
          </div>

          {activeNote && (
            <div style={{ flex: 1, padding: 14, overflow: 'auto', userSelect: 'text' }}>
              {markdownPreview ? (
                <pre
                  style={{
                    margin: 0,
                    whiteSpace: 'pre-wrap',
                    fontFamily: 'Segoe UI Variable, Segoe UI, sans-serif',
                    fontSize: 13,
                    lineHeight: 1.55,
                  }}
                >
                  {activeNote.content}
                </pre>
              ) : (
                <textarea
                  value={activeNote.content}
                  onChange={(e) =>
                    props.onSaveNotes(
                      props.notes.map((item) =>
                        item.id === activeNote.id ? { ...item, content: e.target.value, updatedAt: 'Just now' } : item
                      )
                    )
                  }
                  style={{
                    width: '100%',
                    height: '100%',
                    resize: 'none',
                    background: 'var(--surface-input)',
                    color: 'var(--text-primary)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: 10,
                    padding: 12,
                    fontFamily: 'Consolas, monospace',
                    fontSize: 12.5,
                    outline: 'none',
                  }}
                />
              )}
            </div>
          )}
        </div>
      )}

      {/* 6. SCREEN CAPTURE, OCR, COLOR PICKER & RECORDER STUDIO */}
      {activeOverlay === 'screenCapture' && (
        <div className="overlay-card" style={{ width: 610, padding: 16, gap: 14 }} onClick={(e) => e.stopPropagation()}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <strong style={{ fontSize: 14, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
              <Camera size={16} style={{ color: 'var(--accent-blue)' }} /> Capture, OCR, Color Picker & Recorder
            </strong>
            <button type="button" className="btn" onClick={onClose}>
              <X size={13} />
            </button>
          </div>

          <div className="segmented">
            {(
              [
                ['screenshot', 'Screenshot'],
                ['ocr', 'Screen OCR'],
                ['picker', 'Color Picker'],
                ['recorder', 'MP4 / GIF Recorder'],
              ] as const
            ).map(([id, label]) => (
              <button
                key={id}
                type="button"
                className={`segmented-btn ${captureTab === id ? 'active' : ''}`}
                onClick={() => setCaptureTab(id)}
              >
                {label}
              </button>
            ))}
          </div>

          {captureTab === 'screenshot' && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
              {[
                'Area Capture (Save & Annotate)',
                'Active Window Capture',
                'Full Monitor Capture',
                'Scrolling Window Capture',
              ].map((mode) => (
                <button
                  key={mode}
                  type="button"
                  className="panel-card panel-card-clickable"
                  style={{ textAlign: 'left', color: 'var(--text-primary)' }}
                  onClick={() => props.onToast(`Captured via Windows Graphics Capture: ${mode}`)}
                >
                  <div style={{ fontSize: 12.5, fontWeight: 600 }}>{mode}</div>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>Copies PNG to Clipboard & Shelf</div>
                </button>
              ))}
            </div>
          )}

          {captureTab === 'ocr' && (
            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ fontSize: 12, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}>
                <ScanText size={14} style={{ color: 'var(--accent-blue)' }} /> Recognized Screen Text
              </div>
              <textarea
                rows={4}
                className="input-field"
                style={{ height: 'auto', padding: 10 }}
                value={ocrSample}
                onChange={(e) => setOcrSample(e.target.value)}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                <button type="button" className="btn btn-primary" onClick={() => props.onCopyText(ocrSample)}>
                  <Clipboard size={13} /> Copy Recognized Text
                </button>
              </div>
            </div>
          )}

          {captureTab === 'picker' && (
            <div className="panel-card" style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <input
                type="color"
                value={pickedColor}
                onChange={(e) => setPickedColor(e.target.value)}
                style={{ width: 64, height: 64, border: 'none', borderRadius: 12, background: 'transparent', cursor: 'pointer' }}
              />
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div style={{ fontSize: 12.5, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <Pipette size={14} style={{ color: 'var(--accent-blue)' }} /> Picked Pixel Format
                </div>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <button type="button" className="btn tabular" onClick={() => props.onCopyText(pickedColor.toUpperCase())}>
                    HEX: {pickedColor.toUpperCase()}
                  </button>
                  <button type="button" className="btn tabular" onClick={() => props.onCopyText(hexToRgb(pickedColor))}>
                    {hexToRgb(pickedColor)}
                  </button>
                </div>
              </div>
            </div>
          )}

          {captureTab === 'recorder' && (
            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Video size={15} style={{ color: isRecording ? 'var(--accent-red)' : 'var(--accent-blue)' }} />
                  <strong style={{ fontSize: 13 }}>
                    {isRecording ? `Recording (${recordSecs}s)` : 'Windows Screen Recorder (MP4 / cgif)'}
                  </strong>
                </div>
                <div className="segmented">
                  {(['MP4', 'GIF'] as const).map((fmt) => (
                    <button
                      key={fmt}
                      type="button"
                      className={`segmented-btn ${recordFormat === fmt ? 'active' : ''}`}
                      onClick={() => setRecordFormat(fmt)}
                    >
                      {fmt}
                    </button>
                  ))}
                </div>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: 12 }}>Show live keystrokes HUD</span>
                <Switch checked={showKeystrokes} onChange={setShowKeystrokes} />
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: 12 }}>Highlight mouse cursor clicks</span>
                <Switch checked={highlightClicks} onChange={setHighlightClicks} />
              </div>
              <button
                type="button"
                className={isRecording ? 'btn btn-danger' : 'btn btn-primary'}
                onClick={() => {
                  if (isRecording) {
                    setIsRecording(false);
                    props.onToast(`Saved ${recordFormat} capture (${recordSecs}s)`);
                    setRecordSecs(0);
                  } else {
                    setIsRecording(true);
                  }
                }}
              >
                <CircleDot size={14} />
                {isRecording ? 'Stop & Save Recording' : `Start ${recordFormat} Recording`}
              </button>
            </div>
          )}
        </div>
      )}

      {/* 7. KEYBOARD CLEANING MODE LOCK */}
      {activeOverlay === 'cleaningMode' && (
        <div
          className="overlay-card"
          style={{ width: 420, padding: 28, alignItems: 'center', textAlign: 'center', gap: 14 }}
        >
          <Keyboard size={34} style={{ color: 'var(--accent-blue)' }} />
          <div style={{ fontSize: 17, fontWeight: 700 }}>Keyboard & Touchpad Locked</div>
          <div style={{ fontSize: 12.5, color: 'var(--text-secondary)', lineHeight: 1.45 }}>
            Safe Cleaning Mode is active. Accidental keystrokes are suppressed while you clean your hardware.
          </div>
          <div style={{ width: '100%', height: 6, borderRadius: 999, background: 'var(--track-bg)', overflow: 'hidden' }}>
            <div style={{ width: `${unlockProgress}%`, height: '100%', background: 'var(--accent-green)', transition: 'width 60ms linear' }} />
          </div>
          <button
            type="button"
            className="btn btn-primary"
            style={{ width: '100%', height: 36 }}
            onMouseDown={startUnlockHold}
            onMouseUp={stopUnlockHold}
            onMouseLeave={stopUnlockHold}
            onTouchStart={startUnlockHold}
            onTouchEnd={stopUnlockHold}
          >
            <LockOpen size={14} /> Hold button (1s) to Unlock
          </button>
        </div>
      )}

      {/* 8. ABOUT MODAL */}
      {activeOverlay === 'about' && (
        <div className="overlay-card" style={{ width: 400, padding: 24, alignItems: 'center', textAlign: 'center', gap: 10 }} onClick={(e) => e.stopPropagation()}>
          <BrandMark width={58} />
          <div style={{ fontSize: 18, fontWeight: 700, marginTop: 4 }}>Vorssaint Utils</div>
          <div className="tag-badge blue">Windows Edition · v{APP_VERSION}</div>
          <div style={{ fontSize: 12, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
            Native Rust + Win32 + Tauri v2 port of the Vorssaint modular desktop suite. Telemetry, Audio Mixer, Dynamic Island, Window Layout, Winget & Dev Tools.
          </div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
            GPL-3.0-or-later · Vorssaint Brand Artwork reserved under TRADEMARKS.md
          </div>
          <button type="button" className="btn btn-primary" style={{ marginTop: 6, width: '100%' }} onClick={onClose}>
            <Check size={14} /> Done
          </button>
        </div>
      )}
    </div>
  );
}

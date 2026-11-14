import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AppWindow,
  Calculator,
  Clipboard,
  Columns,
  Copy,
  Globe,
  Link2,
  Lock,
  Moon,
  Pin,
  Pipette,
  Scissors,
  Search,
  Settings,
  ShieldCheck,
  Sparkles,
  Terminal,
  Trash2,
  X,
  Zap,
} from 'lucide-react';
import { BrandMark } from '../components/BrandMark';
import { FEATURE_CATALOG, UI_LABELS } from '../data/catalog';
import {
  captureScreenPng,
  copyToClipboard,
  focusWindow,
  hideOverlay,
  launchWindowsUtility,
  listOpenWindows,
  lockWorkstation,
  openExternalUrl,
  openSettingsWindow,
  pickScreenColor,
  safeListen,
  setWindowsDarkMode,
  snapActiveWindow,
  toggleTrayPanel,
  toggleWindowPin,
} from '../lib/bridge';
import { useVorssaintStore } from '../lib/store';
import { cleanUrl, isLikelyUrl } from '../lib/urlCleaner';
import type { OpenWindowEntry, OverlayMode } from '../types/vorssaint';

function evalMath(expr: string): string | null {
  const cleaned = expr.replace(/^=/, '').trim();
  if (!cleaned || !/^[0-9+\-*/().%\s]+$/.test(cleaned)) return null;
  try {
    const fn = new Function(`"use strict"; return (${cleaned});`);
    const v = fn();
    if (typeof v === 'number' && Number.isFinite(v)) {
      return Number.isInteger(v) ? String(v) : v.toFixed(4).replace(/\.?0+$/, '');
    }
    return null;
  } catch {
    return null;
  }
}

interface PaletteAction {
  id: string;
  group: string;
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  run: () => void | Promise<void>;
}

export const OverlayWindow: React.FC = () => {
  const {
    settings,
    clipboard,
    togglePinClipboard,
    clearClipboard,
    snippets,
    addClipboardEntry,
    toggleKeepAwakeState,
  } = useVorssaintStore();

  const labels = UI_LABELS[settings.language] ?? UI_LABELS.pt;
  const accent = settings.accentHex || '#38bdf8';

  const [mode, setMode] = useState<OverlayMode>('command');
  const [query, setQuery] = useState('');
  const [selectedIdx, setSelectedIdx] = useState(0);
  const [windows, setWindows] = useState<OpenWindowEntry[]>([]);
  const [radialHover, setRadialHover] = useState<number | null>(null);
  const [cleanHoldProgress, setCleanHoldProgress] = useState(0);

  const inputRef = useRef<HTMLInputElement | null>(null);
  const holdTimerRef = useRef<number | null>(null);

  const refreshContext = useCallback(() => {
    void listOpenWindows().then(setWindows).catch(() => {});
    window.setTimeout(() => inputRef.current?.focus(), 40);
  }, []);

  useEffect(() => {
    refreshContext();
    const unsubPromise = safeListen<OverlayMode>('overlay-mode', (nextMode) => {
      setMode(nextMode);
      setQuery('');
      setSelectedIdx(0);
      setCleanHoldProgress(0);
      refreshContext();
    });
    return () => {
      void unsubPromise.then((u) => u());
    };
  }, [refreshContext]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        void hideOverlay();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  const builtInActions: PaletteAction[] = useMemo(
    () => [
      {
        id: 'act-shot',
        group: 'Captura',
        title: 'Captura de Tela PNG',
        subtitle: 'Salva screenshot em Imagens e copia caminho',
        icon: <Scissors size={15} color="#34d399" />,
        run: async () => {
          await hideOverlay();
          await captureScreenPng();
        },
      },
      {
        id: 'act-color',
        group: 'Design',
        title: 'Conta-gotas Win32 da Tela',
        subtitle: 'Captura a cor exata sob o cursor (#HEX)',
        icon: <Pipette size={15} color="#f472b6" />,
        run: async () => {
          await hideOverlay();
          const c = await pickScreenColor();
          await copyToClipboard(c.hex);
          addClipboardEntry(c.hex);
        },
      },
      {
        id: 'act-pin',
        group: 'Janelas',
        title: 'Fixar / Desafixar Janela no Topo',
        subtitle: 'Always-on-top para janela em primeiro plano',
        icon: <Pin size={15} color="#38bdf8" />,
        run: async () => {
          await hideOverlay();
          await toggleWindowPin();
        },
      },
      {
        id: 'act-snap-l',
        group: 'Janelas',
        title: 'Encaixar Janela à Esquerda',
        subtitle: 'Divide na metade esquerda da área útil',
        icon: <Columns size={15} color="#60a5fa" />,
        run: async () => {
          await hideOverlay();
          await snapActiveWindow('left');
        },
      },
      {
        id: 'act-snap-r',
        group: 'Janelas',
        title: 'Encaixar Janela à Direita',
        subtitle: 'Divide na metade direita da área útil',
        icon: <Columns size={15} color="#60a5fa" />,
        run: async () => {
          await hideOverlay();
          await snapActiveWindow('right');
        },
      },
      {
        id: 'act-awake',
        group: 'Energia',
        title: 'Ativar Manter PC Ligado (Keep Awake)',
        subtitle: 'Impede suspensão e tela desligada',
        icon: <Zap size={15} color="#fbbf24" />,
        run: async () => {
          await toggleKeepAwakeState(true);
          await hideOverlay();
        },
      },
      {
        id: 'act-dark',
        group: 'Sistema',
        title: 'Alternar Tema Escuro do Windows',
        subtitle: 'Aplica Dark Mode nativo em apps e sistema',
        icon: <Moon size={15} color="#818cf8" />,
        run: async () => {
          await setWindowsDarkMode(true);
          await hideOverlay();
        },
      },
      {
        id: 'act-panel',
        group: 'Vorssaint',
        title: 'Abrir Painel da Bandeja',
        subtitle: 'Abre flyout acima do relógio',
        icon: <Sparkles size={15} color={accent} />,
        run: async () => {
          await hideOverlay();
          await toggleTrayPanel();
        },
      },
      {
        id: 'act-clean-mode',
        group: 'Utilitários',
        title: 'Modo Limpeza de Tela & Teclado',
        subtitle: 'Bloqueio temporário para higienizar o computador',
        icon: <ShieldCheck size={15} color="#fbbf24" />,
        run: () => setMode('cleaning'),
      },
      {
        id: 'act-lock',
        group: 'Sistema',
        title: 'Bloquear Sessão do Windows (Win+L)',
        subtitle: 'LockWorkStation nativo',
        icon: <Lock size={15} color="#f87171" />,
        run: async () => {
          await hideOverlay();
          await lockWorkstation();
        },
      },
      {
        id: 'act-term',
        group: 'Windows',
        title: 'Abrir Windows Terminal',
        subtitle: 'Inicia wt.exe',
        icon: <Terminal size={15} color="#a78bfa" />,
        run: async () => {
          await hideOverlay();
          await launchWindowsUtility('wt');
        },
      },
      {
        id: 'act-settings',
        group: 'Vorssaint',
        title: 'Abrir Configurações Completas',
        subtitle: 'Central de recursos, Ilha Dinâmica e ferramentas',
        icon: <Settings size={15} color="#94a3b8" />,
        run: async () => {
          await hideOverlay();
          await openSettingsWindow('general');
        },
      },
    ],
    [accent, addClipboardEntry, toggleKeepAwakeState]
  );

  const mathResult = evalMath(query);
  const cleanedUrl = isLikelyUrl(query) ? cleanUrl(query) : null;

  const commandResults: PaletteAction[] = useMemo(() => {
    const q = query.trim().toLowerCase();
    const list: PaletteAction[] = [];

    if (mathResult) {
      list.push({
        id: 'math-res',
        group: 'Cálculo',
        title: `= ${mathResult}`,
        subtitle: 'Pressione Enter para copiar o resultado',
        icon: <Calculator size={15} color={accent} />,
        run: async () => {
          await copyToClipboard(mathResult);
          addClipboardEntry(mathResult);
          await hideOverlay();
        },
      });
    }

    if (cleanedUrl?.valid) {
      list.push({
        id: 'url-clean-res',
        group: 'Limpador URL',
        title: `Copiar URL Limpa (-${cleanedUrl.removedCount} trackers)`,
        subtitle: cleanedUrl.cleaned,
        icon: <Link2 size={15} color="#34d399" />,
        run: async () => {
          await copyToClipboard(cleanedUrl.cleaned);
          addClipboardEntry(cleanedUrl.cleaned);
          await hideOverlay();
        },
      });
    }

    for (const act of builtInActions) {
      if (
        !q ||
        act.title.toLowerCase().includes(q) ||
        act.subtitle.toLowerCase().includes(q) ||
        act.group.toLowerCase().includes(q)
      ) {
        list.push(act);
      }
    }

    for (const w of windows) {
      if (
        !q ||
        w.title.toLowerCase().includes(q) ||
        w.processName.toLowerCase().includes(q)
      ) {
        list.push({
          id: `win-${w.hwnd}`,
          group: 'Janela Aberta',
          title: w.title,
          subtitle: w.processName,
          icon: <AppWindow size={15} color="#38bdf8" />,
          run: async () => {
            await hideOverlay();
            await focusWindow(w.hwnd);
          },
        });
      }
    }

    for (const snip of snippets) {
      if (
        !q ||
        snip.trigger.toLowerCase().includes(q) ||
        snip.expansion.toLowerCase().includes(q)
      ) {
        list.push({
          id: `snip-${snip.id}`,
          group: 'Snippet',
          title: `${snip.trigger} · ${snip.category}`,
          subtitle: snip.expansion.replace(/\n/g, ' '),
          icon: <Copy size={15} color="#a78bfa" />,
          run: async () => {
            await copyToClipboard(snip.expansion);
            await hideOverlay();
          },
        });
      }
    }

    if (q) {
      for (const f of FEATURE_CATALOG) {
        if (
          f.settingsPage &&
          (f.title[settings.language].toLowerCase().includes(q) ||
            f.summary[settings.language].toLowerCase().includes(q))
        ) {
          list.push({
            id: `feat-${f.key}`,
            group: 'Recurso',
            title: f.title[settings.language],
            subtitle: f.summary[settings.language],
            icon: <Sparkles size={15} color={accent} />,
            run: async () => {
              await hideOverlay();
              await openSettingsWindow(f.settingsPage);
            },
          });
        }
      }

      list.push({
        id: 'web-search',
        group: 'Web',
        title: `Pesquisar "${query}" no navegador`,
        subtitle: 'Abrir busca padrão via Google',
        icon: <Globe size={15} color="#60a5fa" />,
        run: async () => {
          await hideOverlay();
          await openExternalUrl(
            `https://www.google.com/search?q=${encodeURIComponent(query)}`
          );
        },
      });
    }

    return list.slice(0, 14);
  }, [
    query,
    mathResult,
    cleanedUrl,
    builtInActions,
    windows,
    snippets,
    settings.language,
    accent,
    addClipboardEntry,
  ]);

  const filteredClipboard = useMemo(() => {
    const q = query.trim().toLowerCase();
    return clipboard.filter((c) => !q || c.text.toLowerCase().includes(q));
  }, [clipboard, query]);

  const radialItems = useMemo(
    () => [
      { label: 'Captura PNG', color: '#34d399', action: builtInActions[0].run },
      { label: 'Conta-gotas', color: '#f472b6', action: builtInActions[1].run },
      { label: 'Fixar Janela', color: '#38bdf8', action: builtInActions[2].run },
      { label: 'Snap Dir.', color: '#60a5fa', action: builtInActions[4].run },
      { label: 'Keep Awake', color: '#fbbf24', action: builtInActions[5].run },
      { label: 'Modo Limpeza', color: '#fb923c', action: builtInActions[8].run },
      { label: 'Command Bar', color: '#a78bfa', action: () => setMode('command') },
      { label: 'Snap Esq.', color: '#2dd4bf', action: builtInActions[3].run },
    ],
    [builtInActions]
  );

  const startCleanHold = () => {
    if (holdTimerRef.current) window.clearInterval(holdTimerRef.current);
    const start = Date.now();
    holdTimerRef.current = window.setInterval(() => {
      const elapsed = Date.now() - start;
      const pct = Math.min(100, (elapsed / 1200) * 100);
      setCleanHoldProgress(pct);
      if (pct >= 100) {
        if (holdTimerRef.current) window.clearInterval(holdTimerRef.current);
        void hideOverlay();
      }
    }, 30);
  };

  const stopCleanHold = () => {
    if (holdTimerRef.current) {
      window.clearInterval(holdTimerRef.current);
      holdTimerRef.current = null;
    }
    setCleanHoldProgress(0);
  };

  return (
    <div
      onClick={(e) => {
        if (e.target === e.currentTarget && mode !== 'cleaning') {
          void hideOverlay();
        }
      }}
      style={{
        width: '100vw',
        height: '100vh',
        display: 'grid',
        placeItems: 'center',
        padding: 16,
        background: 'transparent',
      }}
    >
      {/* MODE 1: GLOBAL COMMAND BAR */}
      {mode === 'command' && (
        <div
          className="v-shell"
          style={{
            width: '100%',
            maxWidth: 620,
            maxHeight: 450,
            borderRadius: 18,
            background: 'rgba(13, 16, 24, 0.96)',
            border: '1px solid rgba(255,255,255,0.16)',
            boxShadow: '0 26px 60px rgba(0,0,0,0.68)',
            backdropFilter: 'blur(26px)',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              padding: '12px 14px',
              borderBottom: '1px solid rgba(255,255,255,0.1)',
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <Search size={17} color={accent} />
            <input
              ref={inputRef}
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setSelectedIdx(0);
              }}
              onKeyDown={(e) => {
                if (e.key === 'ArrowDown') {
                  e.preventDefault();
                  setSelectedIdx((i) => Math.min(commandResults.length - 1, i + 1));
                } else if (e.key === 'ArrowUp') {
                  e.preventDefault();
                  setSelectedIdx((i) => Math.max(0, i - 1));
                } else if (e.key === 'Enter' && commandResults[selectedIdx]) {
                  e.preventDefault();
                  void commandResults[selectedIdx].run();
                }
              }}
              placeholder={labels.commandPlaceholder}
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                color: '#fff',
                fontSize: 15,
                fontFamily: 'inherit',
              }}
            />
            <span
              style={{
                fontSize: 10.5,
                color: 'rgba(255,255,255,0.45)',
                padding: '2px 7px',
                borderRadius: 6,
                border: '1px solid rgba(255,255,255,0.12)',
              }}
            >
              ESC
            </span>
          </div>

          <div style={{ flex: 1, overflowY: 'auto', padding: 8, display: 'flex', flexDirection: 'column', gap: 3 }}>
            {commandResults.map((item, idx) => {
              const active = idx === selectedIdx;
              return (
                <button
                  key={item.id}
                  onMouseEnter={() => setSelectedIdx(idx)}
                  onClick={() => void item.run()}
                  style={{
                    padding: '9px 11px',
                    borderRadius: 11,
                    border: active ? `1px solid ${accent}44` : '1px solid transparent',
                    background: active ? `${accent}20` : 'transparent',
                    color: '#fff',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: 10,
                    cursor: 'pointer',
                    textAlign: 'left',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
                    <span
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: 8,
                        background: 'rgba(255,255,255,0.06)',
                        display: 'grid',
                        placeItems: 'center',
                        flexShrink: 0,
                      }}
                    >
                      {item.icon}
                    </span>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontSize: 13, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {item.title}
                      </div>
                      <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.52)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {item.subtitle}
                      </div>
                    </div>
                  </div>
                  <span style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.45)', whiteSpace: 'nowrap' }}>
                    {item.group}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* MODE 2: CLIPBOARD QUICK PANEL */}
      {mode === 'clipboard' && (
        <div
          className="v-shell"
          style={{
            width: '100%',
            maxWidth: 590,
            maxHeight: 450,
            borderRadius: 18,
            background: 'rgba(13, 16, 24, 0.96)',
            border: '1px solid rgba(255,255,255,0.16)',
            boxShadow: '0 26px 60px rgba(0,0,0,0.68)',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
          }}
        >
          <div style={{ padding: '12px 14px', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', gap: 10 }}>
            <Clipboard size={16} color={accent} />
            <input
              ref={inputRef}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Buscar no Histórico de Clipboard do Windows..."
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                color: '#fff',
                fontSize: 13.5,
              }}
            />
            <button
              className="v-btn"
              style={{ padding: '4px 9px', fontSize: 11, color: '#fca5a5' }}
              onClick={clearClipboard}
            >
              <Trash2 size={12} /> Limpar
            </button>
            <button
              className="v-btn"
              style={{ padding: 5 }}
              onClick={() => void hideOverlay()}
            >
              <X size={13} />
            </button>
          </div>

          <div style={{ flex: 1, overflowY: 'auto', padding: 10, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {filteredClipboard.length === 0 ? (
              <div style={{ padding: 20, textAlign: 'center', fontSize: 12.5, color: 'rgba(255,255,255,0.5)' }}>
                Nenhum item encontrado no Clipboard.
              </div>
            ) : (
              filteredClipboard.map((item) => (
                <div
                  key={item.id}
                  style={{
                    padding: '9px 11px',
                    borderRadius: 11,
                    background: 'rgba(255,255,255,0.04)',
                    border: '1px solid rgba(255,255,255,0.08)',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                  }}
                >
                  {item.kind === 'color' && (
                    <span
                      style={{
                        width: 18,
                        height: 18,
                        borderRadius: 5,
                        background: item.text.trim(),
                        border: '1px solid rgba(255,255,255,0.35)',
                        flexShrink: 0,
                      }}
                    />
                  )}
                  <div
                    onClick={async () => {
                      await copyToClipboard(item.text);
                      await hideOverlay();
                    }}
                    style={{ flex: 1, minWidth: 0, cursor: 'pointer' }}
                  >
                    <div
                      style={{
                        fontSize: 12.5,
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {item.text}
                    </div>
                    <div style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.45)', marginTop: 2 }}>
                      {item.kind.toUpperCase()} · {item.source}
                    </div>
                  </div>
                  <button
                    onClick={() => togglePinClipboard(item.id)}
                    style={{
                      border: 'none',
                      background: 'transparent',
                      color: item.pinned ? '#fbbf24' : 'rgba(255,255,255,0.45)',
                      cursor: 'pointer',
                    }}
                  >
                    <Pin size={13} />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* MODE 3: RADIAL WHEEL MENU */}
      {mode === 'radial' && (
        <div
          style={{
            position: 'relative',
            width: 390,
            height: 390,
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(17,21,32,0.94) 0%, rgba(10,12,18,0.92) 100%)',
            border: '1px solid rgba(255,255,255,0.16)',
            boxShadow: '0 24px 64px rgba(0,0,0,0.72)',
            display: 'grid',
            placeItems: 'center',
          }}
        >
          {radialItems.map((item, idx) => {
            const angle = (idx / radialItems.length) * Math.PI * 2 - Math.PI / 2;
            const r = 132;
            const x = Math.cos(angle) * r;
            const y = Math.sin(angle) * r;
            const hovered = radialHover === idx;
            return (
              <button
                key={item.label}
                onMouseEnter={() => setRadialHover(idx)}
                onMouseLeave={() => setRadialHover(null)}
                onClick={() => void item.action()}
                style={{
                  position: 'absolute',
                  transform: `translate(${x}px, ${y}px) scale(${hovered ? 1.09 : 1})`,
                  width: 90,
                  padding: '9px 6px',
                  borderRadius: 14,
                  border: hovered
                    ? `1.5px solid ${item.color}`
                    : '1px solid rgba(255,255,255,0.14)',
                  background: hovered ? `${item.color}2b` : 'rgba(255,255,255,0.06)',
                  color: '#fff',
                  fontSize: 11,
                  fontWeight: 700,
                  textAlign: 'center',
                  cursor: 'pointer',
                  transition: 'transform 130ms ease, background 130ms ease',
                }}
              >
                {item.label}
              </button>
            );
          })}

          <button
            onClick={() => void hideOverlay()}
            style={{
              width: 104,
              height: 104,
              borderRadius: '50%',
              border: `1px solid ${accent}55`,
              background: 'rgba(15, 18, 26, 0.96)',
              color: '#fff',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 6,
              cursor: 'pointer',
            }}
          >
            <BrandMark size={24} light />
            <span style={{ fontSize: 10.5, fontWeight: 700, color: 'rgba(255,255,255,0.82)' }}>
              {radialHover !== null ? radialItems[radialHover].label : 'Fechar'}
            </span>
          </button>
        </div>
      )}

      {/* MODE 4: CLEANING LOCK SHIELD */}
      {mode === 'cleaning' && (
        <div
          className="v-shell"
          style={{
            width: '100%',
            maxWidth: 480,
            padding: 28,
            borderRadius: 22,
            background: 'rgba(9, 11, 16, 0.97)',
            border: `1.5px solid ${accent}55`,
            boxShadow: '0 28px 70px rgba(0,0,0,0.8)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            textAlign: 'center',
            gap: 14,
          }}
        >
          <BrandMark size={46} badge />
          <div style={{ fontSize: 18, fontWeight: 700 }}>Modo Limpeza Ativo</div>
          <div style={{ fontSize: 12.5, color: 'rgba(255,255,255,0.65)', lineHeight: 1.5 }}>
            Área de proteção para higienizar a tela e o teclado com segurança. Segure o botão abaixo por 1.2s ou pressione ESC para sair.
          </div>

          <button
            onMouseDown={startCleanHold}
            onMouseUp={stopCleanHold}
            onMouseLeave={stopCleanHold}
            style={{
              position: 'relative',
              overflow: 'hidden',
              width: 240,
              padding: '11px 18px',
              borderRadius: 12,
              border: `1px solid ${accent}66`,
              background: 'rgba(255,255,255,0.07)',
              color: '#fff',
              fontSize: 13,
              fontWeight: 700,
              cursor: 'pointer',
            }}
          >
            <span
              style={{
                position: 'absolute',
                left: 0,
                top: 0,
                bottom: 0,
                width: `${cleanHoldProgress}%`,
                background: accent,
                opacity: 0.35,
              }}
            />
            <span style={{ position: 'relative' }}>Segure para Desbloquear</span>
          </button>

          <button
            onClick={() => void hideOverlay()}
            style={{
              border: 'none',
              background: 'transparent',
              color: 'rgba(255,255,255,0.45)',
              fontSize: 11.5,
              cursor: 'pointer',
            }}
          >
            Sair imediatamente (ESC)
          </button>
        </div>
      )}
    </div>
  );
};

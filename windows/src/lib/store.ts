import { useCallback, useEffect, useState } from 'react';
import {
  APP_VERSION,
  createDefaultSettings,
  FEATURE_BUNDLES,
  FEATURE_CATALOG,
  INITIAL_AGENTS,
  INITIAL_NOTES,
  INITIAL_SNIPPETS,
} from '../data/catalog';
import type {
  ClipboardItem,
  DynamicIslandAgent,
  ScratchpadNote,
  ScreenshotResult,
  ShelfDropFile,
  ShelfItem,
  TextSnippet,
  VorssaintSettings,
} from '../types/vorssaint';
import { copyToClipboard, safeListen, setIslandVisible, setKeepAwake } from './bridge';
import { cleanUrl, isLikelyUrl } from './urlCleaner';

const KEYS = {
  settings: 'vorssaint.win.v2.settings',
  clipboard: 'vorssaint.win.v2.clipboard',
  shelf: 'vorssaint.win.v2.shelf',
  notes: 'vorssaint.win.v2.notes',
  snippets: 'vorssaint.win.v2.snippets',
  captures: 'vorssaint.win.v2.captures',
  timer: 'vorssaint.win.v2.timer',
};

export interface SharedTimerState {
  mode: 'timer' | 'stopwatch';
  running: boolean;
  remainingSec: number;
  elapsedSec: number;
  presetMinutes: number;
  laps: number[];
  updatedAt: number;
}

const DEFAULT_TIMER: SharedTimerState = {
  mode: 'timer',
  running: false,
  remainingSec: 25 * 60,
  elapsedSec: 0,
  presetMinutes: 25,
  laps: [],
  updatedAt: Date.now(),
};

function readStorage<T>(key: string, fallback: T): T {
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function writeStorage<T>(key: string, value: T): void {
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // ignore quota issues
  }
}

export function useVorssaintStore() {
  const [settings, setSettingsState] = useState<VorssaintSettings>(() => {
    const base = createDefaultSettings();
    const saved = readStorage<Partial<VorssaintSettings>>(KEYS.settings, {});
    return {
      ...base,
      ...saved,
      installedFeatures: { ...base.installedFeatures, ...(saved.installedFeatures ?? {}) },
      panelVisibleSections: { ...base.panelVisibleSections, ...(saved.panelVisibleSections ?? {}) },
    };
  });

  const [clipboard, setClipboardState] = useState<ClipboardItem[]>(() =>
    readStorage<ClipboardItem[]>(KEYS.clipboard, [
      {
        id: 'clip-init-1',
        text: `Vorssaint Utils v${APP_VERSION} — Windows Edition`,
        kind: 'text',
        source: 'Vorssaint',
        timestamp: Date.now() - 120_000,
        pinned: true,
      },
    ])
  );

  const [shelf, setShelfState] = useState<ShelfItem[]>(() =>
    readStorage<ShelfItem[]>(KEYS.shelf, [])
  );

  const [notes, setNotesState] = useState<ScratchpadNote[]>(() =>
    readStorage<ScratchpadNote[]>(KEYS.notes, INITIAL_NOTES)
  );

  const [snippets, setSnippetsState] = useState<TextSnippet[]>(() =>
    readStorage<TextSnippet[]>(KEYS.snippets, INITIAL_SNIPPETS)
  );

  const [captures, setCapturesState] = useState<ScreenshotResult[]>(() =>
    readStorage<ScreenshotResult[]>(KEYS.captures, [])
  );

  const [timer, setTimerState] = useState<SharedTimerState>(() =>
    readStorage<SharedTimerState>(KEYS.timer, DEFAULT_TIMER)
  );

  const [agents] = useState<DynamicIslandAgent[]>(INITIAL_AGENTS);

  // Sync across all 4 native Tauri windows via storage events
  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (!e.key || !e.newValue) return;
      try {
        if (e.key === KEYS.settings) {
          const base = createDefaultSettings();
          const parsed = JSON.parse(e.newValue) as Partial<VorssaintSettings>;
          setSettingsState({
            ...base,
            ...parsed,
            installedFeatures: { ...base.installedFeatures, ...(parsed.installedFeatures ?? {}) },
            panelVisibleSections: {
              ...base.panelVisibleSections,
              ...(parsed.panelVisibleSections ?? {}),
            },
          });
        } else if (e.key === KEYS.clipboard) {
          setClipboardState(JSON.parse(e.newValue));
        } else if (e.key === KEYS.shelf) {
          setShelfState(JSON.parse(e.newValue));
        } else if (e.key === KEYS.notes) {
          setNotesState(JSON.parse(e.newValue));
        } else if (e.key === KEYS.snippets) {
          setSnippetsState(JSON.parse(e.newValue));
        } else if (e.key === KEYS.captures) {
          setCapturesState(JSON.parse(e.newValue));
        } else if (e.key === KEYS.timer) {
          setTimerState(JSON.parse(e.newValue));
        }
      } catch {
        // ignore parse errors
      }
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  // Listen to native Win32 clipboard / drag-drop / screenshot events
  useEffect(() => {
    let mounted = true;
    const unsubs: (() => void)[] = [];

    safeListen<string>('clipboard-captured', (rawText) => {
      if (!mounted || !rawText.trim()) return;
      setSettingsState((currSettings) => {
        const isUrl = isLikelyUrl(rawText);
        let finalText = rawText;
        if (isUrl && currSettings.autoCleanUrls) {
          const cleaned = cleanUrl(rawText);
          if (cleaned.valid && cleaned.removedCount > 0) {
            finalText = cleaned.cleaned;
            void copyToClipboard(finalText);
          }
        }
        const isHex = /^#[0-9a-f]{6}$/i.test(finalText.trim());
        const kind: ClipboardItem['kind'] = isHex ? 'color' : isUrl ? 'url' : finalText.includes('\n') ? 'code' : 'text';

        setClipboardState((prev) => {
          const existing = prev.filter((item) => item.text !== finalText);
          const next: ClipboardItem[] = [
            {
              id: `clip-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
              text: finalText,
              kind,
              source: 'Windows',
              timestamp: Date.now(),
            },
            ...existing,
          ].slice(0, currSettings.clipboardMaxItems || 80);
          writeStorage(KEYS.clipboard, next);
          return next;
        });
        return currSettings;
      });
    }).then((u) => unsubs.push(u));

    safeListen<ShelfDropFile[]>('island-files-dropped', (files) => {
      if (!mounted || !files?.length) return;
      setShelfState((prev) => {
        const mapped: ShelfItem[] = files.map((f, i) => ({
          id: `shelf-${Date.now()}-${i}`,
          name: f.name,
          path: f.path,
          kind: (['image', 'pdf', 'code', 'archive'].includes(f.kind) ? f.kind : 'file') as ShelfItem['kind'],
          sizeLabel: f.sizeLabel,
          addedAt: Date.now(),
        }));
        const deduped = prev.filter((p) => !mapped.some((m) => m.path === p.path));
        const next = [...mapped, ...deduped].slice(0, 40);
        writeStorage(KEYS.shelf, next);
        return next;
      });
    }).then((u) => unsubs.push(u));

    safeListen<ScreenshotResult>('screenshot-captured', (shot) => {
      if (!mounted || !shot) return;
      setCapturesState((prev) => {
        const next = [shot, ...prev].slice(0, 20);
        writeStorage(KEYS.captures, next);
        return next;
      });
    }).then((u) => unsubs.push(u));

    return () => {
      mounted = false;
      unsubs.forEach((fn) => fn());
    };
  }, []);

  // Apply root CSS accent and light/dark variables
  useEffect(() => {
    document.documentElement.style.setProperty('--accent', settings.accentHex);
    document.documentElement.style.setProperty(
      '--accent-soft',
      `${settings.accentHex}29`
    );
  }, [settings.accentHex]);

  const updateSettings = useCallback((patch: Partial<VorssaintSettings>) => {
    setSettingsState((prev) => {
      const next = { ...prev, ...patch };
      writeStorage(KEYS.settings, next);
      if (patch.islandVisible !== undefined && patch.islandVisible !== prev.islandVisible) {
        void setIslandVisible(patch.islandVisible);
      }
      return next;
    });
  }, []);

  const toggleFeature = useCallback((key: string, enabled?: boolean) => {
    setSettingsState((prev) => {
      const val = enabled ?? !prev.installedFeatures[key];
      const next: VorssaintSettings = {
        ...prev,
        installedFeatures: { ...prev.installedFeatures, [key]: val },
      };
      writeStorage(KEYS.settings, next);
      if (key === 'notch') {
        void setIslandVisible(val);
      }
      return next;
    });
  }, []);

  const installAllFeatures = useCallback((install: boolean) => {
    setSettingsState((prev) => {
      const installedFeatures: Record<string, boolean> = {};
      for (const f of FEATURE_CATALOG) installedFeatures[f.key] = install;
      const next = { ...prev, installedFeatures };
      writeStorage(KEYS.settings, next);
      void setIslandVisible(install);
      return next;
    });
  }, []);

  const applyBundle = useCallback((bundleId: string) => {
    const bundle = FEATURE_BUNDLES.find((b) => b.id === bundleId);
    if (!bundle) return;
    setSettingsState((prev) => {
      const installedFeatures: Record<string, boolean> = {};
      for (const f of FEATURE_CATALOG) {
        installedFeatures[f.key] = bundle.featureKeys.includes(f.key);
      }
      const next = { ...prev, installedFeatures, islandVisible: Boolean(installedFeatures.notch) };
      writeStorage(KEYS.settings, next);
      void setIslandVisible(next.islandVisible);
      return next;
    });
  }, []);

  const updateTimer = useCallback((updater: (prev: SharedTimerState) => SharedTimerState) => {
    setTimerState((prev) => {
      const next = { ...updater(prev), updatedAt: Date.now() };
      writeStorage(KEYS.timer, next);
      return next;
    });
  }, []);

  const saveNotes = useCallback((next: ScratchpadNote[]) => {
    setNotesState(next);
    writeStorage(KEYS.notes, next);
  }, []);

  const saveSnippets = useCallback((next: TextSnippet[]) => {
    setSnippetsState(next);
    writeStorage(KEYS.snippets, next);
  }, []);

  const removeShelfItem = useCallback((id: string) => {
    setShelfState((prev) => {
      const next = prev.filter((x) => x.id !== id);
      writeStorage(KEYS.shelf, next);
      return next;
    });
  }, []);

  const clearShelf = useCallback(() => {
    setShelfState([]);
    writeStorage(KEYS.shelf, []);
  }, []);

  const addClipboardEntry = useCallback((text: string) => {
    if (!text.trim()) return;
    void copyToClipboard(text);
    setClipboardState((prev) => {
      const next: ClipboardItem[] = [
        {
          id: `clip-${Date.now()}`,
          text,
          kind: (isLikelyUrl(text) ? 'url' : 'text') as ClipboardItem['kind'],
          source: 'Vorssaint',
          timestamp: Date.now(),
        },
        ...prev.filter((i) => i.text !== text),
      ].slice(0, 80);
      writeStorage(KEYS.clipboard, next);
      return next;
    });
  }, []);

  const togglePinClipboard = useCallback((id: string) => {
    setClipboardState((prev) => {
      const next = prev.map((c) => (c.id === id ? { ...c, pinned: !c.pinned } : c));
      writeStorage(KEYS.clipboard, next);
      return next;
    });
  }, []);

  const clearClipboard = useCallback(() => {
    setClipboardState((prev) => {
      const next = prev.filter((c) => c.pinned);
      writeStorage(KEYS.clipboard, next);
      return next;
    });
  }, []);

  const toggleKeepAwakeState = useCallback(
    async (enabled: boolean) => {
      return setKeepAwake(enabled, settings.keepDisplayOn);
    },
    [settings.keepDisplayOn]
  );

  return {
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
    notes,
    saveNotes,
    snippets,
    saveSnippets,
    captures,
    timer,
    updateTimer,
    agents,
    toggleKeepAwakeState,
  };
}

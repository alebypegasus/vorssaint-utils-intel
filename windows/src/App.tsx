import React, { useEffect, useState } from 'react';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { isTauriRuntime } from './lib/bridge';
import { useVorssaintStore } from './lib/store';
import type { WindowKind } from './types/vorssaint';
import { IslandWindow } from './windows/IslandWindow';
import { OverlayWindow } from './windows/OverlayWindow';
import { SettingsWindow } from './windows/SettingsWindow';
import { TrayPanelWindow } from './windows/TrayPanelWindow';

function resolveInitialWindowKind(): WindowKind {
  const param = new URLSearchParams(window.location.search).get('window');
  if (
    param === 'island' ||
    param === 'panel' ||
    param === 'settings' ||
    param === 'overlay'
  ) {
    return param;
  }
  return 'settings';
}

export const App: React.FC = () => {
  const [kind, setKind] = useState<WindowKind>(resolveInitialWindowKind);
  const { settings } = useVorssaintStore();

  useEffect(() => {
    const param = new URLSearchParams(window.location.search).get('window');
    if (param) return;
    if (isTauriRuntime()) {
      const label = getCurrentWindow().label;
      if (
        label === 'island' ||
        label === 'panel' ||
        label === 'settings' ||
        label === 'overlay'
      ) {
        setKind(label);
      }
    }
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    if (settings.appearance === 'light' && kind !== 'island') {
      root.classList.add('theme-light');
    } else {
      root.classList.remove('theme-light');
    }
  }, [settings.appearance, kind]);

  switch (kind) {
    case 'island':
      return <IslandWindow />;
    case 'panel':
      return <TrayPanelWindow />;
    case 'overlay':
      return <OverlayWindow />;
    case 'settings':
    default:
      return <SettingsWindow />;
  }
};

export default App;

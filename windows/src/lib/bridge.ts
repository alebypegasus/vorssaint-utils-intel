import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import type {
  AppAudioSession,
  InstalledAppEntry,
  JunkCategory,
  ListeningPortEntry,
  OpenWindowEntry,
  OverlayMode,
  PickedColorResult,
  ScreenshotResult,
  SystemTelemetry,
  WingetPackage,
} from '../types/vorssaint';

export function isTauriRuntime(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

export async function safeListen<T>(
  event: string,
  handler: (payload: T) => void
): Promise<UnlistenFn> {
  if (!isTauriRuntime()) {
    return () => {};
  }
  return listen<T>(event, (ev) => handler(ev.payload));
}

export async function setIslandBounds(
  width: number,
  height: number,
  focusWindow = false
): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('set_island_bounds', { width, height, focusWindow });
}

export async function setIslandVisible(visible: boolean): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('set_island_visible', { visible });
}

export async function toggleTrayPanel(): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('toggle_panel');
}

export async function hideTrayPanel(): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('hide_panel');
}

export async function openSettingsWindow(page?: string): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('open_settings_window', { page: page ?? null });
}

export async function openOverlay(mode: OverlayMode): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('open_overlay', { mode });
}

export async function hideOverlay(): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('hide_overlay');
}

export async function quitApp(): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('quit_app');
}

export async function fetchSystemTelemetry(): Promise<SystemTelemetry> {
  if (!isTauriRuntime()) {
    return {
      hostName: 'Windows-PC',
      osVersion: 'Windows 11',
      cpuBrand: 'x64 Processor',
      cpuPercent: 18,
      cpuCores: [14, 22, 19, 12, 24, 16, 15, 11],
      cpuTempC: 52,
      gpuPercent: 9,
      gpuTempC: 48,
      memoryUsedGb: 10.2,
      memoryTotalGb: 32,
      memoryPressure: 'Normal',
      batteryPercent: 86,
      batteryCharging: true,
      batteryTempC: null,
      uptimeSeconds: 18420,
      downloadKbPerSec: 128,
      uploadKbPerSec: 34,
      keepAwakeActive: false,
      masterVolume: 68,
      masterMuted: false,
      darkMode: true,
      activeWindowTitle: 'Vorssaint Utils',
      mediaSession: null,
      disks: [
        {
          name: 'Windows',
          mount: 'C:\\',
          fileSystem: 'NTFS',
          totalGb: 512,
          availableGb: 214,
          usedPercent: 58,
          isRemovable: false,
        },
      ],
      networks: [
        {
          name: 'Wi-Fi',
          rxKbPerSec: 128,
          txKbPerSec: 34,
          totalRxMb: 420,
          totalTxMb: 92,
        },
      ],
      topProcesses: [],
    };
  }
  return invoke<SystemTelemetry>('get_system_telemetry');
}

export async function setKeepAwake(enabled: boolean, keepDisplayOn: boolean): Promise<boolean> {
  if (!isTauriRuntime()) return enabled;
  return invoke<boolean>('set_keep_awake', { enabled, keepDisplayOn });
}

export async function setMasterAudio(
  volume?: number,
  muted?: boolean
): Promise<{ volume: number; muted: boolean }> {
  if (!isTauriRuntime()) return { volume: volume ?? 65, muted: muted ?? false };
  return invoke('set_master_audio', {
    volume: volume ?? null,
    muted: muted ?? null,
  });
}

export async function listAudioSessions(): Promise<AppAudioSession[]> {
  if (!isTauriRuntime()) return [];
  return invoke<AppAudioSession[]>('list_audio_sessions');
}

export async function setAppAudio(
  pid: number,
  volume?: number,
  muted?: boolean
): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('set_app_audio', {
    pid,
    volume: volume ?? null,
    muted: muted ?? null,
  });
}

export async function sendMediaAction(action: 'playPause' | 'next' | 'prev'): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('send_media_action', { action });
}

export async function setDisplayBrightness(level: number): Promise<number> {
  if (!isTauriRuntime()) return level;
  return invoke<number>('set_display_brightness', { level });
}

export async function setWindowsDarkMode(enabled: boolean): Promise<boolean> {
  if (!isTauriRuntime()) return enabled;
  return invoke<boolean>('set_windows_dark_mode', { enabled });
}

export async function lockWorkstation(): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('lock_workstation');
}

export async function emptyRecycleBin(): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('empty_recycle_bin');
}

export async function listOpenWindows(): Promise<OpenWindowEntry[]> {
  if (!isTauriRuntime()) return [];
  return invoke<OpenWindowEntry[]>('list_open_windows');
}

export async function focusWindow(hwnd: number): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('focus_window', { hwnd });
}

export async function toggleWindowPin(hwnd?: number): Promise<boolean> {
  if (!isTauriRuntime()) return false;
  return invoke<boolean>('toggle_window_pin', { hwnd: hwnd ?? null });
}

export async function snapActiveWindow(preset: string, hwnd?: number): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('snap_active_window', { preset, hwnd: hwnd ?? null });
}

export async function pickScreenColor(): Promise<PickedColorResult> {
  if (!isTauriRuntime()) {
    return { hex: '#38BDF8', r: 56, g: 189, b: 248, x: 0, y: 0 };
  }
  return invoke<PickedColorResult>('pick_screen_color');
}

export async function captureScreenPng(): Promise<ScreenshotResult | null> {
  if (!isTauriRuntime()) return null;
  return invoke<ScreenshotResult>('capture_screen_png');
}

export async function copyToClipboard(text: string): Promise<void> {
  if (!isTauriRuntime()) {
    await navigator.clipboard?.writeText(text).catch(() => {});
    return;
  }
  await invoke('copy_text_to_clipboard', { text });
}

export async function openPathInExplorer(path: string): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('open_path_in_explorer', { path });
}

export async function openExternalUrl(url: string): Promise<void> {
  if (!isTauriRuntime()) {
    window.open(url, '_blank');
    return;
  }
  await invoke('open_external_url', { url });
}

export async function launchWindowsUtility(command: string): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('launch_windows_utility', { command });
}

export async function listListeningPorts(): Promise<ListeningPortEntry[]> {
  if (!isTauriRuntime()) return [];
  return invoke<ListeningPortEntry[]>('list_listening_ports');
}

export async function killProcessByPid(pid: number): Promise<boolean> {
  if (!isTauriRuntime()) return false;
  return invoke<boolean>('kill_process', { pid });
}

export async function scanJunkCaches(): Promise<JunkCategory[]> {
  if (!isTauriRuntime()) return [];
  return invoke<JunkCategory[]>('scan_junk_caches');
}

export async function cleanJunkCaches(ids: string[]): Promise<number> {
  if (!isTauriRuntime()) return 0;
  return invoke<number>('clean_junk_caches', { ids });
}

export async function listInstalledApps(): Promise<InstalledAppEntry[]> {
  if (!isTauriRuntime()) return [];
  return invoke<InstalledAppEntry[]>('list_installed_apps');
}

export async function triggerUninstallApp(uninstallString: string): Promise<void> {
  if (!isTauriRuntime()) return;
  await invoke('uninstall_app', { uninstallString });
}

export async function wingetSearch(query: string): Promise<WingetPackage[]> {
  if (!isTauriRuntime()) return [];
  return invoke<WingetPackage[]>('winget_search', { query });
}

export async function wingetListUpdates(): Promise<WingetPackage[]> {
  if (!isTauriRuntime()) return [];
  return invoke<WingetPackage[]>('winget_list_updates');
}

export async function wingetInstall(id: string, upgrade = false): Promise<string> {
  if (!isTauriRuntime()) return 'Simulated';
  return invoke<string>('winget_install', { id, upgrade });
}

import type {
  InstalledAppEntry,
  JunkCategory,
  ListeningPortEntry,
  OpenWindowEntry,
  SystemTelemetry,
  WingetPackage,
} from '../types/vorssaint';

type InvokeFn = <T>(cmd: string, args?: Record<string, unknown>) => Promise<T>;

let cachedInvoke: InvokeFn | null | undefined = undefined;

async function getTauriInvoke(): Promise<InvokeFn | null> {
  if (cachedInvoke !== undefined) {
    return cachedInvoke;
  }
  const hasTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
  if (!hasTauri) {
    cachedInvoke = null;
    return null;
  }
  try {
    const core = await import('@tauri-apps/api/core');
    cachedInvoke = core.invoke;
    return cachedInvoke;
  } catch {
    cachedInvoke = null;
    return null;
  }
}

export async function isTauriRuntime(): Promise<boolean> {
  return (await getTauriInvoke()) !== null;
}

let simTick = 0;

function fallbackTelemetry(keepAwakeActive: boolean, masterVolume: number, masterMuted: boolean): SystemTelemetry {
  simTick += 1;
  const wave = Math.sin(simTick * 0.45);
  const cpuPercent = Math.round((24 + wave * 9 + (simTick % 3) * 2) * 10) / 10;
  const gpuPercent = Math.round((18 + Math.cos(simTick * 0.35) * 11) * 10) / 10;
  return {
    hostName: 'VORSSAINT-WIN11',
    osVersion: 'Windows 11 Pro (x64)',
    cpuBrand: 'Intel Core Ultra / AMD Ryzen (Preview Mode)',
    cpuPercent,
    cpuCores: Array.from({ length: 12 }, (_, idx) =>
      Math.max(4, Math.min(92, Math.round(cpuPercent + Math.sin(simTick * 0.5 + idx) * 14)))
    ),
    cpuTempC: 46 + Math.round(wave * 3),
    gpuPercent,
    gpuTempC: 41 + Math.round(wave * 2),
    memoryUsedGb: 11.4,
    memoryTotalGb: 32.0,
    memoryPressure: 'Normal',
    batteryPercent: 86,
    batteryCharging: true,
    batteryTempC: 29,
    uptimeSeconds: 18420 + simTick * 2,
    downloadKbPerSec: Math.round(Math.max(12, 340 + Math.sin(simTick) * 180)),
    uploadKbPerSec: Math.round(Math.max(4, 58 + Math.cos(simTick * 0.8) * 26)),
    keepAwakeActive,
    masterVolume,
    masterMuted,
    disks: [
      {
        name: 'Windows NVMe',
        mount: 'C:\\',
        fileSystem: 'NTFS',
        totalGb: 953.0,
        availableGb: 412.6,
        usedPercent: 56.7,
        isRemovable: false,
      },
      {
        name: 'Projects',
        mount: 'D:\\',
        fileSystem: 'NTFS',
        totalGb: 1863.0,
        availableGb: 1180.4,
        usedPercent: 36.6,
        isRemovable: false,
      },
    ],
    networks: [
      {
        name: 'Wi-Fi 6E AX211',
        rxKbPerSec: 340,
        txKbPerSec: 58,
        totalRxMb: 4218.5,
        totalTxMb: 814.2,
      },
      {
        name: 'Ethernet Realtek 2.5GbE',
        rxKbPerSec: 0,
        txKbPerSec: 0,
        totalRxMb: 120.0,
        totalTxMb: 28.4,
      },
    ],
    topProcesses: [
      { pid: 14820, name: 'Code.exe', cpuPercent: 9.4, memoryMb: 942.0 },
      { pid: 8112, name: 'msedgewebview2.exe', cpuPercent: 6.1, memoryMb: 418.4 },
      { pid: 3340, name: 'Discord.exe', cpuPercent: 3.8, memoryMb: 362.1 },
      { pid: 1924, name: 'explorer.exe', cpuPercent: 2.3, memoryMb: 214.5 },
      { pid: 22910, name: 'vorssaint-utils.exe', cpuPercent: 1.4, memoryMb: 98.0 },
    ],
  };
}

export async function fetchSystemTelemetry(
  keepAwakeFallback = false,
  volumeFallback = 68,
  mutedFallback = false
): Promise<SystemTelemetry> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    try {
      return await invoke<SystemTelemetry>('get_system_telemetry');
    } catch {
      // fall through to preview telemetry if called outside desktop shell
    }
  }
  return fallbackTelemetry(keepAwakeFallback, volumeFallback, mutedFallback);
}

export async function toggleKeepAwake(enabled: boolean, keepDisplayOn: boolean): Promise<boolean> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<boolean>('set_keep_awake', { enabled, keepDisplayOn });
  }
  return enabled;
}

export async function setMasterAudio(volume?: number, muted?: boolean): Promise<{ volume: number; muted: boolean }> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<{ volume: number; muted: boolean }>('set_master_audio', {
      volume: volume ?? null,
      muted: muted ?? null,
    });
  }
  return { volume: volume ?? 68, muted: muted ?? false };
}

export async function setDisplayBrightness(level: number): Promise<number> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<number>('set_display_brightness', { level });
  }
  return level;
}

export async function fetchOpenWindows(): Promise<OpenWindowEntry[]> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<OpenWindowEntry[]>('list_open_windows');
  }
  return [
    { hwnd: 1001, pid: 14820, title: 'vorssaint-utils-intel — Visual Studio Code', processName: 'Code.exe' },
    { hwnd: 1002, pid: 8112, title: 'GitHub Releases — Vorssaint Universal', processName: 'msedge.exe' },
    { hwnd: 1003, pid: 3340, title: 'Discord — #dev-windows', processName: 'Discord.exe' },
    { hwnd: 1004, pid: 1924, title: 'File Explorer — C:\\Projects', processName: 'explorer.exe' },
    { hwnd: 1005, pid: 9012, title: 'Windows Terminal — PowerShell', processName: 'WindowsTerminal.exe' },
  ];
}

export async function focusWindow(hwnd: number): Promise<void> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    await invoke<void>('focus_window', { hwnd });
  }
}

export async function snapActiveWindow(layout: string): Promise<void> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    await invoke<void>('snap_active_window', { layout });
  }
}

export async function fetchListeningPorts(): Promise<ListeningPortEntry[]> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<ListeningPortEntry[]>('list_listening_ports');
  }
  return [
    { protocol: 'TCP', localAddress: '127.0.0.1:1420', port: 1420, pid: 22910, processName: 'vite.exe' },
    { protocol: 'TCP', localAddress: '0.0.0.0:3000', port: 3000, pid: 17620, processName: 'node.exe' },
    { protocol: 'TCP', localAddress: '127.0.0.1:5432', port: 5432, pid: 6140, processName: 'postgres.exe' },
    { protocol: 'TCP', localAddress: '127.0.0.1:8080', port: 8080, pid: 24110, processName: 'cargo.exe' },
  ];
}

export async function killProcessByPid(pid: number): Promise<boolean> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<boolean>('kill_process', { pid });
  }
  return true;
}

export async function scanJunkCaches(): Promise<JunkCategory[]> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<JunkCategory[]>('scan_junk_caches');
  }
  return [
    { id: 'user-temp', label: 'Windows User Temp (%TEMP%)', path: 'C:\\Users\\user\\AppData\\Local\\Temp', sizeMb: 428.4, fileCount: 1842 },
    { id: 'crash-dumps', label: 'Windows CrashDumps', path: 'C:\\Users\\user\\AppData\\Local\\CrashDumps', sizeMb: 112.0, fileCount: 6 },
    { id: 'npm-cache', label: 'npm / Node Local Cache', path: 'C:\\Users\\user\\AppData\\Local\\npm-cache', sizeMb: 286.2, fileCount: 4120 },
    { id: 'pip-cache', label: 'Python pip Cache', path: 'C:\\Users\\user\\AppData\\Local\\pip\\Cache', sizeMb: 94.6, fileCount: 192 },
  ];
}

export async function cleanJunkCaches(categoryIds: string[]): Promise<number> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<number>('clean_junk_caches', { categoryIds });
  }
  return 921.2;
}

export async function fetchInstalledApps(): Promise<InstalledAppEntry[]> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<InstalledAppEntry[]>('list_installed_apps');
  }
  return [
    { name: 'Git', publisher: 'The Git Development Community', version: '2.56.0', installLocation: 'C:\\Program Files\\Git', uninstallString: '' },
    { name: 'Node.js', publisher: 'OpenJS Foundation', version: '26.13.1', installLocation: 'C:\\Program Files\\nodejs', uninstallString: '' },
    { name: 'Visual Studio Code', publisher: 'Microsoft Corporation', version: '1.99.0', installLocation: 'C:\\Users\\user\\AppData\\Local\\Programs\\Microsoft VS Code', uninstallString: '' },
    { name: 'Discord', publisher: 'Discord Inc.', version: '1.0.9182', installLocation: 'C:\\Users\\user\\AppData\\Local\\Discord', uninstallString: '' },
  ];
}

export async function triggerUninstallApp(uninstallString: string): Promise<string> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<string>('uninstall_app', { uninstallString });
  }
  return 'Launched native Windows uninstaller (requires Tauri Windows desktop runtime)';
}

export async function searchWingetPackages(query: string): Promise<WingetPackage[]> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<WingetPackage[]>('winget_search', { query });
  }
  return [
    { name: 'PowerToys (Preview)', id: 'Microsoft.PowerToys', version: '0.89.0' },
    { name: 'Everything', id: 'voidtools.Everything', version: '1.4.1.1026' },
    { name: 'ShareX', id: 'ShareX.ShareX', version: '17.0.0' },
  ].filter((p) => !query.trim() || `${p.name} ${p.id}`.toLowerCase().includes(query.toLowerCase()));
}

export async function fetchWingetUpdates(): Promise<WingetPackage[]> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<WingetPackage[]>('winget_list_updates');
  }
  return [
    { name: 'Visual Studio Code', id: 'Microsoft.VisualStudioCode', version: '1.98.2', availableVersion: '1.99.0' },
    { name: 'Git for Windows', id: 'Git.Git', version: '2.55.0', availableVersion: '2.56.0' },
  ];
}

export async function installWingetPackage(packageId: string): Promise<string> {
  const invoke = await getTauriInvoke();
  if (invoke) {
    return invoke<string>('winget_install', { packageId });
  }
  return `Queued winget install --id ${packageId}`;
}

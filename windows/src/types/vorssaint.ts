export type LocaleCode = 'pt' | 'en' | 'es';
export type AppAppearanceMode = 'dark' | 'light';
export type WindowKind = 'island' | 'panel' | 'settings' | 'overlay';
export type OverlayMode = 'command' | 'clipboard' | 'radial' | 'cleaning';

export type FeatureGroupId =
  | 'dynamicIsland'
  | 'mouse'
  | 'windows'
  | 'sound'
  | 'keyboard'
  | 'energy'
  | 'monitor'
  | 'files'
  | 'utilities'
  | 'system';

export type SettingsPageId =
  | 'general'
  | 'panelConfig'
  | 'features'
  | 'notch'
  | 'notchMascot'
  | 'monitor'
  | 'energy'
  | 'mixer'
  | 'brightness'
  | 'windowLayout'
  | 'switcher'
  | 'shortcuts'
  | 'commandBar'
  | 'radialMenu'
  | 'clipboard'
  | 'textSnippets'
  | 'urlCleaner'
  | 'cleaner'
  | 'uninstaller'
  | 'killProcess'
  | 'portManager'
  | 'appUpdates'
  | 'screenshot'
  | 'shelf'
  | 'about'
  | 'releaseNotes';

export type IslandModuleId =
  | 'controls'
  | 'music'
  | 'files'
  | 'timer'
  | 'calendar'
  | 'clipboard'
  | 'scratchpad'
  | 'mixer'
  | 'camera'
  | 'agents'
  | 'system';

export type TrayPanelSectionId =
  | 'keepAwake'
  | 'mixer'
  | 'brightness'
  | 'system'
  | 'network'
  | 'disk'
  | 'power'
  | 'fan'
  | 'utilities'
  | 'toggles';

export interface FeatureDefinition {
  key: string;
  group: FeatureGroupId;
  title: Record<LocaleCode, string>;
  summary: Record<LocaleCode, string>;
  settingsPage?: SettingsPageId;
  shortcut?: string;
  permission?: 'accessibility' | 'disk' | 'capture' | 'bluetooth';
}

export interface BundleDefinition {
  id: string;
  title: Record<LocaleCode, string>;
  summary: Record<LocaleCode, string>;
  featureKeys: string[];
}

export interface SidebarGroupDef {
  id: string;
  title: Record<LocaleCode, string>;
  items: {
    page: SettingsPageId;
    title: Record<LocaleCode, string>;
    icon: string;
  }[];
}

export interface ProcessEntry {
  pid: number;
  name: string;
  cpuPercent: number;
  memoryMb: number;
}

export interface DiskVolume {
  name: string;
  mount: string;
  fileSystem: string;
  totalGb: number;
  availableGb: number;
  usedPercent: number;
  isRemovable: boolean;
}

export interface NetAdapter {
  name: string;
  rxKbPerSec: number;
  txKbPerSec: number;
  totalRxMb: number;
  totalTxMb: number;
}

export interface MediaSessionInfo {
  appName: string;
  title: string;
  artist: string;
  isPlaying: boolean;
}

export interface SystemTelemetry {
  hostName: string;
  osVersion: string;
  cpuBrand: string;
  cpuPercent: number;
  cpuCores: number[];
  cpuTempC: number | null;
  gpuPercent: number;
  gpuTempC: number | null;
  memoryUsedGb: number;
  memoryTotalGb: number;
  memoryPressure: 'Normal' | 'Warn' | 'Critical' | string;
  batteryPercent: number | null;
  batteryCharging: boolean;
  batteryTempC: number | null;
  uptimeSeconds: number;
  downloadKbPerSec: number;
  uploadKbPerSec: number;
  keepAwakeActive: boolean;
  masterVolume: number;
  masterMuted: boolean;
  darkMode: boolean;
  activeWindowTitle: string;
  mediaSession: MediaSessionInfo | null;
  disks: DiskVolume[];
  networks: NetAdapter[];
  topProcesses: ProcessEntry[];
}

export interface AppAudioSession {
  id: string;
  pid: number;
  name: string;
  volume: number;
  muted: boolean;
}

export interface OpenWindowEntry {
  hwnd: number;
  pid: number;
  title: string;
  processName: string;
}

export interface ListeningPortEntry {
  protocol: string;
  localAddress: string;
  port: number;
  pid: number;
  processName: string;
}

export interface JunkCategory {
  id: string;
  label: string;
  path: string;
  sizeMb: number;
  fileCount: number;
}

export interface InstalledAppEntry {
  name: string;
  publisher: string;
  version: string;
  installLocation: string;
  uninstallString: string;
}

export interface WingetPackage {
  name: string;
  id: string;
  version: string;
  availableVersion: string | null;
}

export interface PickedColorResult {
  hex: string;
  r: number;
  g: number;
  b: number;
  x: number;
  y: number;
}

export interface ScreenshotResult {
  path: string;
  fileName: string;
  width: number;
  height: number;
  sizeKb: number;
}

export interface ClipboardItem {
  id: string;
  text: string;
  kind: 'text' | 'url' | 'code' | 'color';
  source: string;
  timestamp: number;
  pinned?: boolean;
}

export interface ShelfDropFile {
  name: string;
  path: string;
  kind: string;
  sizeLabel: string;
}

export interface ShelfItem {
  id: string;
  name: string;
  path: string;
  kind: 'file' | 'image' | 'pdf' | 'code' | 'archive';
  sizeLabel: string;
  addedAt: number;
}

export interface ScratchpadNote {
  id: string;
  title: string;
  body: string;
  updatedAt: number;
}

export interface TextSnippet {
  id: string;
  trigger: string;
  expansion: string;
  category: string;
}

export interface DynamicIslandAgent {
  id: string;
  name: string;
  provider: 'Claude' | 'Codex' | 'Gemini';
  task: string;
  status: 'running' | 'done' | 'waiting';
  elapsedSec: number;
}

export interface VorssaintSettings {
  language: LocaleCode;
  appearance: AppAppearanceMode;
  accentHex: string;
  islandVisible: boolean;
  islandPinned: boolean;
  islandSilhouette: 'pill' | 'notch';
  islandOpenOnHover: boolean;
  islandMascotEnabled: boolean;
  islandLiquidGlass: boolean;
  keepDisplayOn: boolean;
  brightnessLevel: number;
  nightLightWarmth: number;
  autoCleanUrls: boolean;
  clipboardMaxItems: number;
  installedFeatures: Record<string, boolean>;
  panelVisibleSections: Record<TrayPanelSectionId, boolean>;
}

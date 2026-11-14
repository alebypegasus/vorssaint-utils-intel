export type LocaleCode = 'en' | 'pt' | 'es';
export type ThemeMode = 'dark' | 'light';

export type PanelTabId =
  | 'keepAwake'
  | 'mixer'
  | 'system'
  | 'network'
  | 'disk'
  | 'power'
  | 'fanControl'
  | 'brightness'
  | 'utilities'
  | 'controls'
  | 'wallpaper';

export type UtilitySubview =
  | 'home'
  | 'metricCPU'
  | 'metricGPU'
  | 'metricMemory'
  | 'clipboard'
  | 'cleaner'
  | 'winget'
  | 'media'
  | 'windowLayout'
  | 'uninstaller'
  | 'portManager'
  | 'killProcess'
  | 'urlCleaner'
  | 'appUpdates';

export type SettingsSectionId =
  | 'general'
  | 'features'
  | 'energy'
  | 'monitor'
  | 'sound'
  | 'mouseKeyboard'
  | 'switcher'
  | 'windowLayout'
  | 'quitOnClose'
  | 'clipboard'
  | 'textSnippets'
  | 'shelf'
  | 'dynamicIsland'
  | 'tools'
  | 'shortcuts'
  | 'backup'
  | 'about';

export type OverlayId =
  | 'commandBar'
  | 'appSwitcher'
  | 'radialMenu'
  | 'fileShelf'
  | 'scratchpad'
  | 'screenCapture'
  | 'cleaningMode'
  | 'about';

export type FeatureGroupId =
  | 'windowsDock'
  | 'mouseKeyboard'
  | 'clipboardFiles'
  | 'sound'
  | 'energyDisplay'
  | 'tools'
  | 'dynamicIsland'
  | 'monitor';

export type PermissionKey =
  | 'accessibility'
  | 'screenRecording'
  | 'fullDiskAccess'
  | 'notifications'
  | 'audioCapture'
  | 'microphone'
  | 'camera'
  | 'appManagement'
  | 'calendar';

export interface FeatureDefinition {
  id: string;
  group: FeatureGroupId;
  name: Record<LocaleCode, string>;
  description: Record<LocaleCode, string>;
  icon: string;
  moduleTab?: PanelTabId;
  runtimeBadge: 'keyboard' | 'mouse' | 'audio' | 'idle' | 'beta';
  isBeta?: boolean;
  permission?: PermissionKey;
  defaultInstalled: boolean;
}

export interface BundleDefinition {
  id: 'essentials' | 'windows' | 'battery' | 'developer';
  name: Record<LocaleCode, string>;
  description: Record<LocaleCode, string>;
  icon: string;
  featureIds: string[];
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
  disks: DiskVolume[];
  networks: NetAdapter[];
  topProcesses: ProcessEntry[];
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
  availableVersion?: string | null;
}

export interface MixerAppChannel {
  id: string;
  name: string;
  outputDevice: string;
  volume: number; // 0..200 (boost > 100)
  muted: boolean;
  color: string;
  active: boolean;
}

export interface ClipboardItem {
  id: string;
  text: string;
  sourceApp: string;
  timestamp: string;
  pinned: boolean;
}

export interface TextSnippet {
  id: string;
  trigger: string;
  expansion: string;
  category: string;
}

export interface ShelfItem {
  id: string;
  name: string;
  kind: 'file' | 'image' | 'link' | 'snippet';
  sizeLabel: string;
  addedAt: string;
}

export interface ScratchpadNote {
  id: string;
  title: string;
  content: string;
  updatedAt: string;
}

export interface DynamicIslandAgent {
  id: 'claude' | 'codex' | 'copilot';
  name: string;
  model: string;
  state: 'active' | 'idle';
  tokensUsed: number;
  sessionCostUsd: number;
  taskSummary: string;
}

export interface ControlToggleState {
  switcher: boolean;
  switcherLargeIcons: boolean;
  taskbarPreview: boolean;
  taskbarClickMinimize: boolean;
  windowMaximizer: boolean;
  windowEdgeSnap: boolean;
  autoQuitOnClose: boolean;
  scrollInverter: boolean;
  smoothScroll: boolean;
  linearScroll: boolean;
  focusFollowsMouse: boolean;
  mouseAccelDisabled: boolean;
  clipboardHistory: boolean;
  explorerCutPaste: boolean;
  explorerBatchRename: boolean;
  urlAutoClean: boolean;
  audioPriority: boolean;
  micMuteShortcut: boolean;
  musicBlock: boolean;
  keepAwakeDisplay: boolean;
  extraBrightness: boolean;
  bluetoothSleep: boolean;
  dynamicIslandEnabled: boolean;
  dynamicIslandLyrics: boolean;
  dynamicIslandEqualizer: boolean;
  dynamicIslandAgents: boolean;
  dynamicIslandMascot: boolean;
  separateMenuMetrics: boolean;
  launchAtStartup: boolean;
}

export interface AppSettings {
  theme: ThemeMode;
  locale: LocaleCode;
  activeTab: PanelTabId;
  activeSubview: UtilitySubview;
  activeSettingsSection: SettingsSectionId;
  installedFeatures: Record<string, boolean>;
  toggles: ControlToggleState;
  keepAwakeDuration: 'indefinite' | '30m' | '1h' | '2h' | '4h';
  brightnessLevel: number;
  nightWarmth: number;
  softwareDimming: number;
  fanPreset: 'auto' | 'silent' | 'balanced' | 'performance';
  fanRpm: number;
  wallpaperCategory: 'studio' | 'architecture' | 'landscape' | 'dynamic';
  selectedWallpaperId: string;
  shortcuts: Record<string, string>;
}

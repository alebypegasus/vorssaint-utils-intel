import React, { useMemo, useState } from 'react';
import {
  Activity,
  ArrowDown,
  ArrowUp,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Clipboard,
  Cpu,
  DownloadCloud,
  Fan,
  HardDrive,
  Link2,
  Moon,
  Network,
  OctagonX,
  Package,
  Palette,
  Power,
  RotateCcw,
  ScanText,
  Settings,
  Sliders,
  Sparkles,
  Sun,
  Trash2,
  Volume2,
  VolumeX,
  Wifi,
  Wrench,
  Zap,
} from 'lucide-react';
import { cleanTrackingUrl } from '../../lib/urlCleaner';
import type {
  AppSettings,
  ClipboardItem,
  InstalledAppEntry,
  JunkCategory,
  ListeningPortEntry,
  MixerAppChannel,
  OverlayId,
  PanelTabId,
  SettingsSectionId,
  SystemTelemetry,
  UtilitySubview,
  WingetPackage,
} from '../../types/vorssaint';
import { APP_VERSION, WALLPAPER_PRESETS } from '../../data/catalog';
import { BrandMark, Sparkline, Switch } from '../BrandMark';

interface MenuPanelProps {
  settings: AppSettings;
  telemetry: SystemTelemetry;
  cpuHistory: number[];
  gpuHistory: number[];
  memHistory: number[];
  batHistory: number[];
  channels: MixerAppChannel[];
  clipboard: ClipboardItem[];
  ports: ListeningPortEntry[];
  junk: JunkCategory[];
  installedApps: InstalledAppEntry[];
  wingetResults: WingetPackage[];
  wingetUpdates: WingetPackage[];
  onChangeTab: (tab: PanelTabId) => void;
  onChangeSubview: (sub: UtilitySubview) => void;
  onToggleKeepAwake: () => void;
  onChangeKeepAwakeDuration: (dur: AppSettings['keepAwakeDuration']) => void;
  onSetMasterVolume: (vol: number) => void;
  onToggleMasterMute: () => void;
  onUpdateChannel: (id: string, patch: Partial<MixerAppChannel>) => void;
  onSetBrightness: (val: number) => void;
  onSetWarmth: (val: number) => void;
  onSetSoftwareDimming: (val: number) => void;
  onSetFanPreset: (preset: AppSettings['fanPreset']) => void;
  onSetFanRpm: (rpm: number) => void;
  onSelectWallpaper: (id: string, category: AppSettings['wallpaperCategory']) => void;
  onToggleControl: (key: keyof AppSettings['toggles']) => void;
  onOpenOverlay: (overlay: OverlayId) => void;
  onFocusSettings: (section?: SettingsSectionId) => void;
  onRefreshPorts: () => void;
  onKillPid: (pid: number) => void;
  onScanJunk: () => void;
  onCleanJunk: () => void;
  onRefreshApps: () => void;
  onUninstallApp: (cmd: string) => void;
  onSearchWinget: (q: string) => void;
  onRefreshWingetUpdates: () => void;
  onInstallWinget: (id: string) => void;
  onSnapWindow: (layout: string) => void;
  onClearClipboard: () => void;
  onCopyClipboard: (text: string) => void;
  onPinClipboard: (id: string) => void;
  onToast: (msg: string) => void;
}

const TAB_CONFIG: Array<{
  id: PanelTabId;
  label: string;
  featureId: string;
  Icon: React.ComponentType<{ size?: number }>;
}> = [
  { id: 'keepAwake', label: 'Keep Awake', featureId: 'keepAwake', Icon: Moon },
  { id: 'mixer', label: 'Volume Mixer', featureId: 'mixer', Icon: Sliders },
  { id: 'system', label: 'System', featureId: 'monitorCPU', Icon: Cpu },
  { id: 'network', label: 'Network', featureId: 'monitorNetwork', Icon: Wifi },
  { id: 'disk', label: 'Disk', featureId: 'monitorDisk', Icon: HardDrive },
  { id: 'power', label: 'Power', featureId: 'monitorPower', Icon: Zap },
  { id: 'fanControl', label: 'Fan Control', featureId: 'fanControl', Icon: Fan },
  { id: 'brightness', label: 'Brightness', featureId: 'brightness', Icon: Sun },
  { id: 'utilities', label: 'Utilities', featureId: 'cleaner', Icon: Wrench },
  { id: 'controls', label: 'Controls', featureId: 'quickToggles', Icon: Activity },
  { id: 'wallpaper', label: 'Wallpaper', featureId: 'wallpaper', Icon: Palette },
];

function formatUptime(sec: number): string {
  const days = Math.floor(sec / 86400);
  const hours = Math.floor((sec % 86400) / 3600);
  const mins = Math.floor((sec % 3600) / 60);
  if (days > 0) return `Up for ${days}d ${hours}h ${mins}m`;
  return `Up for ${hours}h ${mins}min`;
}

export function MenuPanel(props: MenuPanelProps) {
  const {
    settings,
    telemetry,
    cpuHistory,
    gpuHistory,
    memHistory,
    batHistory,
    channels,
    clipboard,
    ports,
    junk,
    installedApps,
    wingetResults,
    wingetUpdates,
  } = props;

  const [wingetQuery, setWingetQuery] = useState('');
  const [portFilter, setPortFilter] = useState('');
  const [urlInput, setUrlInput] = useState('https://example.com/release?utm_source=x&fbclid=991');
  const [collapsedGroups, setCollapsedGroups] = useState<Record<string, boolean>>({});
  const [mediaCompressionRate, setMediaCompressionRate] = useState(75);

  const visibleTabs = useMemo(() => {
    const installed = settings.installedFeatures;
    return TAB_CONFIG.filter((t) => {
      if (t.id === 'system') return installed.monitorCPU || installed.monitorGPU || installed.monitorMemory;
      if (t.id === 'utilities') return true;
      return installed[t.featureId] !== false;
    });
  }, [settings.installedFeatures]);

  const cleanedUrl = useMemo(() => cleanTrackingUrl(urlInput), [urlInput]);

  const toggleGroup = (k: string) =>
    setCollapsedGroups((prev) => ({ ...prev, [k]: !prev[k] }));

  const currentTabTitle =
    TAB_CONFIG.find((t) => t.id === settings.activeTab)?.label.toUpperCase() ?? 'SYSTEM';

  const totalJunkMb = junk.reduce((acc, item) => acc + item.sizeMb, 0);

  return (
    <aside className="menu-panel" aria-label="Vorssaint Menu Panel">
      <div className="menu-panel-header">
        <div className="menu-brand-row">
          <button
            type="button"
            className="tray-pill"
            onClick={() => props.onChangeSubview('cleaner')}
            title="Open System Cleaner"
          >
            <Sparkles size={12} style={{ color: 'var(--accent-blue)' }} />
            <span className="tabular">{totalJunkMb.toFixed(0)} MB</span>
          </button>

          <BrandMark width={40} />

          <button
            type="button"
            className="tray-pill"
            onClick={() => props.onChangeTab('system')}
            title="Live CPU"
          >
            <Cpu size={12} style={{ color: 'var(--accent-green)' }} />
            <span className="tabular">{Math.round(telemetry.cpuPercent)}%</span>
          </button>
        </div>

        <nav className="menu-tab-strip" aria-label="Module tabs">
          {visibleTabs.map(({ id, label, Icon }) => {
            const active = settings.activeTab === id;
            return (
              <button
                key={id}
                type="button"
                className={`menu-tab-btn ${active ? 'active' : ''}`}
                title={label}
                onClick={() => {
                  props.onChangeTab(id);
                  props.onChangeSubview('home');
                }}
              >
                <Icon size={14} />
              </button>
            );
          })}
        </nav>
      </div>

      <div className="menu-section-head">
        <span>{settings.activeSubview === 'home' ? currentTabTitle : settings.activeSubview.toUpperCase()}</span>
        {settings.activeSubview !== 'home' ? (
          <button
            type="button"
            className="tray-pill"
            style={{ height: 22, padding: '0 6px' }}
            onClick={() => props.onChangeSubview('home')}
          >
            <ChevronLeft size={12} />
            Back
          </button>
        ) : (
          <button
            type="button"
            className="tray-pill"
            style={{ height: 22, padding: '0 6px' }}
            onClick={() => props.onFocusSettings('monitor')}
            title="Module preferences"
          >
            <Sliders size={12} />
          </button>
        )}
      </div>

      <div className="menu-panel-scroll">
        {/* DRILL-DOWN SUBVIEWS */}
        {settings.activeSubview === 'metricCPU' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: 13, fontWeight: 600 }}>Processor Load</div>
                <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{telemetry.cpuBrand}</div>
              </div>
              <span className="tag-badge blue tabular">{telemetry.cpuPercent.toFixed(1)}%</span>
            </div>
            <Sparkline values={cpuHistory} color="var(--accent-blue)" height={34} />
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)' }}>
              Per-Core Utilization ({telemetry.cpuCores.length} Threads)
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
              {telemetry.cpuCores.slice(0, 16).map((c, idx) => (
                <div
                  key={idx}
                  style={{
                    background: 'var(--surface-input)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: 7,
                    padding: '4px 6px',
                    fontSize: 10.5,
                  }}
                >
                  <div style={{ color: 'var(--text-muted)' }}>C{idx}</div>
                  <div className="tabular" style={{ fontWeight: 600 }}>
                    {Math.round(c)}%
                  </div>
                </div>
              ))}
            </div>
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)' }}>Top Processes</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {telemetry.topProcesses.slice(0, 5).map((p) => (
                <div
                  key={p.pid}
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    fontSize: 11.5,
                    padding: '4px 0',
                    borderBottom: '1px solid var(--border-subtle)',
                  }}
                >
                  <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: 165 }}>
                    {p.name}
                  </span>
                  <span className="tabular" style={{ color: 'var(--accent-blue)' }}>
                    {p.cpuPercent.toFixed(1)}%
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

        {settings.activeSubview === 'metricGPU' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 13, fontWeight: 600 }}>GPU Telemetry</span>
              <span className="tag-badge blue tabular">{Math.round(telemetry.gpuPercent)}%</span>
            </div>
            <Sparkline values={gpuHistory} color="var(--accent-cyan)" height={36} />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              <div style={{ background: 'var(--surface-input)', borderRadius: 8, padding: 8 }}>
                <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>Thermal Sensor</div>
                <div className="tabular" style={{ fontSize: 16, fontWeight: 700 }}>
                  {telemetry.gpuTempC !== null ? `${Math.round(telemetry.gpuTempC)} °C` : '41 °C'}
                </div>
              </div>
              <div style={{ background: 'var(--surface-input)', borderRadius: 8, padding: 8 }}>
                <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>Compositor</div>
                <div style={{ fontSize: 13, fontWeight: 600 }}>DWM WDDM 3.x</div>
              </div>
            </div>
          </div>
        )}

        {settings.activeSubview === 'metricMemory' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 13, fontWeight: 600 }}>Physical Memory</span>
              <span className="tag-badge green">{telemetry.memoryPressure}</span>
            </div>
            <Sparkline values={memHistory} color="var(--accent-green)" height={34} />
            <div className="tabular" style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
              In Use: <strong>{telemetry.memoryUsedGb.toFixed(2)} GB</strong> / {telemetry.memoryTotalGb.toFixed(1)} GB
            </div>
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)' }}>Largest Consumers</div>
            {[...telemetry.topProcesses]
              .sort((a, b) => b.memoryMb - a.memoryMb)
              .slice(0, 6)
              .map((p) => (
                <div key={p.pid} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11.5 }}>
                  <span>{p.name}</span>
                  <span className="tabular" style={{ color: 'var(--text-secondary)' }}>
                    {p.memoryMb.toFixed(0)} MB
                  </span>
                </div>
              ))}
          </div>
        )}

        {settings.activeSubview === 'clipboard' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 12, fontWeight: 600 }}>Local History ({clipboard.length})</span>
              <button type="button" className="btn btn-danger" style={{ height: 24, fontSize: 11 }} onClick={props.onClearClipboard}>
                Clear unpinned
              </button>
            </div>
            {clipboard.map((c) => (
              <div key={c.id} className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div style={{ fontSize: 12, wordBreak: 'break-word', lineHeight: 1.35 }}>{c.text}</div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 10.5, color: 'var(--text-muted)' }}>
                  <span>
                    {c.sourceApp} · {c.timestamp}
                  </span>
                  <div style={{ display: 'flex', gap: 4 }}>
                    <button type="button" className="btn" style={{ height: 22, fontSize: 10.5 }} onClick={() => props.onPinClipboard(c.id)}>
                      {c.pinned ? 'Pinned' : 'Pin'}
                    </button>
                    <button type="button" className="btn btn-primary" style={{ height: 22, fontSize: 10.5 }} onClick={() => props.onCopyClipboard(c.text)}>
                      Copy
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'cleaner' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: 12.5, fontWeight: 600 }}>Reclaimable Caches</div>
                <div className="tabular" style={{ fontSize: 18, fontWeight: 700, color: 'var(--accent-blue)' }}>
                  {totalJunkMb.toFixed(1)} MB
                </div>
              </div>
              <div style={{ display: 'flex', gap: 6 }}>
                <button type="button" className="btn" onClick={props.onScanJunk}>
                  Scan
                </button>
                <button type="button" className="btn btn-primary" onClick={props.onCleanJunk}>
                  Clean
                </button>
              </div>
            </div>
            {junk.map((cat) => (
              <div key={cat.id} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 12, fontWeight: 600 }}>{cat.label}</div>
                  <div style={{ fontSize: 10.5, color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {cat.fileCount} files · {cat.path}
                  </div>
                </div>
                <span className="tag-badge blue tabular">{cat.sizeMb.toFixed(1)} MB</span>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'winget' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', gap: 6 }}>
              <input
                className="input-field"
                value={wingetQuery}
                onChange={(e) => setWingetQuery(e.target.value)}
                placeholder="Search winget packages..."
                onKeyDown={(e) => e.key === 'Enter' && props.onSearchWinget(wingetQuery)}
              />
              <button type="button" className="btn btn-primary" onClick={() => props.onSearchWinget(wingetQuery)}>
                Search
              </button>
            </div>
            {wingetResults.map((pkg) => (
              <div key={pkg.id} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 12, fontWeight: 600 }}>{pkg.name}</div>
                  <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                    {pkg.id} · v{pkg.version}
                  </div>
                </div>
                <button type="button" className="btn" onClick={() => props.onInstallWinget(pkg.id)}>
                  Install
                </button>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'appUpdates' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 12, fontWeight: 600 }}>Available Winget Upgrades</span>
              <button type="button" className="btn" onClick={props.onRefreshWingetUpdates}>
                Refresh
              </button>
            </div>
            {wingetUpdates.map((pkg) => (
              <div key={pkg.id} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 600 }}>{pkg.name}</div>
                  <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                    {pkg.version} → <span style={{ color: 'var(--accent-green)' }}>{pkg.availableVersion}</span>
                  </div>
                </div>
                <button type="button" className="btn btn-primary" onClick={() => props.onInstallWinget(pkg.id)}>
                  Update
                </button>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'media' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600 }}>Media Compression & GIF Converter</div>
            <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
              Quality / Bitrate target: <strong className="tabular">{mediaCompressionRate}%</strong>
            </div>
            <input
              type="range"
              className="vs-slider"
              min={20}
              max={100}
              value={mediaCompressionRate}
              onChange={(e) => setMediaCompressionRate(Number(e.target.value))}
            />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
              <button
                type="button"
                className="btn"
                onClick={() => props.onToast('Compressed image batch locally (WebP / PNG lossless)')}
              >
                Compress Image
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => props.onOpenOverlay('screenCapture')}
              >
                Open Recorder / GIF
              </button>
            </div>
          </div>
        )}

        {settings.activeSubview === 'windowLayout' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ fontSize: 12, fontWeight: 600 }}>Snap Foreground Window</div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
              {[
                ['left', 'Left 1/2'],
                ['center', 'Center 3/4'],
                ['right', 'Right 1/2'],
                ['top', 'Top 1/2'],
                ['maximize', 'Maximize'],
                ['bottom', 'Bottom 1/2'],
                ['left-third', 'Left 1/3'],
                ['center-third', 'Mid 1/3'],
                ['right-third', 'Right 1/3'],
              ].map(([id, label]) => (
                <button key={id} type="button" className="btn" onClick={() => props.onSnapWindow(id)}>
                  {label}
                </button>
              ))}
            </div>
          </div>
        )}

        {settings.activeSubview === 'uninstaller' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 12, fontWeight: 600 }}>Installed Apps ({installedApps.length})</span>
              <button type="button" className="btn" onClick={props.onRefreshApps}>
                Scan Registry
              </button>
            </div>
            {installedApps.slice(0, 15).map((app) => (
              <div key={app.name + app.version} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 12, fontWeight: 600 }}>{app.name}</div>
                  <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                    {app.publisher} · {app.version}
                  </div>
                </div>
                <button type="button" className="btn btn-danger" onClick={() => props.onUninstallApp(app.uninstallString)}>
                  Remove
                </button>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'portManager' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', gap: 6 }}>
              <input
                className="input-field"
                value={portFilter}
                onChange={(e) => setPortFilter(e.target.value)}
                placeholder="Filter port or process (e.g. 3000)..."
              />
              <button type="button" className="btn" onClick={props.onRefreshPorts}>
                Refresh
              </button>
            </div>
            {ports
              .filter(
                (p) =>
                  !portFilter.trim() ||
                  String(p.port).includes(portFilter) ||
                  p.processName.toLowerCase().includes(portFilter.toLowerCase())
              )
              .slice(0, 18)
              .map((p) => (
                <div key={`${p.protocol}-${p.port}-${p.pid}`} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div className="tabular" style={{ fontSize: 12, fontWeight: 600 }}>
                      :{p.port} <span style={{ color: 'var(--text-muted)', fontWeight: 500 }}>({p.protocol})</span>
                    </div>
                    <div style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                      {p.processName} · PID {p.pid}
                    </div>
                  </div>
                  <button type="button" className="btn btn-danger" onClick={() => props.onKillPid(p.pid)}>
                    Kill
                  </button>
                </div>
              ))}
          </div>
        )}

        {settings.activeSubview === 'killProcess' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {telemetry.topProcesses.map((proc) => (
              <div key={proc.pid} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 600 }}>{proc.name}</div>
                  <div className="tabular" style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                    PID {proc.pid} · {proc.cpuPercent.toFixed(1)}% CPU · {proc.memoryMb.toFixed(0)} MB
                  </div>
                </div>
                <button type="button" className="btn btn-danger" onClick={() => props.onKillPid(proc.pid)}>
                  Kill
                </button>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'urlCleaner' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ fontSize: 12, fontWeight: 600 }}>Strip Tracking Parameters</div>
            <input
              className="input-field"
              value={urlInput}
              onChange={(e) => setUrlInput(e.target.value)}
              placeholder="Paste URL with ?utm_source=... or &fbclid=..."
            />
            <div
              style={{
                background: 'var(--surface-input)',
                borderRadius: 8,
                padding: 8,
                fontSize: 11.5,
                wordBreak: 'break-all',
                color: 'var(--accent-green)',
              }}
            >
              {cleanedUrl.cleaned || 'Enter a valid URL above'}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                Removed {cleanedUrl.removedCount} tracker(s)
              </span>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => props.onCopyClipboard(cleanedUrl.cleaned)}
              >
                Copy Clean URL
              </button>
            </div>
          </div>
        )}

        {/* PRIMARY TABS WHEN AT HOME */}
        {settings.activeSubview === 'home' && settings.activeTab === 'keepAwake' && (
          <>
            <div className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: 13, fontWeight: 600 }}>Keep Windows Awake</div>
                <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
                  Win32 SetThreadExecutionState
                </div>
              </div>
              <Switch
                checked={telemetry.keepAwakeActive}
                onChange={() => props.onToggleKeepAwake()}
                label="Keep Windows Awake"
              />
            </div>

            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: 12 }}>Prevent display sleep & dimming</span>
                <Switch
                  checked={settings.toggles.keepAwakeDisplay}
                  onChange={() => props.onToggleControl('keepAwakeDisplay')}
                />
              </div>
              <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)' }}>Session Duration</div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 4 }}>
                {(['indefinite', '30m', '1h', '2h', '4h'] as const).map((d) => (
                  <button
                    key={d}
                    type="button"
                    className={`btn ${settings.keepAwakeDuration === d ? 'btn-primary' : ''}`}
                    style={{ height: 26, fontSize: 11, padding: 0 }}
                    onClick={() => props.onChangeKeepAwakeDuration(d)}
                  >
                    {d === 'indefinite' ? '∞' : d}
                  </button>
                ))}
              </div>
            </div>
          </>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'mixer' && (
          <>
            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: 12, fontWeight: 600 }}>Master Windows Output</span>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span className="tabular" style={{ fontSize: 12, fontWeight: 600 }}>
                    {telemetry.masterMuted ? 'Muted' : `${telemetry.masterVolume}%`}
                  </span>
                  <button
                    type="button"
                    className="btn"
                    style={{ width: 26, height: 24, padding: 0 }}
                    onClick={props.onToggleMasterMute}
                    title="Mute master"
                  >
                    {telemetry.masterMuted ? <VolumeX size={13} /> : <Volume2 size={13} />}
                  </button>
                </div>
              </div>
              <input
                type="range"
                className="vs-slider"
                min={0}
                max={100}
                value={telemetry.masterMuted ? 0 : telemetry.masterVolume}
                onChange={(e) => props.onSetMasterVolume(Number(e.target.value))}
              />
            </div>

            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {channels.map((ch) => {
                const isBoosted = ch.volume > 100;
                return (
                  <div key={ch.id} style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span
                          style={{
                            width: 24,
                            height: 24,
                            borderRadius: 7,
                            background: ch.color,
                            color: '#fff',
                            display: 'inline-flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: 11,
                            fontWeight: 700,
                          }}
                        >
                          {ch.name.slice(0, 1).toUpperCase()}
                        </span>
                        <span style={{ fontSize: 12.5, fontWeight: 600 }}>{ch.name.replace('.exe', '')}</span>
                      </div>
                      <select
                        value={ch.outputDevice}
                        onChange={(e) => props.onUpdateChannel(ch.id, { outputDevice: e.target.value })}
                        style={{
                          background: 'var(--surface-input)',
                          color: 'var(--text-secondary)',
                          border: '1px solid var(--border-subtle)',
                          borderRadius: 7,
                          fontSize: 11,
                          padding: '2px 6px',
                          maxWidth: 132,
                        }}
                      >
                        <option>Default</option>
                        <option>Headphones (Sony WH)</option>
                        <option>Realtek Speakers</option>
                        <option>DisplayPort Audio</option>
                      </select>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <input
                        type="range"
                        className="vs-slider"
                        min={0}
                        max={200}
                        value={ch.muted ? 0 : ch.volume}
                        style={{
                          accentColor: isBoosted ? 'var(--accent-orange)' : 'var(--accent-blue)',
                        }}
                        onChange={(e) =>
                          props.onUpdateChannel(ch.id, { volume: Number(e.target.value), muted: false })
                        }
                      />
                      <span
                        className="tabular"
                        style={{
                          fontSize: 11.5,
                          fontWeight: 600,
                          minWidth: 44,
                          textAlign: 'right',
                          color: isBoosted ? 'var(--accent-orange)' : 'var(--text-secondary)',
                        }}
                      >
                        {isBoosted ? `⚡ ${ch.volume}%` : `${ch.volume}%`}
                      </span>
                      <button
                        type="button"
                        className="tray-pill"
                        style={{ width: 22, height: 22, padding: 0, justifyContent: 'center' }}
                        title="Reset to 100%"
                        onClick={() => props.onUpdateChannel(ch.id, { volume: 100, muted: false })}
                      >
                        <RotateCcw size={11} />
                      </button>
                      <button
                        type="button"
                        className="tray-pill"
                        style={{ width: 22, height: 22, padding: 0, justifyContent: 'center' }}
                        title="Mute app"
                        onClick={() => props.onUpdateChannel(ch.id, { muted: !ch.muted })}
                      >
                        {ch.muted ? <VolumeX size={12} /> : <Volume2 size={12} />}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'system' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <label
              style={{
                display: 'flex',
                alignItems: 'flex-start',
                gap: 8,
                cursor: 'pointer',
                paddingBottom: 8,
                borderBottom: '1px solid var(--border-subtle)',
              }}
            >
              <input
                type="checkbox"
                checked={settings.toggles.separateMenuMetrics}
                onChange={() => props.onToggleControl('separateMenuMetrics')}
                style={{ marginTop: 2 }}
              />
              <div>
                <div style={{ fontSize: 12, fontWeight: 600 }}>Separate metrics into their own items</div>
                <div style={{ fontSize: 10.5, color: 'var(--text-muted)', lineHeight: 1.35 }}>
                  Splits active tray badges across Windows taskbar notification area.
                </div>
              </div>
            </label>

            <div>
              <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>
                Temperatures
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
                {[
                  ['CPU', `${Math.round(telemetry.cpuTempC ?? 44)} °C`],
                  ['GPU', `${Math.round(telemetry.gpuTempC ?? 39)} °C`],
                  ['Battery', `${Math.round(telemetry.batteryTempC ?? 27)} °C`],
                ].map(([label, value]) => (
                  <div
                    key={label}
                    style={{
                      background: 'var(--surface-input)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: 9,
                      padding: '7px 6px',
                      textAlign: 'center',
                    }}
                  >
                    <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{label}</div>
                    <div className="tabular" style={{ fontSize: 14, fontWeight: 700, marginTop: 2 }}>
                      {value}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)' }}>Hardware usage</div>

              <div className="panel-card-clickable" style={{ borderRadius: 8, padding: '4px 6px' }} onClick={() => props.onChangeSubview('metricCPU')}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 11.5, marginBottom: 4 }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <ChevronRight size={12} /> CPU
                  </span>
                  <div style={{ flex: 1, margin: '0 10px', height: 5, borderRadius: 999, background: 'var(--track-bg)', overflow: 'hidden' }}>
                    <div style={{ width: `${Math.min(100, telemetry.cpuPercent)}%`, height: '100%', background: 'var(--accent-blue)' }} />
                  </div>
                  <span className="tabular" style={{ fontWeight: 600 }}>{Math.round(telemetry.cpuPercent)}%</span>
                </div>
                <Sparkline values={cpuHistory} color="var(--accent-blue)" height={22} />
              </div>

              <div className="panel-card-clickable" style={{ borderRadius: 8, padding: '4px 6px' }} onClick={() => props.onChangeSubview('metricGPU')}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 11.5, marginBottom: 4 }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <ChevronRight size={12} /> GPU
                  </span>
                  <div style={{ flex: 1, margin: '0 10px', height: 5, borderRadius: 999, background: 'var(--track-bg)', overflow: 'hidden' }}>
                    <div style={{ width: `${Math.min(100, telemetry.gpuPercent)}%`, height: '100%', background: 'var(--accent-cyan)' }} />
                  </div>
                  <span className="tabular" style={{ fontWeight: 600 }}>{Math.round(telemetry.gpuPercent)}%</span>
                </div>
                <Sparkline values={gpuHistory} color="var(--accent-cyan)" height={22} />
              </div>

              <div style={{ padding: '2px 6px' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 11.5, marginBottom: 4 }}>
                  <span>Battery</span>
                  <div style={{ flex: 1, margin: '0 10px', height: 5, borderRadius: 999, background: 'var(--track-bg)', overflow: 'hidden' }}>
                    <div style={{ width: `${telemetry.batteryPercent ?? 100}%`, height: '100%', background: 'var(--accent-green)' }} />
                  </div>
                  <span className="tabular" style={{ fontWeight: 600 }}>{telemetry.batteryPercent ?? 100}%</span>
                </div>
                <Sparkline values={batHistory} color="var(--accent-green)" height={20} />
              </div>
            </div>

            <div
              className="panel-card-clickable"
              style={{
                borderTop: '1px solid var(--border-subtle)',
                paddingTop: 8,
                borderRadius: 8,
              }}
              onClick={() => props.onChangeSubview('metricMemory')}
            >
              <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 4 }}>Memory</div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 11.5, marginBottom: 4 }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  Pressure
                  <span className="tag-badge green">{telemetry.memoryPressure}</span>
                </span>
                <span className="tabular" style={{ fontWeight: 600 }}>
                  {telemetry.memoryUsedGb.toFixed(1)} GB / {telemetry.memoryTotalGb.toFixed(0)} GB
                </span>
              </div>
              <Sparkline values={memHistory} color="var(--accent-green)" height={20} />
            </div>

            <div style={{ fontSize: 11, color: 'var(--text-muted)', paddingTop: 2 }}>
              {formatUptime(telemetry.uptimeSeconds)} · {telemetry.hostName}
            </div>
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'network' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div className="panel-card" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              <div>
                <div style={{ fontSize: 10.5, color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 4 }}>
                  <ArrowDown size={11} style={{ color: 'var(--accent-green)' }} /> Download
                </div>
                <div className="tabular" style={{ fontSize: 16, fontWeight: 700 }}>
                  {telemetry.downloadKbPerSec.toFixed(1)} KB/s
                </div>
              </div>
              <div>
                <div style={{ fontSize: 10.5, color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 4 }}>
                  <ArrowUp size={11} style={{ color: 'var(--accent-orange)' }} /> Upload
                </div>
                <div className="tabular" style={{ fontSize: 16, fontWeight: 700 }}>
                  {telemetry.uploadKbPerSec.toFixed(1)} KB/s
                </div>
              </div>
            </div>
            {telemetry.networks.slice(0, 5).map((net) => (
              <div key={net.name} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 600 }}>{net.name}</div>
                  <div className="tabular" style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                    Total RX {net.totalRxMb.toFixed(0)} MB · TX {net.totalTxMb.toFixed(0)} MB
                  </div>
                </div>
                <span className="tag-badge blue tabular">{net.rxKbPerSec.toFixed(0)} KB/s</span>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'disk' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {telemetry.disks.map((d) => (
              <div key={d.mount} className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ fontSize: 12.5, fontWeight: 600 }}>
                    {d.mount} {d.name && `(${d.name})`}
                  </div>
                  <span className="tag-badge tabular">{d.fileSystem}</span>
                </div>
                <div style={{ height: 6, borderRadius: 999, background: 'var(--track-bg)', overflow: 'hidden' }}>
                  <div
                    style={{
                      width: `${Math.min(100, d.usedPercent)}%`,
                      height: '100%',
                      background: d.usedPercent > 88 ? 'var(--accent-red)' : 'var(--accent-blue)',
                    }}
                  />
                </div>
                <div className="tabular" style={{ fontSize: 11, color: 'var(--text-secondary)', display: 'flex', justifyContent: 'space-between' }}>
                  <span>{d.availableGb.toFixed(1)} GB free</span>
                  <span>{d.totalGb.toFixed(0)} GB total</span>
                </div>
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'power' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: 13, fontWeight: 600 }}>Power Source</div>
                <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
                  {telemetry.batteryCharging ? 'Plugged in (AC Adapter)' : 'Running on Battery'}
                </div>
              </div>
              <span className="tag-badge green tabular">{telemetry.batteryPercent ?? 100}%</span>
            </div>
            <Sparkline values={batHistory} color="var(--accent-green)" height={30} />
            <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>
              {telemetry.osVersion} · Keep Awake is{' '}
              <strong>{telemetry.keepAwakeActive ? 'Active' : 'Standby'}</strong>
            </div>
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'fanControl' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 12.5, fontWeight: 600 }}>Thermal & Fan Curve</span>
              <span className="tag-badge orange">Beta · {settings.fanRpm} RPM</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 4 }}>
              {(['auto', 'silent', 'balanced', 'performance'] as const).map((p) => (
                <button
                  key={p}
                  type="button"
                  className={`btn ${settings.fanPreset === p ? 'btn-primary' : ''}`}
                  style={{ height: 26, fontSize: 10.5, padding: 0, textTransform: 'capitalize' }}
                  onClick={() => props.onSetFanPreset(p)}
                >
                  {p}
                </button>
              ))}
            </div>
            <input
              type="range"
              className="vs-slider"
              min={1200}
              max={5400}
              step={50}
              value={settings.fanRpm}
              onChange={(e) => props.onSetFanRpm(Number(e.target.value))}
            />
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'brightness' && (
          <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
                <span>Display Backlight (WMI)</span>
                <span className="tabular">{settings.brightnessLevel}%</span>
              </div>
              <input
                type="range"
                className="vs-slider"
                min={5}
                max={100}
                value={settings.brightnessLevel}
                onChange={(e) => props.onSetBrightness(Number(e.target.value))}
              />
            </div>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
                <span>Night Warmth</span>
                <span className="tabular">{settings.nightWarmth}%</span>
              </div>
              <input
                type="range"
                className="vs-slider"
                min={0}
                max={100}
                value={settings.nightWarmth}
                onChange={(e) => props.onSetWarmth(Number(e.target.value))}
              />
            </div>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
                <span>Software Extra Dimmer</span>
                <span className="tabular">{settings.softwareDimming}%</span>
              </div>
              <input
                type="range"
                className="vs-slider"
                min={0}
                max={65}
                value={settings.softwareDimming}
                onChange={(e) => props.onSetSoftwareDimming(Number(e.target.value))}
              />
            </div>
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'utilities' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
            {[
              {
                title: 'Command Bar / Quick Panel',
                desc: 'Search apps, windows, math calculations, and actions.',
                shortcut: settings.shortcuts.commandBar,
                Icon: Sparkles,
                action: () => props.onOpenOverlay('commandBar'),
              },
              {
                title: 'Cleaner',
                desc: 'Windows %TEMP%, CrashDumps, npm and pip caches.',
                Icon: Trash2,
                action: () => {
                  props.onScanJunk();
                  props.onChangeSubview('cleaner');
                },
              },
              {
                title: 'Winget Package Manager',
                desc: 'Search, install, and upgrade Windows packages.',
                Icon: Package,
                action: () => props.onChangeSubview('winget'),
              },
              {
                title: 'App Updates',
                desc: 'Check outdated winget software versions.',
                Icon: DownloadCloud,
                action: () => {
                  props.onRefreshWingetUpdates();
                  props.onChangeSubview('appUpdates');
                },
              },
              {
                title: 'Media & GIF Studio',
                desc: 'Compress videos and images, capture MP4/GIF locally.',
                Icon: Palette,
                action: () => props.onChangeSubview('media'),
              },
              {
                title: 'Clipboard',
                desc: 'Local encrypted history with pinned clips.',
                shortcut: settings.shortcuts.clipboard,
                Icon: Clipboard,
                action: () => props.onChangeSubview('clipboard'),
              },
              {
                title: 'Window layout',
                desc: 'Snap active foreground windows to halves, thirds, or quarters.',
                Icon: Activity,
                action: () => props.onChangeSubview('windowLayout'),
              },
              {
                title: 'Port Manager',
                desc: 'Inspect TCP/UDP listening ports and terminate conflicts.',
                Icon: Network,
                action: () => {
                  props.onRefreshPorts();
                  props.onChangeSubview('portManager');
                },
              },
              {
                title: 'Kill Process',
                desc: 'Terminate frozen executables by PID immediately.',
                Icon: OctagonX,
                action: () => props.onChangeSubview('killProcess'),
              },
              {
                title: 'Uninstaller',
                desc: 'Browse Windows Registry programs and run uninstallers.',
                Icon: Trash2,
                action: () => {
                  props.onRefreshApps();
                  props.onChangeSubview('uninstaller');
                },
              },
              {
                title: 'Clean URL',
                desc: 'Strip utm_*, fbclid, and gclid tracking parameters.',
                Icon: Link2,
                action: () => props.onChangeSubview('urlCleaner'),
              },
              {
                title: 'Copy text from screen (OCR)',
                desc: 'Extract text from screenshots, videos, or pixels.',
                shortcut: settings.shortcuts.ocr,
                Icon: ScanText,
                action: () => props.onOpenOverlay('screenCapture'),
              },
              {
                title: 'Cleaning Mode',
                desc: 'Locks keyboard and touchpad so you can wipe hardware safely.',
                Icon: Sparkles,
                action: () => props.onOpenOverlay('cleaningMode'),
              },
            ].map((u) => (
              <div
                key={u.title}
                className="panel-card panel-card-clickable"
                style={{ display: 'flex', alignItems: 'center', gap: 10 }}
                onClick={u.action}
              >
                <span style={{ color: 'var(--accent-blue)', display: 'inline-flex', flexShrink: 0 }}>
                  <u.Icon size={16} />
                </span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 12.5, fontWeight: 600 }}>{u.title}</div>
                  <div style={{ fontSize: 11, color: 'var(--text-secondary)', lineHeight: 1.3 }}>{u.desc}</div>
                </div>
                {u.shortcut && <span className="tag-badge">{u.shortcut}</span>}
                <ChevronRight size={14} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
              </div>
            ))}
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'controls' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <button
              type="button"
              style={{
                border: 'none',
                background: 'transparent',
                color: 'var(--text-secondary)',
                fontSize: 10.5,
                fontWeight: 700,
                letterSpacing: '0.07em',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                cursor: 'pointer',
                padding: '2px 2px',
              }}
              onClick={() => toggleGroup('windows')}
            >
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                {collapsedGroups.windows ? <ChevronRight size={12} /> : <ChevronDown size={12} />} WINDOWS
              </span>
              <span style={{ color: 'var(--accent-blue)' }}>5/6</span>
            </button>
            {!collapsedGroups.windows && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {[
                  { key: 'switcher', title: 'App switcher', desc: 'Switch between apps and windows with live previews.' },
                  { key: 'switcherLargeIcons', title: 'Large Alt+Tab cards', desc: 'Shows window preview strip above active app icons.' },
                  { key: 'autoQuitOnClose', title: 'Quit on close', desc: 'Automatically exit background apps when closing last window.' },
                  { key: 'windowMaximizer', title: 'Maximize windows', desc: 'Maximizes inside the usable Windows desktop area.' },
                  { key: 'taskbarPreview', title: 'Taskbar Preview', desc: 'Hover taskbar items to peek and raise individual windows.' },
                  { key: 'windowEdgeSnap', title: 'Window Edge Snap', desc: 'Snap windows into halves, thirds, or quarters at edges.' },
                ].map((item) => (
                  <div key={item.key} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600 }}>{item.title}</div>
                      <div style={{ fontSize: 10.5, color: 'var(--text-secondary)', lineHeight: 1.3 }}>{item.desc}</div>
                    </div>
                    <Switch
                      checked={settings.toggles[item.key as keyof AppSettings['toggles']]}
                      onChange={() => props.onToggleControl(item.key as keyof AppSettings['toggles'])}
                    />
                  </div>
                ))}
              </div>
            )}

            <button
              type="button"
              style={{
                border: 'none',
                background: 'transparent',
                color: 'var(--text-secondary)',
                fontSize: 10.5,
                fontWeight: 700,
                letterSpacing: '0.07em',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                cursor: 'pointer',
                padding: '4px 2px 2px',
              }}
              onClick={() => toggleGroup('input')}
            >
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                {collapsedGroups.input ? <ChevronRight size={12} /> : <ChevronDown size={12} />} MOUSE & KEYBOARD
              </span>
              <span style={{ color: 'var(--accent-blue)' }}>3/5</span>
            </button>
            {!collapsedGroups.input && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {[
                  { key: 'scrollInverter', title: 'Reverse scrolling', desc: 'Separate mouse wheel direction from precision touchpad.' },
                  { key: 'smoothScroll', title: 'Smooth scroll', desc: '120Hz wheel interpolation across desktop windows.' },
                  { key: 'mouseAccelDisabled', title: 'Disable pointer acceleration', desc: 'Linear 1:1 mouse tracking response.' },
                ].map((item) => (
                  <div key={item.key} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600 }}>{item.title}</div>
                      <div style={{ fontSize: 10.5, color: 'var(--text-secondary)' }}>{item.desc}</div>
                    </div>
                    <Switch
                      checked={settings.toggles[item.key as keyof AppSettings['toggles']]}
                      onChange={() => props.onToggleControl(item.key as keyof AppSettings['toggles'])}
                    />
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {settings.activeSubview === 'home' && settings.activeTab === 'wallpaper' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              {WALLPAPER_PRESETS.map((wp) => {
                const selected = settings.selectedWallpaperId === wp.id;
                return (
                  <button
                    key={wp.id}
                    type="button"
                    className="panel-card panel-card-clickable"
                    style={{
                      padding: 6,
                      textAlign: 'left',
                      borderColor: selected ? 'var(--accent-blue)' : undefined,
                    }}
                    onClick={() => props.onSelectWallpaper(wp.id, wp.category as AppSettings['wallpaperCategory'])}
                  >
                    <div style={{ height: 48, borderRadius: 8, background: wp.gradient, marginBottom: 6 }} />
                    <div style={{ fontSize: 11.5, fontWeight: 600 }}>{wp.title}</div>
                    <div style={{ fontSize: 10, color: 'var(--text-muted)', textTransform: 'capitalize' }}>
                      {wp.category}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>

      <div className="menu-panel-footer">
        <button type="button" className="footer-btn" onClick={() => props.onFocusSettings('features')}>
          <Settings size={13} />
          Settings
        </button>
        <button type="button" className="footer-btn" onClick={() => props.onOpenOverlay('about')}>
          <Power size={13} />
          About · v{APP_VERSION}
        </button>
      </div>
    </aside>
  );
}

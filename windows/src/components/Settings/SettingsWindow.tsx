import React, { useMemo, useState } from 'react';
import {
  Activity,
  Archive,
  Clipboard,
  FileText,
  Info,
  Keyboard,
  LayoutGrid,
  Monitor,
  Mouse,
  Package,
  Search,
  Settings,
  Shield,
  Sparkle,
  Sun,
  Volume2,
  Wrench,
  XSquare,
  Zap,
} from 'lucide-react';
import {
  APP_VERSION,
  BUNDLES,
  FEATURES_CATALOG,
  GROUP_LABELS,
  UI_STRINGS,
} from '../../data/catalog';
import type {
  AppSettings,
  FeatureGroupId,
  LocaleCode,
  OverlayId,
  SettingsSectionId,
  SystemTelemetry,
  TextSnippet,
} from '../../types/vorssaint';
import { BrandMark, FeatureIcon, Switch } from '../BrandMark';

interface SettingsWindowProps {
  settings: AppSettings;
  telemetry: SystemTelemetry;
  snippets: TextSnippet[];
  onChangeSection: (section: SettingsSectionId) => void;
  onChangeTheme: (theme: AppSettings['theme']) => void;
  onChangeLocale: (locale: LocaleCode) => void;
  onInstallFeature: (id: string, installed: boolean) => void;
  onApplyBundle: (featureIds: string[], replace: boolean) => void;
  onInstallAll: () => void;
  onUninstallAll: () => void;
  onToggleControl: (key: keyof AppSettings['toggles']) => void;
  onUpdateShortcut: (action: string, combo: string) => void;
  onSaveSnippets: (snippets: TextSnippet[]) => void;
  onOpenOverlay: (id: OverlayId) => void;
  onExportBackup: () => void;
  onImportBackup: (jsonText: string) => void;
}

const SIDEBAR_GROUPS: Array<{
  title: string;
  items: Array<{ id: SettingsSectionId; label: string; Icon: React.ComponentType<{ size?: number }> }>;
}> = [
  {
    title: 'Essentials',
    items: [
      { id: 'general', label: 'General', Icon: Settings },
      { id: 'features', label: 'Features', Icon: LayoutGrid },
      { id: 'energy', label: 'Energy & Display', Icon: Zap },
      { id: 'monitor', label: 'Monitor', Icon: Activity },
      { id: 'sound', label: 'Sound', Icon: Volume2 },
    ],
  },
  {
    title: 'Window controls',
    items: [
      { id: 'mouseKeyboard', label: 'Mouse & Keyboard', Icon: Mouse },
      { id: 'switcher', label: 'Switcher', Icon: Monitor },
      { id: 'windowLayout', label: 'Window layout', Icon: LayoutGrid },
      { id: 'quitOnClose', label: 'Quit on close', Icon: XSquare },
    ],
  },
  {
    title: 'Files & Island',
    items: [
      { id: 'clipboard', label: 'Clipboard', Icon: Clipboard },
      { id: 'textSnippets', label: 'Text Snippets', Icon: FileText },
      { id: 'shelf', label: 'Shelf', Icon: Package },
      { id: 'dynamicIsland', label: 'Dynamic Island', Icon: Sparkle },
    ],
  },
  {
    title: 'Utilities',
    items: [
      { id: 'tools', label: 'Quick tools', Icon: Wrench },
      { id: 'shortcuts', label: 'Shortcuts', Icon: Keyboard },
      { id: 'backup', label: 'Backup & Restore', Icon: Archive },
      { id: 'about', label: 'About', Icon: Info },
    ],
  },
];

const RUNTIME_BADGES: Record<string, { label: string; cls: string }> = {
  keyboard: { label: 'Listens to keyboard', cls: 'tag-badge blue' },
  mouse: { label: 'Listens to mouse', cls: 'tag-badge' },
  audio: { label: 'Audio endpoint', cls: 'tag-badge green' },
  idle: { label: 'Nothing at rest', cls: 'tag-badge' },
  beta: { label: 'Beta', cls: 'tag-badge orange' },
};

const GROUP_ORDER: FeatureGroupId[] = [
  'windowsDock',
  'mouseKeyboard',
  'clipboardFiles',
  'sound',
  'energyDisplay',
  'tools',
  'dynamicIsland',
  'monitor',
];

export function SettingsWindow(props: SettingsWindowProps) {
  const { settings, telemetry, snippets } = props;
  const loc = settings.locale;
  const t = UI_STRINGS[loc];

  const [hubTab, setHubTab] = useState<'features' | 'permissions'>('features');
  const [sidebarSearch, setSidebarSearch] = useState('');
  const [hubSearch, setHubSearch] = useState('');
  const [newTrigger, setNewTrigger] = useState('');
  const [newExpansion, setNewExpansion] = useState('');
  const [backupInput, setBackupInput] = useState('');

  const installedCount = useMemo(
    () => FEATURES_CATALOG.filter((item) => settings.installedFeatures[item.id] !== false).length,
    [settings.installedFeatures]
  );

  const permissionRows = useMemo(
    () => [
      {
        id: 'accessibility',
        name: 'Win32 Input & Window Hooks',
        desc: 'Required for App Switcher, Window Layout Snapping, Debounce filters, and Super Key.',
        granted: true,
        users: FEATURES_CATALOG.filter(
          (f) => f.permission === 'accessibility' && settings.installedFeatures[f.id] !== false
        ).length,
      },
      {
        id: 'screenRecording',
        name: 'Desktop Duplication / Screen Capture',
        desc: 'Powers Taskbar Previews, Screenshot Studio, OCR text extraction, and MP4/GIF recorder.',
        granted: true,
        users: FEATURES_CATALOG.filter(
          (f) => f.permission === 'screenRecording' && settings.installedFeatures[f.id] !== false
        ).length,
      },
      {
        id: 'audioCapture',
        name: 'Windows CoreAudio WASAPI Endpoint',
        desc: 'Per-app volume faders, >100% boost, and Dynamic Island real-time equalizer.',
        granted: true,
        users: FEATURES_CATALOG.filter(
          (f) => f.permission === 'audioCapture' && settings.installedFeatures[f.id] !== false
        ).length,
      },
      {
        id: 'appManagement',
        name: 'Windows Registry & Winget Elevation',
        desc: 'Reads installed Registry uninstall keys and triggers winget upgrades.',
        granted: true,
        users: FEATURES_CATALOG.filter(
          (f) => f.permission === 'appManagement' && settings.installedFeatures[f.id] !== false
        ).length,
      },
    ],
    [settings.installedFeatures]
  );

  return (
    <section className="settings-window" aria-label={t.settingsTitle}>
      <div className="window-titlebar">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ display: 'inline-flex', gap: 6 }}>
            <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#ff5f57' }} />
            <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#febc2e' }} />
            <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#28c840' }} />
          </span>
          <strong style={{ fontSize: 12.5 }}>{t.settingsTitle}</strong>
          <span className="tag-badge">Windows Edition · v{APP_VERSION}</span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div className="segmented" style={{ padding: 2 }}>
            {(['en', 'pt', 'es'] as const).map((code) => (
              <button
                key={code}
                type="button"
                className={`segmented-btn ${settings.locale === code ? 'active' : ''}`}
                style={{ height: 22, padding: '0 8px', fontSize: 11, textTransform: 'uppercase' }}
                onClick={() => props.onChangeLocale(code)}
              >
                {code}
              </button>
            ))}
          </div>
          <button
            type="button"
            className="btn"
            style={{ height: 26 }}
            onClick={() => props.onChangeTheme(settings.theme === 'dark' ? 'light' : 'dark')}
          >
            <Sun size={12} /> {settings.theme === 'dark' ? 'Dark' : 'Light'}
          </button>
        </div>
      </div>

      <div className="settings-body">
        <aside className="settings-sidebar">
          <div style={{ position: 'relative', padding: '0 2px' }}>
            <Search size={13} style={{ position: 'absolute', left: 10, top: 9, color: 'var(--text-muted)' }} />
            <input
              className="input-field"
              style={{ paddingLeft: 28, height: 29 }}
              value={sidebarSearch}
              onChange={(e) => setSidebarSearch(e.target.value)}
              placeholder={t.searchSettings}
            />
          </div>

          {SIDEBAR_GROUPS.map((group) => {
            const visibleItems = group.items.filter(
              (item) => !sidebarSearch.trim() || item.label.toLowerCase().includes(sidebarSearch.toLowerCase())
            );
            if (visibleItems.length === 0) return null;
            return (
              <div key={group.title} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <div className="sidebar-group-label">{group.title}</div>
                {visibleItems.map(({ id, label, Icon }) => (
                  <button
                    key={id}
                    type="button"
                    className={`sidebar-item ${settings.activeSettingsSection === id ? 'active' : ''}`}
                    onClick={() => props.onChangeSection(id)}
                  >
                    <Icon size={14} />
                    <span>{label}</span>
                  </button>
                ))}
              </div>
            );
          })}
        </aside>

        <main className="settings-content">
          {/* FEATURES HUB */}
          {settings.activeSettingsSection === 'features' && (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
                <div className="segmented">
                  <button
                    type="button"
                    className={`segmented-btn ${hubTab === 'features' ? 'active' : ''}`}
                    onClick={() => setHubTab('features')}
                  >
                    {t.featuresHub}
                  </button>
                  <button
                    type="button"
                    className={`segmented-btn ${hubTab === 'permissions' ? 'active' : ''}`}
                    onClick={() => setHubTab('permissions')}
                  >
                    {t.permissions}
                  </button>
                </div>

                <input
                  className="input-field"
                  style={{ width: 220 }}
                  value={hubSearch}
                  onChange={(e) => setHubSearch(e.target.value)}
                  placeholder="Filter 80 features..."
                />
              </div>

              {hubTab === 'features' ? (
                <>
                  <div className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600 }}>
                        Install only what you use. Whatever you uninstall disappears from the panel and stops running.
                      </div>
                      <div className="tabular" style={{ fontSize: 11.5, color: 'var(--text-secondary)', marginTop: 3 }}>
                        {installedCount} of {FEATURES_CATALOG.length} {t.installedCount}
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                      <button type="button" className="btn" onClick={props.onInstallAll}>
                        {t.installAll}
                      </button>
                      <button type="button" className="btn" onClick={props.onUninstallAll}>
                        {t.uninstallAll}
                      </button>
                    </div>
                  </div>

                  <div>
                    <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 8 }}>{t.bundleSection}</div>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10 }}>
                      {BUNDLES.map((bundle) => {
                        const missing = bundle.featureIds.filter(
                          (fid) => settings.installedFeatures[fid] === false
                        ).length;
                        return (
                          <div key={bundle.id} className="panel-card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between', gap: 8 }}>
                            <div>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 700 }}>
                                <span style={{ color: 'var(--accent-blue)' }}>
                                  <FeatureIcon name={bundle.icon} size={15} />
                                </span>
                                {bundle.name[loc]}
                              </div>
                              <div style={{ fontSize: 11.5, color: 'var(--text-secondary)', marginTop: 4, lineHeight: 1.4 }}>
                                {bundle.description[loc]}
                              </div>
                            </div>
                            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                              <button
                                type="button"
                                className="btn"
                                onClick={() => props.onApplyBundle(bundle.featureIds, true)}
                              >
                                {t.applyBundle}
                              </button>
                              {missing > 0 && (
                                <button
                                  type="button"
                                  className="btn btn-primary"
                                  onClick={() => props.onApplyBundle(bundle.featureIds, false)}
                                >
                                  Install {missing} missing
                                </button>
                              )}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                    <div style={{ fontSize: 11.5, color: 'var(--text-muted)', marginTop: 6 }}>{t.bundleHint}</div>
                  </div>

                  {GROUP_ORDER.map((groupId) => {
                    const items = FEATURES_CATALOG.filter((item) => {
                      if (item.group !== groupId) return false;
                      if (!hubSearch.trim()) return true;
                      const q = hubSearch.toLowerCase();
                      return (
                        item.name[loc].toLowerCase().includes(q) ||
                        item.description[loc].toLowerCase().includes(q) ||
                        item.id.toLowerCase().includes(q)
                      );
                    });
                    if (items.length === 0) return null;

                    return (
                      <div key={groupId} style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                        <div style={{ fontSize: 14, fontWeight: 700 }}>{GROUP_LABELS[groupId][loc]}</div>
                        <div className="panel-card" style={{ padding: 0, overflow: 'hidden' }}>
                          {items.map((item, idx) => {
                            const isInstalled = settings.installedFeatures[item.id] !== false;
                            const badge = item.isBeta ? RUNTIME_BADGES.beta : RUNTIME_BADGES[item.runtimeBadge];
                            return (
                              <div
                                key={item.id}
                                style={{
                                  padding: '10px 14px',
                                  borderTop: idx > 0 ? '1px solid var(--border-subtle)' : undefined,
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'space-between',
                                  gap: 12,
                                }}
                              >
                                <div style={{ display: 'flex', alignItems: 'center', gap: 11, minWidth: 0 }}>
                                  <div
                                    style={{
                                      width: 30,
                                      height: 30,
                                      borderRadius: 8,
                                      background: 'var(--surface-input)',
                                      border: '1px solid var(--border-subtle)',
                                      display: 'flex',
                                      alignItems: 'center',
                                      justifyContent: 'center',
                                      color: isInstalled ? 'var(--accent-blue)' : 'var(--text-muted)',
                                      flexShrink: 0,
                                    }}
                                  >
                                    <FeatureIcon name={item.icon} size={15} />
                                  </div>
                                  <div style={{ minWidth: 0 }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
                                      <span style={{ fontSize: 13, fontWeight: 600 }}>{item.name[loc]}</span>
                                      <span className={badge.cls}>{badge.label}</span>
                                    </div>
                                    <div style={{ fontSize: 11.5, color: 'var(--text-secondary)', marginTop: 2 }}>
                                      {item.description[loc]}
                                    </div>
                                  </div>
                                </div>
                                <button
                                  type="button"
                                  className={`btn ${isInstalled ? '' : 'btn-primary'}`}
                                  style={{ minWidth: 84, flexShrink: 0 }}
                                  onClick={() => props.onInstallFeature(item.id, !isInstalled)}
                                >
                                  {isInstalled ? t.uninstall : t.install}
                                </button>
                              </div>
                            );
                          })}
                        </div>
                      </div>
                    );
                  })}
                </>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {permissionRows.map((perm) => (
                    <div key={perm.id} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <Shield size={18} style={{ color: 'var(--accent-green)', flexShrink: 0 }} />
                        <div>
                          <div style={{ fontSize: 13, fontWeight: 600 }}>{perm.name}</div>
                          <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>{perm.desc}</div>
                          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>
                            Used by {perm.users} installed feature(s)
                          </div>
                        </div>
                      </div>
                      <span className="tag-badge green">Ready on Windows</span>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}

          {/* GENERAL */}
          {settings.activeSettingsSection === 'general' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>General Windows Integration</div>
              <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>Launch Vorssaint automatically at Windows logon</div>
                    <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>Starts minimized to the system tray</div>
                  </div>
                  <Switch checked={settings.toggles.launchAtStartup} onChange={() => props.onToggleControl('launchAtStartup')} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>Separate tray metrics into individual icons</div>
                    <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>CPU, RAM, and Net badges in Windows taskbar tray</div>
                  </div>
                  <Switch checked={settings.toggles.separateMenuMetrics} onChange={() => props.onToggleControl('separateMenuMetrics')} />
                </div>
              </div>
            </div>
          )}

          {/* ENERGY & MONITOR & SOUND */}
          {(settings.activeSettingsSection === 'energy' ||
            settings.activeSettingsSection === 'monitor' ||
            settings.activeSettingsSection === 'sound') && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>
                {settings.activeSettingsSection === 'energy'
                  ? 'Energy & Display Control'
                  : settings.activeSettingsSection === 'monitor'
                  ? 'System Telemetry Engine'
                  : 'Windows Sound & Audio Mixer'}
              </div>
              <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ fontSize: 12.5, color: 'var(--text-secondary)' }}>
                  Host: <strong>{telemetry.hostName}</strong> · {telemetry.osVersion}
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 13 }}>Prevent display sleep when Keep Awake is active</span>
                  <Switch checked={settings.toggles.keepAwakeDisplay} onChange={() => props.onToggleControl('keepAwakeDisplay')} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 13 }}>Automatic output & mic device priority</span>
                  <Switch checked={settings.toggles.audioPriority} onChange={() => props.onToggleControl('audioPriority')} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 13 }}>Extra software dimming beyond hardware min</span>
                  <Switch checked={settings.toggles.extraBrightness} onChange={() => props.onToggleControl('extraBrightness')} />
                </div>
              </div>
            </div>
          )}

          {/* WINDOW & INPUT CONTROLS */}
          {(settings.activeSettingsSection === 'mouseKeyboard' ||
            settings.activeSettingsSection === 'switcher' ||
            settings.activeSettingsSection === 'windowLayout' ||
            settings.activeSettingsSection === 'quitOnClose') && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>Windows & Input Behavior</div>
              <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {(
                  [
                    ['switcher', 'Enable Vorssaint App Switcher', 'Alt+Tab cards with live window titles and focus raising'],
                    ['taskbarPreview', 'Taskbar hover window previews', 'Peek individual windows from the Windows taskbar'],
                    ['windowMaximizer', 'Clean Maximize within usable work area', 'Respects Windows taskbar boundaries'],
                    ['windowEdgeSnap', 'Drag-to-edge Window Layout snapping', 'Halves, thirds, and quarter zones'],
                    ['autoQuitOnClose', 'Quit app automatically on last window close', 'Prevents hidden background processes from lingering'],
                    ['scrollInverter', 'Invert external mouse wheel independently', 'Leave Precision Touchpad scroll untouched'],
                    ['smoothScroll', '120Hz smooth scroll curve', 'Fluid scrolling across Win32 and browser views'],
                    ['mouseAccelDisabled', 'Disable Windows pointer acceleration', 'True 1:1 linear pointer tracking'],
                  ] as const
                ).map(([key, title, desc]) => (
                  <div key={key} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 600 }}>{title}</div>
                      <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>{desc}</div>
                    </div>
                    <Switch checked={settings.toggles[key]} onChange={() => props.onToggleControl(key)} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* CLIPBOARD & SHELF */}
          {(settings.activeSettingsSection === 'clipboard' || settings.activeSettingsSection === 'shelf') && (
            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ fontSize: 15, fontWeight: 700 }}>Clipboard, URL Cleaner & Floating Shelf</div>
              {(
                [
                  ['clipboardHistory', 'Record local clipboard history', 'Encrypted strictly on device'],
                  ['urlAutoClean', 'Strip utm_*, fbclid & gclid automatically', 'Clean tracking parameters when copying links'],
                  ['explorerCutPaste', 'Enhanced Explorer cut/paste & image paste', 'Paste clipboard screenshots straight as PNG files'],
                  ['explorerBatchRename', 'Batch rename tools in Explorer', 'Regex and sequential numbering templates'],
                ] as const
              ).map(([key, title, desc]) => (
                <div key={key} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>{title}</div>
                    <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>{desc}</div>
                  </div>
                  <Switch checked={settings.toggles[key]} onChange={() => props.onToggleControl(key)} />
                </div>
              ))}
              <div>
                <button type="button" className="btn btn-primary" onClick={() => props.onOpenOverlay('fileShelf')}>
                  Open Floating Shelf Window
                </button>
              </div>
            </div>
          )}

          {/* TEXT SNIPPETS */}
          {settings.activeSettingsSection === 'textSnippets' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>Text Expansion Snippets</div>
              <div className="panel-card" style={{ display: 'grid', gridTemplateColumns: '140px 1fr auto', gap: 8 }}>
                <input
                  className="input-field"
                  placeholder=";trigger"
                  value={newTrigger}
                  onChange={(e) => setNewTrigger(e.target.value)}
                />
                <input
                  className="input-field"
                  placeholder="Expanded phrase or command..."
                  value={newExpansion}
                  onChange={(e) => setNewExpansion(e.target.value)}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={() => {
                    if (!newTrigger.trim() || !newExpansion.trim()) return;
                    props.onSaveSnippets([
                      ...snippets,
                      { id: `sn-${Date.now()}`, trigger: newTrigger.trim(), expansion: newExpansion.trim(), category: 'Custom' },
                    ]);
                    setNewTrigger('');
                    setNewExpansion('');
                  }}
                >
                  Add Snippet
                </button>
              </div>
              {snippets.map((s) => (
                <div key={s.id} className="panel-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <span className="tag-badge blue" style={{ marginRight: 8 }}>{s.trigger}</span>
                    <span style={{ fontSize: 12.5 }}>{s.expansion}</span>
                  </div>
                  <button
                    type="button"
                    className="btn btn-danger"
                    onClick={() => props.onSaveSnippets(snippets.filter((item) => item.id !== s.id))}
                  >
                    Delete
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* DYNAMIC ISLAND */}
          {settings.activeSettingsSection === 'dynamicIsland' && (
            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ fontSize: 15, fontWeight: 700 }}>Dynamic Island HUD Settings</div>
              {(
                [
                  ['dynamicIslandEnabled', 'Show Dynamic Island Pill on Windows Desktop', 'Top-center floating status pill'],
                  ['dynamicIslandLyrics', 'Synchronized Track Lyrics', 'Display current line while playing audio'],
                  ['dynamicIslandEqualizer', 'Live Audio Equalizer Visualizer', 'Animated bars synced to audio'],
                  ['dynamicIslandAgents', 'AI Coding Agents Monitor', 'Track Claude, Codex, and Copilot sessions'],
                  ['dynamicIslandMascot', 'Show Vorssaint Orbital Mascot', 'Subtle mascot indicator on pill edge'],
                ] as const
              ).map(([key, title, desc]) => (
                <div key={key} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>{title}</div>
                    <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>{desc}</div>
                  </div>
                  <Switch checked={settings.toggles[key]} onChange={() => props.onToggleControl(key)} />
                </div>
              ))}
            </div>
          )}

          {/* QUICK TOOLS */}
          {settings.activeSettingsSection === 'tools' && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10 }}>
              {[
                ['Command Bar (Ctrl+K)', 'Search windows, calculate math, launch actions', 'commandBar'],
                ['Window Switcher (Alt+Tab)', 'Visual preview switcher across open Windows apps', 'appSwitcher'],
                ['Radial Action Wheel', 'Circular 8-way cursor launcher', 'radialMenu'],
                ['Floating File Shelf', 'Drop files across virtual desktops', 'fileShelf'],
                ['Markdown Scratchpad', 'Multi-tab instant developer notes', 'scratchpad'],
                ['Screenshot, OCR & Recorder', 'Region capture, pixel hex picker & MP4/GIF recorder', 'screenCapture'],
                ['Keyboard Cleaning Mode', 'Lock accidental keyboard & trackpad presses', 'cleaningMode'],
              ].map(([title, desc, overlay]) => (
                <button
                  key={overlay}
                  type="button"
                  className="panel-card panel-card-clickable"
                  style={{ textAlign: 'left', color: 'var(--text-primary)' }}
                  onClick={() => props.onOpenOverlay(overlay as OverlayId)}
                >
                  <div style={{ fontSize: 13, fontWeight: 600 }}>{title}</div>
                  <div style={{ fontSize: 11.5, color: 'var(--text-secondary)', marginTop: 3 }}>{desc}</div>
                </button>
              ))}
            </div>
          )}

          {/* SHORTCUTS */}
          {settings.activeSettingsSection === 'shortcuts' && (
            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ fontSize: 15, fontWeight: 700 }}>Global Windows Hotkeys</div>
              {Object.entries(settings.shortcuts).map(([action, combo]) => (
                <div key={action} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 13, fontWeight: 500, textTransform: 'capitalize' }}>{action}</span>
                  <input
                    className="input-field"
                    style={{ width: 160, textAlign: 'center', fontWeight: 600 }}
                    value={combo}
                    onChange={(e) => props.onUpdateShortcut(action, e.target.value)}
                  />
                </div>
              ))}
            </div>
          )}

          {/* BACKUP & RESTORE */}
          {settings.activeSettingsSection === 'backup' && (
            <div className="panel-card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ fontSize: 15, fontWeight: 700 }}>Settings Backup & Restore</div>
              <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                Export or import a JSON snapshot of installed features, toggles, shortcuts, and snippets.
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button type="button" className="btn btn-primary" onClick={props.onExportBackup}>
                  Copy JSON Backup to Clipboard
                </button>
              </div>
              <textarea
                rows={4}
                className="input-field"
                style={{ height: 'auto', padding: 10, fontFamily: 'Consolas, monospace' }}
                placeholder="Paste previously exported Vorssaint JSON snapshot here..."
                value={backupInput}
                onChange={(e) => setBackupInput(e.target.value)}
              />
              <div>
                <button type="button" className="btn" onClick={() => props.onImportBackup(backupInput)}>
                  Restore Snapshot
                </button>
              </div>
            </div>
          )}

          {/* ABOUT */}
          {settings.activeSettingsSection === 'about' && (
            <div className="panel-card" style={{ display: 'flex', alignItems: 'center', gap: 16, padding: 18 }}>
              <BrandMark width={56} />
              <div>
                <div style={{ fontSize: 16, fontWeight: 700 }}>Vorssaint Utils — Windows Edition v{APP_VERSION}</div>
                <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>
                  Complete Windows feature & visual parity build on branch <code>dev.win</code>. Backed by Rust + Win32 APIs (<code>sysinfo</code>, <code>SetThreadExecutionState</code>, CoreAudio WASAPI, <code>EnumWindows</code>, <code>netstat</code>, <code>winget</code>) and Tauri v2.
                </div>
              </div>
            </div>
          )}
        </main>
      </div>
    </section>
  );
}

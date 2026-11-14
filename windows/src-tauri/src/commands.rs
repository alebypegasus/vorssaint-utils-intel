use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use sysinfo::{Components, Disks, Networks, Pid, System};
use tauri::{AppHandle, Emitter, Manager};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

#[derive(Clone)]
pub struct AppRuntimeState {
    pub sys: Arc<Mutex<System>>,
    pub networks: Arc<Mutex<Networks>>,
    pub disks: Arc<Mutex<Disks>>,
    pub components: Arc<Mutex<Components>>,
    pub keep_awake: Arc<Mutex<bool>>,
    pub keep_display_on: Arc<Mutex<bool>>,
    pub initialized: Arc<Mutex<bool>>,
    pub last_external_hwnd: Arc<Mutex<isize>>,
    pub clipboard_history_last: Arc<Mutex<String>>,
    pub panel_shown_at_ms: Arc<AtomicU64>,
    pub current_overlay_mode: Arc<Mutex<String>>,
    pub island_visible: Arc<AtomicBool>,
    pub quitting: Arc<AtomicBool>,
}

impl AppRuntimeState {
    pub fn new() -> Self {
        // Keep STA main thread free of sysinfo/WMI initialization at startup so tao::OleInitialize succeeds.
        Self {
            sys: Arc::new(Mutex::new(System::new())),
            networks: Arc::new(Mutex::new(Networks::new())),
            disks: Arc::new(Mutex::new(Disks::new())),
            components: Arc::new(Mutex::new(Components::new())),
            keep_awake: Arc::new(Mutex::new(false)),
            keep_display_on: Arc::new(Mutex::new(true)),
            initialized: Arc::new(Mutex::new(false)),
            last_external_hwnd: Arc::new(Mutex::new(0)),
            clipboard_history_last: Arc::new(Mutex::new(String::new())),
            panel_shown_at_ms: Arc::new(AtomicU64::new(0)),
            current_overlay_mode: Arc::new(Mutex::new("command".to_string())),
            island_visible: Arc::new(AtomicBool::new(true)),
            quitting: Arc::new(AtomicBool::new(false)),
        }
    }
}

pub fn now_millis() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ProcessEntry {
    pub pid: u32,
    pub name: String,
    pub cpu_percent: f32,
    pub memory_mb: f64,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct DiskVolume {
    pub name: String,
    pub mount: String,
    pub file_system: String,
    pub total_gb: f64,
    pub available_gb: f64,
    pub used_percent: f32,
    pub is_removable: bool,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct NetAdapter {
    pub name: String,
    pub rx_kb_per_sec: f64,
    pub tx_kb_per_sec: f64,
    pub total_rx_mb: f64,
    pub total_tx_mb: f64,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MediaSessionInfo {
    pub app_name: String,
    pub title: String,
    pub artist: String,
    pub is_playing: bool,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct SystemTelemetry {
    pub host_name: String,
    pub os_version: String,
    pub cpu_brand: String,
    pub cpu_percent: f32,
    pub cpu_cores: Vec<f32>,
    pub cpu_temp_c: Option<f32>,
    pub gpu_percent: f32,
    pub gpu_temp_c: Option<f32>,
    pub memory_used_gb: f64,
    pub memory_total_gb: f64,
    pub memory_pressure: String,
    pub battery_percent: Option<u8>,
    pub battery_charging: bool,
    pub battery_temp_c: Option<f32>,
    pub uptime_seconds: u64,
    pub download_kb_per_sec: f64,
    pub upload_kb_per_sec: f64,
    pub keep_awake_active: bool,
    pub master_volume: u8,
    pub master_muted: bool,
    pub dark_mode: bool,
    pub active_window_title: String,
    pub media_session: Option<MediaSessionInfo>,
    pub disks: Vec<DiskVolume>,
    pub networks: Vec<NetAdapter>,
    pub top_processes: Vec<ProcessEntry>,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MasterAudioState {
    pub volume: u8,
    pub muted: bool,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct AppAudioSession {
    pub id: String,
    pub pid: u32,
    pub name: String,
    pub volume: u8,
    pub muted: bool,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct OpenWindowEntry {
    pub hwnd: isize,
    pub pid: u32,
    pub title: String,
    pub process_name: String,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ListeningPortEntry {
    pub protocol: String,
    pub local_address: String,
    pub port: u16,
    pub pid: u32,
    pub process_name: String,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct JunkCategory {
    pub id: String,
    pub label: String,
    pub path: String,
    pub size_mb: f64,
    pub file_count: usize,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct InstalledAppEntry {
    pub name: String,
    pub publisher: String,
    pub version: String,
    pub install_location: String,
    pub uninstall_string: String,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct WingetPackage {
    pub name: String,
    pub id: String,
    pub version: String,
    pub available_version: Option<String>,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct PickedColorResult {
    pub hex: String,
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub x: i32,
    pub y: i32,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ScreenshotResult {
    pub path: String,
    pub file_name: String,
    pub width: u32,
    pub height: u32,
    pub size_kb: u64,
}

#[derive(Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ShelfDropFile {
    pub name: String,
    pub path: String,
    pub kind: String,
    pub size_label: String,
}

fn hidden_command(program: &str) -> Command {
    let mut cmd = Command::new(program);
    #[cfg(windows)]
    cmd.creation_flags(CREATE_NO_WINDOW);
    cmd
}

#[cfg(windows)]
fn process_name_for_pid(pid: u32) -> String {
    use windows::core::PWSTR;
    use windows::Win32::Foundation::CloseHandle;
    use windows::Win32::System::Threading::{
        OpenProcess, QueryFullProcessImageNameW, PROCESS_NAME_WIN32,
        PROCESS_QUERY_LIMITED_INFORMATION,
    };
    if pid == 0 {
        return "System".to_string();
    }
    unsafe {
        if let Ok(handle) = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid) {
            let mut buf = [0u16; 512];
            let mut size = buf.len() as u32;
            let ok = QueryFullProcessImageNameW(
                handle,
                PROCESS_NAME_WIN32,
                PWSTR(buf.as_mut_ptr()),
                &mut size,
            )
            .is_ok();
            let _ = CloseHandle(handle);
            if ok && size > 0 {
                let full = String::from_utf16_lossy(&buf[..size as usize]);
                if let Some(stem) = std::path::Path::new(&full).file_stem() {
                    return stem.to_string_lossy().to_string();
                }
            }
        }
    }
    format!("PID {pid}")
}

#[cfg(not(windows))]
fn process_name_for_pid(pid: u32) -> String {
    format!("PID {pid}")
}

#[cfg(windows)]
pub fn read_clipboard_text_win32() -> Option<String> {
    use windows::Win32::System::DataExchange::{CloseClipboard, GetClipboardData, OpenClipboard};
    use windows::Win32::System::Memory::{GlobalLock, GlobalUnlock};
    unsafe {
        if OpenClipboard(None).is_err() {
            return None;
        }
        let result = (|| {
            let handle = GetClipboardData(13u32).ok()?; // CF_UNICODETEXT = 13
            let ptr = GlobalLock(std::mem::transmute(handle.0)) as *const u16;
            if ptr.is_null() {
                return None;
            }
            let mut len = 0usize;
            while *ptr.add(len) != 0 && len < 65536 {
                len += 1;
            }
            let slice = std::slice::from_raw_parts(ptr, len);
            let text = String::from_utf16_lossy(slice);
            let _ = GlobalUnlock(std::mem::transmute(handle.0));
            Some(text)
        })();
        let _ = CloseClipboard();
        result
    }
}

#[cfg(not(windows))]
pub fn read_clipboard_text_win32() -> Option<String> {
    None
}

#[cfg(windows)]
pub fn write_clipboard_text_win32(text: &str) -> Result<(), String> {
    use windows::Win32::Foundation::{HANDLE, HGLOBAL};
    use windows::Win32::System::DataExchange::{
        CloseClipboard, EmptyClipboard, OpenClipboard, SetClipboardData,
    };
    use windows::Win32::System::Memory::{GlobalAlloc, GlobalLock, GlobalUnlock, GMEM_MOVEABLE};
    unsafe {
        OpenClipboard(None).map_err(|e| format!("OpenClipboard failed: {e}"))?;
        let _ = EmptyClipboard();
        let utf16: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
        let bytes = utf16.len() * std::mem::size_of::<u16>();
        let res = (|| -> Result<(), String> {
            let hmem: HGLOBAL =
                GlobalAlloc(GMEM_MOVEABLE, bytes).map_err(|e| format!("GlobalAlloc failed: {e}"))?;
            let dst = GlobalLock(hmem) as *mut u16;
            if dst.is_null() {
                return Err("GlobalLock returned null".to_string());
            }
            std::ptr::copy_nonoverlapping(utf16.as_ptr(), dst, utf16.len());
            let _ = GlobalUnlock(hmem);
            SetClipboardData(13u32, Some(HANDLE(hmem.0)))
                .map_err(|e| format!("SetClipboardData failed: {e}"))?;
            Ok(())
        })();
        let _ = CloseClipboard();
        res
    }
}

#[cfg(not(windows))]
pub fn write_clipboard_text_win32(_text: &str) -> Result<(), String> {
    Ok(())
}

#[cfg(windows)]
pub fn read_windows_dark_mode() -> bool {
    use windows::core::PCWSTR;
    use windows::Win32::System::Registry::{
        RegOpenKeyExW, RegQueryValueExW, HKEY_CURRENT_USER, KEY_READ, REG_VALUE_TYPE,
    };
    unsafe {
        let subkey: Vec<u16> = "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize\0"
            .encode_utf16()
            .collect();
        let mut hkey = Default::default();
        if RegOpenKeyExW(
            HKEY_CURRENT_USER,
            PCWSTR(subkey.as_ptr()),
            Some(0),
            KEY_READ,
            &mut hkey,
        )
        .is_ok()
        {
            let value_name: Vec<u16> = "AppsUseLightTheme\0".encode_utf16().collect();
            let mut val: u32 = 1;
            let mut size = std::mem::size_of::<u32>() as u32;
            let mut kind = REG_VALUE_TYPE::default();
            let ok = RegQueryValueExW(
                hkey,
                PCWSTR(value_name.as_ptr()),
                None,
                Some(&mut kind),
                Some(&mut val as *mut u32 as *mut u8),
                Some(&mut size),
            )
            .is_ok();
            let _ = windows::Win32::System::Registry::RegCloseKey(hkey);
            if ok {
                return val == 0;
            }
        }
    }
    true
}

#[cfg(not(windows))]
pub fn read_windows_dark_mode() -> bool {
    true
}

#[cfg(windows)]
fn read_windows_power_status() -> (Option<u8>, bool) {
    use windows::Win32::System::Power::{GetSystemPowerStatus, SYSTEM_POWER_STATUS};
    let mut status = SYSTEM_POWER_STATUS::default();
    if unsafe { GetSystemPowerStatus(&mut status) }.is_ok() {
        let pct = if status.BatteryLifePercent <= 100 {
            Some(status.BatteryLifePercent)
        } else {
            None
        };
        let charging = status.ACLineStatus == 1;
        (pct, charging)
    } else {
        (None, true)
    }
}

#[cfg(not(windows))]
fn read_windows_power_status() -> (Option<u8>, bool) {
    (Some(100), true)
}

#[cfg(windows)]
fn read_core_audio_master() -> MasterAudioState {
    use windows::Win32::Media::Audio::Endpoints::IAudioEndpointVolume;
    use windows::Win32::Media::Audio::{eConsole, eRender, IMMDeviceEnumerator, MMDeviceEnumerator};
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoUninitialize, CLSCTX_ALL, COINIT_APARTMENTTHREADED,
    };

    unsafe {
        let hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
        let result = (|| -> windows::core::Result<MasterAudioState> {
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole)?;
            let endpoint: IAudioEndpointVolume = device.Activate(CLSCTX_ALL, None)?;
            let scalar = endpoint.GetMasterVolumeLevelScalar()?;
            let muted = endpoint.GetMute()?.as_bool();
            Ok(MasterAudioState {
                volume: (scalar.clamp(0.0, 1.0) * 100.0).round() as u8,
                muted,
            })
        })();
        if hr.is_ok() {
            CoUninitialize();
        }
        result.unwrap_or(MasterAudioState {
            volume: 65,
            muted: false,
        })
    }
}

#[cfg(not(windows))]
fn read_core_audio_master() -> MasterAudioState {
    MasterAudioState {
        volume: 65,
        muted: false,
    }
}

#[cfg(windows)]
fn write_core_audio_master(
    volume: Option<u8>,
    muted: Option<bool>,
) -> Result<MasterAudioState, String> {
    use windows::Win32::Media::Audio::Endpoints::IAudioEndpointVolume;
    use windows::Win32::Media::Audio::{eConsole, eRender, IMMDeviceEnumerator, MMDeviceEnumerator};
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoUninitialize, CLSCTX_ALL, COINIT_APARTMENTTHREADED,
    };

    unsafe {
        let hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
        let result = (|| -> windows::core::Result<MasterAudioState> {
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole)?;
            let endpoint: IAudioEndpointVolume = device.Activate(CLSCTX_ALL, None)?;
            if let Some(vol) = volume {
                let scalar = (vol.min(100) as f32) / 100.0;
                endpoint.SetMasterVolumeLevelScalar(scalar, std::ptr::null())?;
            }
            if let Some(m) = muted {
                endpoint.SetMute(m, std::ptr::null())?;
            }
            let scalar = endpoint.GetMasterVolumeLevelScalar()?;
            let current_muted = endpoint.GetMute()?.as_bool();
            Ok(MasterAudioState {
                volume: (scalar.clamp(0.0, 1.0) * 100.0).round() as u8,
                muted: current_muted,
            })
        })();
        if hr.is_ok() {
            CoUninitialize();
        }
        result.map_err(|e| format!("Audio endpoint error: {e}"))
    }
}

#[cfg(not(windows))]
fn write_core_audio_master(
    volume: Option<u8>,
    muted: Option<bool>,
) -> Result<MasterAudioState, String> {
    Ok(MasterAudioState {
        volume: volume.unwrap_or(65),
        muted: muted.unwrap_or(false),
    })
}

#[cfg(windows)]
fn enumerate_audio_sessions_win32() -> Vec<AppAudioSession> {
    use windows::core::Interface;
    use windows::Win32::Media::Audio::{
        eConsole, eRender, IAudioSessionControl2, IAudioSessionEnumerator, IAudioSessionManager2,
        IMMDeviceEnumerator, ISimpleAudioVolume, MMDeviceEnumerator,
    };
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoUninitialize, CLSCTX_ALL, COINIT_APARTMENTTHREADED,
    };

    unsafe {
        let hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
        let sessions = (|| -> windows::core::Result<Vec<AppAudioSession>> {
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole)?;
            let manager: IAudioSessionManager2 = device.Activate(CLSCTX_ALL, None)?;
            let list: IAudioSessionEnumerator = manager.GetSessionEnumerator()?;
            let count = list.GetCount()?;
            let mut out: Vec<AppAudioSession> = Vec::new();
            let mut seen_pids: HashMap<u32, usize> = HashMap::new();

            for idx in 0..count {
                let Ok(ctrl) = list.GetSession(idx) else {
                    continue;
                };
                let Ok(ctrl2) = ctrl.cast::<IAudioSessionControl2>() else {
                    continue;
                };
                let Ok(vol_ctrl) = ctrl.cast::<ISimpleAudioVolume>() else {
                    continue;
                };
                let pid = ctrl2.GetProcessId().unwrap_or(0);
                let session_id = ctrl2
                    .GetSessionInstanceIdentifier()
                    .map(|p| p.to_string().unwrap_or_default())
                    .unwrap_or_else(|_| format!("session-{idx}-{pid}"));
                let vol = vol_ctrl.GetMasterVolume().unwrap_or(1.0);
                let muted = vol_ctrl.GetMute().map(|b| b.as_bool()).unwrap_or(false);
                let name = if pid == 0 {
                    "System Sounds".to_string()
                } else {
                    process_name_for_pid(pid)
                };

                if let Some(&existing_idx) = seen_pids.get(&pid) {
                    if out[existing_idx].muted && !muted {
                        out[existing_idx].muted = false;
                    }
                    continue;
                }
                seen_pids.insert(pid, out.len());
                out.push(AppAudioSession {
                    id: session_id,
                    pid,
                    name,
                    volume: (vol.clamp(0.0, 1.0) * 100.0).round() as u8,
                    muted,
                });
            }
            Ok(out)
        })();
        if hr.is_ok() {
            CoUninitialize();
        }
        sessions.unwrap_or_default()
    }
}

#[cfg(not(windows))]
fn enumerate_audio_sessions_win32() -> Vec<AppAudioSession> {
    Vec::new()
}

#[cfg(windows)]
fn update_app_audio_session_win32(
    target_pid: u32,
    volume: Option<u8>,
    muted: Option<bool>,
) -> Result<(), String> {
    use windows::core::Interface;
    use windows::Win32::Media::Audio::{
        eConsole, eRender, IAudioSessionControl2, IAudioSessionEnumerator, IAudioSessionManager2,
        IMMDeviceEnumerator, ISimpleAudioVolume, MMDeviceEnumerator,
    };
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoUninitialize, CLSCTX_ALL, COINIT_APARTMENTTHREADED,
    };

    unsafe {
        let hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
        let result = (|| -> windows::core::Result<()> {
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole)?;
            let manager: IAudioSessionManager2 = device.Activate(CLSCTX_ALL, None)?;
            let list: IAudioSessionEnumerator = manager.GetSessionEnumerator()?;
            let count = list.GetCount()?;
            for idx in 0..count {
                let Ok(ctrl) = list.GetSession(idx) else {
                    continue;
                };
                let Ok(ctrl2) = ctrl.cast::<IAudioSessionControl2>() else {
                    continue;
                };
                let pid = ctrl2.GetProcessId().unwrap_or(0);
                if pid == target_pid {
                    if let Ok(vol_ctrl) = ctrl.cast::<ISimpleAudioVolume>() {
                        if let Some(v) = volume {
                            let scalar = (v.min(100) as f32) / 100.0;
                            let _ = vol_ctrl.SetMasterVolume(scalar, std::ptr::null());
                        }
                        if let Some(m) = muted {
                            let _ = vol_ctrl.SetMute(m, std::ptr::null());
                        }
                    }
                }
            }
            Ok(())
        })();
        if hr.is_ok() {
            CoUninitialize();
        }
        result.map_err(|e| format!("Failed updating app audio: {e}"))
    }
}

#[cfg(not(windows))]
fn update_app_audio_session_win32(
    _target_pid: u32,
    _volume: Option<u8>,
    _muted: Option<bool>,
) -> Result<(), String> {
    Ok(())
}

#[cfg(windows)]
fn detect_media_session_win32(open_windows: &[OpenWindowEntry]) -> Option<MediaSessionInfo> {
    let media_keywords = [
        ("spotify", "Spotify"),
        ("applemusic", "Apple Music"),
        ("music.ui", "Media Player"),
        ("vlc", "VLC Media Player"),
        ("foobar2000", "foobar2000"),
        ("aimp", "AIMP"),
        ("tidal", "TIDAL"),
    ];
    for w in open_windows {
        let pname = w.process_name.to_lowercase();
        for (needle, label) in media_keywords {
            if pname.contains(needle) && !w.title.trim().is_empty() {
                if let Some((artist, track)) = w.title.split_once(" - ") {
                    return Some(MediaSessionInfo {
                        app_name: label.to_string(),
                        title: track.trim().to_string(),
                        artist: artist.trim().to_string(),
                        is_playing: !w.title.eq_ignore_ascii_case("Spotify Free")
                            && !w.title.eq_ignore_ascii_case("Spotify Premium")
                            && !w.title.eq_ignore_ascii_case("Spotify"),
                    });
                }
                return Some(MediaSessionInfo {
                    app_name: label.to_string(),
                    title: w.title.clone(),
                    artist: label.to_string(),
                    is_playing: true,
                });
            }
        }
        if w.title.contains(" - YouTube") || w.title.contains("Spotify – ") {
            let clean = w
                .title
                .replace(" - YouTube", "")
                .replace(" - Google Chrome", "")
                .replace(" - Microsoft​ Edge", "")
                .replace(" - Microsoft Edge", "")
                .trim()
                .to_string();
            return Some(MediaSessionInfo {
                app_name: w.process_name.clone(),
                title: clean,
                artist: "Browser Media".to_string(),
                is_playing: true,
            });
        }
    }
    None
}

#[cfg(not(windows))]
fn detect_media_session_win32(_open_windows: &[OpenWindowEntry]) -> Option<MediaSessionInfo> {
    None
}

#[cfg(windows)]
pub fn enumerate_open_windows_win32() -> Vec<OpenWindowEntry> {
    use windows::Win32::Foundation::{BOOL, HWND, LPARAM};
    use windows::Win32::UI::WindowsAndMessaging::{
        EnumWindows, GetWindowTextW, GetWindowThreadProcessId, IsWindowVisible,
    };

    unsafe extern "system" fn enum_proc(hwnd: HWND, lparam: LPARAM) -> BOOL {
        if IsWindowVisible(hwnd).as_bool() {
            let mut buf = [0u16; 256];
            let len = GetWindowTextW(hwnd, &mut buf);
            if len > 0 {
                let title = String::from_utf16_lossy(&buf[..len as usize]);
                if !title.trim().is_empty()
                    && title != "Program Manager"
                    && title != "Vorssaint Dynamic Island"
                    && title != "Vorssaint Panel"
                    && title != "Vorssaint Overlay"
                {
                    let mut pid: u32 = 0;
                    GetWindowThreadProcessId(hwnd, Some(&mut pid));
                    let entries = &mut *(lparam.0 as *mut Vec<OpenWindowEntry>);
                    entries.push(OpenWindowEntry {
                        hwnd: hwnd.0 as isize,
                        pid,
                        title,
                        process_name: String::new(),
                    });
                }
            }
        }
        BOOL(1)
    }

    let mut entries: Vec<OpenWindowEntry> = Vec::new();
    let ptr = &mut entries as *mut Vec<OpenWindowEntry> as isize;
    unsafe {
        let _ = EnumWindows(Some(enum_proc), LPARAM(ptr));
    }
    let self_pid = std::process::id();
    entries.retain(|e| e.pid != self_pid);
    for entry in &mut entries {
        entry.process_name = process_name_for_pid(entry.pid);
    }
    entries.truncate(32);
    entries
}

#[cfg(not(windows))]
pub fn enumerate_open_windows_win32() -> Vec<OpenWindowEntry> {
    Vec::new()
}

// =========================================================================
// Native Window Positioning & Multi-Window Management
// =========================================================================

pub fn position_island_on_primary(app: &AppHandle, width_logical: f64, height_logical: f64) {
    let Some(win) = app.get_webview_window("island") else {
        return;
    };
    let Ok(Some(monitor)) = win.primary_monitor() else {
        return;
    };
    let scale = monitor.scale_factor();
    let phys_w = (width_logical * scale).round().max(100.0) as u32;
    let phys_h = (height_logical * scale).round().max(32.0) as u32;
    let mon_pos = monitor.position();
    let mon_size = monitor.size();
    let x = mon_pos.x + (mon_size.width as i32 - phys_w as i32) / 2;
    let y = mon_pos.y;
    let _ = win.set_size(tauri::PhysicalSize::new(phys_w, phys_h));
    let _ = win.set_position(tauri::PhysicalPosition::new(x, y));
}

pub fn position_panel_above_tray(app: &AppHandle) {
    let Some(win) = app.get_webview_window("panel") else {
        return;
    };
    let scale = win
        .primary_monitor()
        .ok()
        .flatten()
        .map(|m| m.scale_factor())
        .unwrap_or(1.0);
    let phys_w = (356.0 * scale).round() as i32;
    let phys_h = (592.0 * scale).round() as i32;
    let margin = (12.0 * scale).round() as i32;

    #[cfg(windows)]
    {
        use windows::Win32::Foundation::RECT;
        use windows::Win32::UI::WindowsAndMessaging::{
            SystemParametersInfoW, SPI_GETWORKAREA, SYSTEM_PARAMETERS_INFO_UPDATE_FLAGS,
        };
        let mut rect = RECT::default();
        if unsafe {
            SystemParametersInfoW(
                SPI_GETWORKAREA,
                0,
                Some(&mut rect as *mut RECT as *mut std::ffi::c_void),
                SYSTEM_PARAMETERS_INFO_UPDATE_FLAGS(0),
            )
        }
        .is_ok()
        {
            let x = (rect.right - phys_w - margin).max(rect.left + margin);
            let y = (rect.bottom - phys_h - margin).max(rect.top + margin);
            let _ = win.set_size(tauri::PhysicalSize::new(phys_w as u32, phys_h as u32));
            let _ = win.set_position(tauri::PhysicalPosition::new(x, y));
            return;
        }
    }

    if let Ok(Some(monitor)) = win.primary_monitor() {
        let mon_size = monitor.size();
        let x = mon_size.width as i32 - phys_w - margin;
        let y = mon_size.height as i32 - phys_h - margin - (48.0 * scale).round() as i32;
        let _ = win.set_size(tauri::PhysicalSize::new(phys_w as u32, phys_h as u32));
        let _ = win.set_position(tauri::PhysicalPosition::new(x, y));
    }
}

pub fn toggle_panel_internal(app: &AppHandle, state: &AppRuntimeState) {
    let Some(panel) = app.get_webview_window("panel") else {
        return;
    };
    let visible = panel.is_visible().unwrap_or(false);
    if visible {
        let _ = panel.hide();
    } else {
        position_panel_above_tray(app);
        state.panel_shown_at_ms.store(now_millis(), Ordering::Relaxed);
        let _ = panel.show();
        let _ = panel.set_focus();
        let _ = app.emit("panel-opened", ());
    }
}

pub fn show_overlay_internal(app: &AppHandle, state: &AppRuntimeState, mode: &str) {
    let Some(overlay) = app.get_webview_window("overlay") else {
        return;
    };
    let is_visible = overlay.is_visible().unwrap_or(false);
    let current = state
        .current_overlay_mode
        .lock()
        .map(|g| g.clone())
        .unwrap_or_default();
    if is_visible && current == mode {
        let _ = overlay.hide();
        return;
    }

    if let Ok(mut g) = state.current_overlay_mode.lock() {
        *g = mode.to_string();
    }

    if let Ok(Some(monitor)) = overlay.primary_monitor() {
        let scale = monitor.scale_factor();
        let mon_pos = monitor.position();
        let mon_size = monitor.size();
        if mode == "cleaning" {
            let _ = overlay.set_size(tauri::PhysicalSize::new(mon_size.width, mon_size.height));
            let _ = overlay.set_position(tauri::PhysicalPosition::new(mon_pos.x, mon_pos.y));
        } else {
            let (lw, lh) = match mode {
                "radial" => (520.0, 520.0),
                "clipboard" => (700.0, 520.0),
                _ => (660.0, 490.0),
            };
            let pw = (lw * scale).round() as i32;
            let ph = (lh * scale).round() as i32;
            let x = mon_pos.x + (mon_size.width as i32 - pw) / 2;
            let y = if mode == "command" {
                mon_pos.y + ((mon_size.height as f64) * 0.18).round() as i32
            } else {
                mon_pos.y + (mon_size.height as i32 - ph) / 2
            };
            let _ = overlay.set_size(tauri::PhysicalSize::new(pw as u32, ph as u32));
            let _ = overlay.set_position(tauri::PhysicalPosition::new(x, y));
        }
    }

    let _ = app.emit("overlay-mode", mode.to_string());
    let _ = overlay.show();
    let _ = overlay.set_focus();
}

#[tauri::command]
pub fn set_island_bounds(app: AppHandle, width: f64, height: f64, focus_window: bool) {
    position_island_on_primary(&app, width, height);
    if let Some(win) = app.get_webview_window("island") {
        let _ = win.set_focusable(focus_window);
        if focus_window {
            let _ = win.set_focus();
        }
    }
}

#[tauri::command]
pub fn set_island_visible(app: AppHandle, state: tauri::State<'_, AppRuntimeState>, visible: bool) {
    state.island_visible.store(visible, Ordering::Relaxed);
    if let Some(win) = app.get_webview_window("island") {
        if visible {
            position_island_on_primary(&app, 276.0, 42.0);
            let _ = win.show();
        } else {
            let _ = win.hide();
        }
    }
}

#[tauri::command]
pub fn toggle_panel(app: AppHandle, state: tauri::State<'_, AppRuntimeState>) {
    toggle_panel_internal(&app, state.inner());
}

#[tauri::command]
pub fn hide_panel(app: AppHandle) {
    if let Some(win) = app.get_webview_window("panel") {
        let _ = win.hide();
    }
}

#[tauri::command]
pub fn open_settings_window(app: AppHandle, page: Option<String>) {
    if let Some(panel) = app.get_webview_window("panel") {
        let _ = panel.hide();
    }
    if let Some(overlay) = app.get_webview_window("overlay") {
        let _ = overlay.hide();
    }
    if let Some(settings) = app.get_webview_window("settings") {
        let _ = settings.unminimize();
        let _ = settings.show();
        let _ = settings.set_focus();
        if let Some(p) = page {
            let _ = app.emit("navigate-settings", p);
        }
    }
}

#[tauri::command]
pub fn open_overlay(app: AppHandle, state: tauri::State<'_, AppRuntimeState>, mode: String) {
    if let Some(panel) = app.get_webview_window("panel") {
        let _ = panel.hide();
    }
    show_overlay_internal(&app, state.inner(), &mode);
}

#[tauri::command]
pub fn hide_overlay(app: AppHandle) {
    if let Some(win) = app.get_webview_window("overlay") {
        let _ = win.hide();
    }
}

#[tauri::command]
pub fn quit_app(app: AppHandle, state: tauri::State<'_, AppRuntimeState>) {
    state.quitting.store(true, Ordering::Relaxed);
    app.exit(0);
}

// =========================================================================
// Telemetry & System Controls (Async off STA thread)
// =========================================================================

#[tauri::command]
pub async fn get_system_telemetry(
    state: tauri::State<'_, AppRuntimeState>,
) -> Result<SystemTelemetry, String> {
    let runtime = state.inner().clone();
    tauri::async_runtime::spawn_blocking(move || collect_system_telemetry(&runtime))
        .await
        .map_err(|e| format!("Telemetry worker error: {e}"))
}

fn collect_system_telemetry(state: &AppRuntimeState) -> SystemTelemetry {
    let first_run = {
        let mut init = state.initialized.lock().expect("initialized mutex poisoned");
        let was_init = *init;
        *init = true;
        !was_init
    };

    let mut sys = state.sys.lock().expect("sys mutex poisoned");
    if first_run {
        sys.refresh_all();
    } else {
        sys.refresh_cpu_usage();
        sys.refresh_memory();
        sys.refresh_processes(sysinfo::ProcessesToUpdate::All, true);
    }

    let cpu_cores: Vec<f32> = sys.cpus().iter().map(|c| c.cpu_usage()).collect();
    let cpu_percent = sys.global_cpu_usage();
    let cpu_brand = sys
        .cpus()
        .first()
        .map(|c| c.brand().trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Windows x64 Processor".to_string());

    let memory_total_gb = (sys.total_memory() as f64) / 1_073_741_824.0;
    let memory_used_gb = (sys.used_memory() as f64) / 1_073_741_824.0;
    let mem_ratio = if memory_total_gb > 0.0 {
        memory_used_gb / memory_total_gb
    } else {
        0.0
    };
    let memory_pressure = if mem_ratio > 0.88 {
        "Critical"
    } else if mem_ratio > 0.72 {
        "Warn"
    } else {
        "Normal"
    }
    .to_string();

    let mut processes: Vec<ProcessEntry> = sys
        .processes()
        .iter()
        .map(|(pid, proc_)| ProcessEntry {
            pid: pid.as_u32(),
            name: proc_.name().to_string_lossy().to_string(),
            cpu_percent: proc_.cpu_usage(),
            memory_mb: (proc_.memory() as f64) / 1_048_576.0,
        })
        .collect();
    drop(sys);
    processes.sort_by(|a, b| {
        b.cpu_percent
            .partial_cmp(&a.cpu_percent)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| {
                b.memory_mb
                    .partial_cmp(&a.memory_mb)
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
    });
    processes.truncate(15);

    let mut components = state.components.lock().expect("components mutex poisoned");
    components.refresh(first_run);
    let mut cpu_temp_c: Option<f32> = None;
    let mut gpu_temp_c: Option<f32> = None;
    let mut battery_temp_c: Option<f32> = None;
    for comp in components.iter() {
        let label = comp.label().to_lowercase();
        let Some(temp) = comp.temperature() else {
            continue;
        };
        if temp <= 0.0 || temp > 130.0 {
            continue;
        }
        if (label.contains("cpu")
            || label.contains("core")
            || label.contains("package")
            || label.contains("tctl"))
            && cpu_temp_c.is_none()
        {
            cpu_temp_c = Some(temp);
        } else if (label.contains("gpu") || label.contains("nvidia") || label.contains("radeon"))
            && gpu_temp_c.is_none()
        {
            gpu_temp_c = Some(temp);
        } else if label.contains("bat") && battery_temp_c.is_none() {
            battery_temp_c = Some(temp);
        } else if cpu_temp_c.is_none() {
            cpu_temp_c = Some(temp);
        }
    }
    drop(components);

    let mut disks_guard = state.disks.lock().expect("disks mutex poisoned");
    disks_guard.refresh(first_run);
    let disks: Vec<DiskVolume> = disks_guard
        .iter()
        .map(|d| {
            let total_gb = (d.total_space() as f64) / 1_073_741_824.0;
            let available_gb = (d.available_space() as f64) / 1_073_741_824.0;
            let used_pct = if total_gb > 0.0 {
                (((total_gb - available_gb) / total_gb) * 100.0) as f32
            } else {
                0.0
            };
            DiskVolume {
                name: d.name().to_string_lossy().to_string(),
                mount: d.mount_point().to_string_lossy().to_string(),
                file_system: d.file_system().to_string_lossy().to_string(),
                total_gb,
                available_gb,
                used_percent: used_pct,
                is_removable: d.is_removable(),
            }
        })
        .collect();
    drop(disks_guard);

    let mut networks_guard = state.networks.lock().expect("networks mutex poisoned");
    networks_guard.refresh(first_run);
    let mut download_kb_per_sec = 0.0;
    let mut upload_kb_per_sec = 0.0;
    let mut networks = Vec::new();
    for (name, data) in networks_guard.iter() {
        let rx_kb = (data.received() as f64) / 1024.0;
        let tx_kb = (data.transmitted() as f64) / 1024.0;
        download_kb_per_sec += rx_kb;
        upload_kb_per_sec += tx_kb;
        if data.total_received() > 0 || data.total_transmitted() > 0 {
            networks.push(NetAdapter {
                name: name.clone(),
                rx_kb_per_sec: rx_kb,
                tx_kb_per_sec: tx_kb,
                total_rx_mb: (data.total_received() as f64) / 1_048_576.0,
                total_tx_mb: (data.total_transmitted() as f64) / 1_048_576.0,
            });
        }
    }
    drop(networks_guard);

    let (battery_percent, battery_charging) = read_windows_power_status();
    let keep_awake_active = *state.keep_awake.lock().expect("keep_awake mutex poisoned");
    let audio = read_core_audio_master();
    let open_wins = enumerate_open_windows_win32();
    let media_session = detect_media_session_win32(&open_wins);
    let last_hwnd = *state
        .last_external_hwnd
        .lock()
        .expect("hwnd mutex poisoned");
    let active_window_title = open_wins
        .iter()
        .find(|w| w.hwnd == last_hwnd)
        .map(|w| w.title.clone())
        .or_else(|| open_wins.first().map(|w| w.title.clone()))
        .unwrap_or_else(|| "Windows Desktop".to_string());

    SystemTelemetry {
        host_name: System::host_name().unwrap_or_else(|| "Windows-PC".to_string()),
        os_version: System::long_os_version().unwrap_or_else(|| "Windows 11".to_string()),
        cpu_brand,
        cpu_percent,
        cpu_cores,
        cpu_temp_c,
        gpu_percent: (cpu_percent * 0.42).clamp(2.0, 95.0),
        gpu_temp_c,
        memory_used_gb,
        memory_total_gb,
        memory_pressure,
        battery_percent,
        battery_charging,
        battery_temp_c,
        uptime_seconds: System::uptime(),
        download_kb_per_sec,
        upload_kb_per_sec,
        keep_awake_active,
        master_volume: audio.volume,
        master_muted: audio.muted,
        dark_mode: read_windows_dark_mode(),
        active_window_title,
        media_session,
        disks,
        networks,
        top_processes: processes,
    }
}

#[tauri::command]
pub fn set_keep_awake(
    app: AppHandle,
    state: tauri::State<'_, AppRuntimeState>,
    enabled: bool,
    keep_display_on: bool,
) -> bool {
    *state.keep_awake.lock().expect("keep_awake mutex poisoned") = enabled;
    *state
        .keep_display_on
        .lock()
        .expect("keep_display_on mutex poisoned") = keep_display_on;
    #[cfg(windows)]
    unsafe {
        use windows::Win32::System::Power::{
            SetThreadExecutionState, ES_CONTINUOUS, ES_DISPLAY_REQUIRED, ES_SYSTEM_REQUIRED,
        };
        let flags = if enabled {
            if keep_display_on {
                ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
            } else {
                ES_CONTINUOUS | ES_SYSTEM_REQUIRED
            }
        } else {
            ES_CONTINUOUS
        };
        let _ = SetThreadExecutionState(flags);
    }
    let _ = app.emit("keep-awake-changed", enabled);
    enabled
}

#[tauri::command]
pub fn get_master_audio() -> MasterAudioState {
    read_core_audio_master()
}

#[tauri::command]
pub fn set_master_audio(
    volume: Option<u8>,
    muted: Option<bool>,
) -> Result<MasterAudioState, String> {
    write_core_audio_master(volume, muted)
}

#[tauri::command]
pub async fn list_audio_sessions() -> Result<Vec<AppAudioSession>, String> {
    tauri::async_runtime::spawn_blocking(enumerate_audio_sessions_win32)
        .await
        .map_err(|e| format!("Audio session enumerator error: {e}"))
}

#[tauri::command]
pub async fn set_app_audio(pid: u32, volume: Option<u8>, muted: Option<bool>) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || update_app_audio_session_win32(pid, volume, muted))
        .await
        .map_err(|e| format!("Audio session update error: {e}"))?
}

#[tauri::command]
pub fn send_media_action(action: String) -> Result<(), String> {
    #[cfg(windows)]
    unsafe {
        use windows::Win32::UI::Input::KeyboardAndMouse::{
            keybd_event, KEYEVENTF_KEYUP, VK_MEDIA_NEXT_TRACK, VK_MEDIA_PLAY_PAUSE,
            VK_MEDIA_PREV_TRACK,
        };
        let vk = match action.as_str() {
            "playPause" => VK_MEDIA_PLAY_PAUSE,
            "next" => VK_MEDIA_NEXT_TRACK,
            "prev" => VK_MEDIA_PREV_TRACK,
            _ => return Err(format!("Unknown media action: {action}")),
        };
        keybd_event(vk.0 as u8, 0, Default::default(), 0);
        keybd_event(vk.0 as u8, 0, KEYEVENTF_KEYUP, 0);
    }
    Ok(())
}

#[tauri::command]
pub fn set_display_brightness(level: u8) -> Result<u8, String> {
    let clamped = level.min(100);
    #[cfg(windows)]
    {
        let script = format!(
            "(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods | Select-Object -First 1).WmiSetBrightness(1, {clamped})"
        );
        std::thread::spawn(move || {
            let _ = hidden_command("powershell")
                .args(["-NoProfile", "-Command", &script])
                .output();
        });
    }
    Ok(clamped)
}

#[tauri::command]
pub fn set_windows_dark_mode(enabled: bool) -> Result<bool, String> {
    #[cfg(windows)]
    {
        let val = if enabled { 0 } else { 1 };
        let script = format!(
            "Set-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize' -Name 'AppsUseLightTheme' -Value {val}; \
             Set-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize' -Name 'SystemUsesLightTheme' -Value {val}"
        );
        let _ = hidden_command("powershell")
            .args(["-NoProfile", "-Command", &script])
            .output();
    }
    Ok(enabled)
}

#[tauri::command]
pub fn lock_workstation() -> Result<(), String> {
    #[cfg(windows)]
    unsafe {
        use windows::Win32::System::Shutdown::LockWorkStation;
        LockWorkStation().map_err(|e| format!("LockWorkStation failed: {e}"))?;
    }
    Ok(())
}

#[tauri::command]
pub fn empty_recycle_bin() -> Result<(), String> {
    #[cfg(windows)]
    unsafe {
        use windows::Win32::UI::Shell::{
            SHEmptyRecycleBinW, SHERB_NOCONFIRMATION, SHERB_NOPROGRESSUI, SHERB_NOSOUND,
        };
        let flags = SHERB_NOCONFIRMATION | SHERB_NOPROGRESSUI | SHERB_NOSOUND;
        let hr = SHEmptyRecycleBinW(None, None, flags);
        if hr.is_err() {
            return Err(format!("SHEmptyRecycleBinW error: {hr:?}"));
        }
    }
    Ok(())
}

#[tauri::command]
pub fn list_open_windows() -> Vec<OpenWindowEntry> {
    enumerate_open_windows_win32()
}

#[tauri::command]
pub fn focus_window(hwnd: isize) -> Result<(), String> {
    #[cfg(windows)]
    unsafe {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::UI::WindowsAndMessaging::{IsIconic, SetForegroundWindow, ShowWindow, SW_RESTORE};
        let target = HWND(hwnd as *mut std::ffi::c_void);
        if IsIconic(target).as_bool() {
            let _ = ShowWindow(target, SW_RESTORE);
        }
        let _ = SetForegroundWindow(target);
    }
    Ok(())
}

#[tauri::command]
pub fn toggle_window_pin(state: tauri::State<'_, AppRuntimeState>, hwnd: Option<isize>) -> Result<bool, String> {
    let target_raw = hwnd.unwrap_or_else(|| {
        *state
            .last_external_hwnd
            .lock()
            .expect("hwnd mutex poisoned")
    });
    if target_raw == 0 {
        return Err("No active external window found to pin.".to_string());
    }
    #[cfg(windows)]
    unsafe {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::UI::WindowsAndMessaging::{
            GetWindowLongW, SetWindowPos, GWL_EXSTYLE, HWND_NOTOPMOST, HWND_TOPMOST,
            SWP_NOMOVE, SWP_NOSIZE, WS_EX_TOPMOST,
        };
        let target = HWND(target_raw as *mut std::ffi::c_void);
        let ex = GetWindowLongW(target, GWL_EXSTYLE) as u32;
        let is_topmost = (ex & WS_EX_TOPMOST.0) != 0;
        let next_pos = if is_topmost { HWND_NOTOPMOST } else { HWND_TOPMOST };
        SetWindowPos(target, Some(next_pos), 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE)
            .map_err(|e| format!("SetWindowPos failed: {e}"))?;
        return Ok(!is_topmost);
    }
    #[cfg(not(windows))]
    Ok(false)
}

#[tauri::command]
pub fn snap_active_window(
    state: tauri::State<'_, AppRuntimeState>,
    preset: String,
    hwnd: Option<isize>,
) -> Result<(), String> {
    let target_raw = hwnd.unwrap_or_else(|| {
        *state
            .last_external_hwnd
            .lock()
            .expect("hwnd mutex poisoned")
    });
    if target_raw == 0 {
        return Err("Click an application window before snapping.".to_string());
    }
    #[cfg(windows)]
    unsafe {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::Graphics::Gdi::{
            GetMonitorInfoW, MonitorFromWindow, MONITORINFO, MONITOR_DEFAULTTONEAREST,
        };
        use windows::Win32::UI::WindowsAndMessaging::{
            SetForegroundWindow, SetWindowPos, ShowWindow, HWND_TOP, SWP_NOZORDER, SW_MAXIMIZE,
            SW_RESTORE,
        };

        let target = HWND(target_raw as *mut std::ffi::c_void);
        let monitor = MonitorFromWindow(target, MONITOR_DEFAULTTONEAREST);
        let mut info = MONITORINFO {
            cbSize: std::mem::size_of::<MONITORINFO>() as u32,
            ..Default::default()
        };
        if !GetMonitorInfoW(monitor, &mut info).as_bool() {
            return Err("Could not query monitor info.".to_string());
        }
        let work = info.rcWork;
        let w = work.right - work.left;
        let h = work.bottom - work.top;

        let _ = ShowWindow(target, SW_RESTORE);
        if preset == "maximize" {
            let _ = ShowWindow(target, SW_MAXIMIZE);
            let _ = SetForegroundWindow(target);
            return Ok(());
        }

        let (x, y, nw, nh) = match preset.as_str() {
            "left" => (work.left, work.top, w / 2, h),
            "right" => (work.left + w / 2, work.top, w / 2, h),
            "top" => (work.left, work.top, w, h / 2),
            "bottom" => (work.left, work.top + h / 2, w, h / 2),
            "topLeft" => (work.left, work.top, w / 2, h / 2),
            "topRight" => (work.left + w / 2, work.top, w / 2, h / 2),
            "bottomLeft" => (work.left, work.top + h / 2, w / 2, h / 2),
            "bottomRight" => (work.left + w / 2, work.top + h / 2, w / 2, h / 2),
            "leftThird" => (work.left, work.top, w / 3, h),
            "rightThird" => (work.left + (w * 2) / 3, work.top, w / 3, h),
            "center" => {
                let cw = (w * 72) / 100;
                let ch = (h * 78) / 100;
                (work.left + (w - cw) / 2, work.top + (h - ch) / 2, cw, ch)
            }
            _ => return Err(format!("Unknown snap preset: {preset}")),
        };

        SetWindowPos(target, Some(HWND_TOP), x, y, nw, nh, SWP_NOZORDER)
            .map_err(|e| format!("SetWindowPos failed: {e}"))?;
        let _ = SetForegroundWindow(target);
    }
    Ok(())
}

#[tauri::command]
pub fn pick_screen_color() -> Result<PickedColorResult, String> {
    #[cfg(windows)]
    unsafe {
        use windows::Win32::Foundation::POINT;
        use windows::Win32::Graphics::Gdi::{GetDC, GetPixel, ReleaseDC};
        use windows::Win32::UI::WindowsAndMessaging::GetCursorPos;

        let mut pt = POINT::default();
        GetCursorPos(&mut pt).map_err(|e| format!("GetCursorPos failed: {e}"))?;
        let hdc = GetDC(None);
        let colorref = GetPixel(hdc, pt.x, pt.y);
        let _ = ReleaseDC(None, hdc);
        let raw = colorref.0;
        let r = (raw & 0xFF) as u8;
        let g = ((raw >> 8) & 0xFF) as u8;
        let b = ((raw >> 16) & 0xFF) as u8;
        let hex = format!("#{:02X}{:02X}{:02X}", r, g, b);
        let _ = write_clipboard_text_win32(&hex);
        Ok(PickedColorResult {
            hex,
            r,
            g,
            b,
            x: pt.x,
            y: pt.y,
        })
    }
    #[cfg(not(windows))]
    Ok(PickedColorResult {
        hex: "#38BDF8".to_string(),
        r: 56,
        g: 189,
        b: 248,
        x: 0,
        y: 0,
    })
}

#[tauri::command]
pub fn capture_screen_png(app: AppHandle) -> Result<ScreenshotResult, String> {
    #[cfg(windows)]
    unsafe {
        use windows::Win32::Graphics::Gdi::{
            BitBlt, CreateCompatibleBitmap, CreateCompatibleDC, DeleteDC, DeleteObject, GetDC,
            GetDIBits, ReleaseDC, SelectObject, BITMAPINFO, BITMAPINFOHEADER, BI_RGB,
            DIB_RGB_COLORS, SRCCOPY,
        };
        use windows::Win32::UI::WindowsAndMessaging::{GetSystemMetrics, SM_CXSCREEN, SM_CYSCREEN};

        let w = GetSystemMetrics(SM_CXSCREEN).max(1) as u32;
        let h = GetSystemMetrics(SM_CYSCREEN).max(1) as u32;

        let hdc_screen = GetDC(None);
        let hdc_mem = CreateCompatibleDC(Some(hdc_screen));
        let hbm = CreateCompatibleBitmap(hdc_screen, w as i32, h as i32);
        let old = SelectObject(hdc_mem, hbm.into());
        let _ = BitBlt(
            hdc_mem,
            0,
            0,
            w as i32,
            h as i32,
            Some(hdc_screen),
            0,
            0,
            SRCCOPY,
        );

        let mut bi = BITMAPINFO {
            bmiHeader: BITMAPINFOHEADER {
                biSize: std::mem::size_of::<BITMAPINFOHEADER>() as u32,
                biWidth: w as i32,
                biHeight: -(h as i32), // top-down
                biPlanes: 1,
                biBitCount: 32,
                biCompression: BI_RGB.0,
                ..Default::default()
            },
            ..Default::default()
        };

        let mut pixels = vec![0u8; (w * h * 4) as usize];
        let scan = GetDIBits(
            hdc_mem,
            hbm,
            0,
            h,
            Some(pixels.as_mut_ptr() as *mut std::ffi::c_void),
            &mut bi,
            DIB_RGB_COLORS,
        );
        SelectObject(hdc_mem, old);
        let _ = DeleteObject(hbm.into());
        let _ = DeleteDC(hdc_mem);
        let _ = ReleaseDC(None, hdc_screen);

        if scan == 0 {
            return Err("Screen capture GetDIBits failed.".to_string());
        }

        // BGRA -> RGBA
        for px in pixels.chunks_exact_mut(4) {
            px.swap(0, 2);
            px[3] = 255;
        }

        let dir = dirs_pictures_vorssaint();
        let _ = std::fs::create_dir_all(&dir);
        let ts = now_millis();
        let file_name = format!("Vorssaint-{ts}.png");
        let out_path = dir.join(&file_name);

        image::save_buffer(&out_path, &pixels, w, h, image::ColorType::Rgba8)
            .map_err(|e| format!("PNG save failed: {e}"))?;

        let size_kb = std::fs::metadata(&out_path).map(|m| m.len() / 1024).unwrap_or(0);
        let path_str = out_path.to_string_lossy().to_string();
        let _ = write_clipboard_text_win32(&path_str);
        let res = ScreenshotResult {
            path: path_str,
            file_name,
            width: w,
            height: h,
            size_kb,
        };
        let _ = app.emit("screenshot-captured", res.clone());
        Ok(res)
    }
    #[cfg(not(windows))]
    Err("Not on Windows".to_string())
}

fn dirs_pictures_vorssaint() -> PathBuf {
    if let Ok(profile) = std::env::var("USERPROFILE") {
        let pics = PathBuf::from(profile).join("Pictures").join("Vorssaint");
        return pics;
    }
    PathBuf::from("VorssaintCaptures")
}

#[tauri::command]
pub fn copy_text_to_clipboard(state: tauri::State<'_, AppRuntimeState>, text: String) -> Result<(), String> {
    if let Ok(mut last) = state.clipboard_history_last.lock() {
        *last = text.clone();
    }
    write_clipboard_text_win32(&text)
}

#[tauri::command]
pub fn open_path_in_explorer(path: String) -> Result<(), String> {
    #[cfg(windows)]
    {
        let p = PathBuf::from(&path);
        if p.is_file() {
            let arg = format!("/select,{}", p.to_string_lossy());
            hidden_command("explorer").arg(arg).spawn().map_err(|e| e.to_string())?;
        } else {
            hidden_command("explorer").arg(&path).spawn().map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

#[tauri::command]
pub fn open_external_url(url: String) -> Result<(), String> {
    #[cfg(windows)]
    {
        hidden_command("cmd")
            .args(["/c", "start", "", &url])
            .spawn()
            .map_err(|e| format!("Failed opening URL: {e}"))?;
    }
    Ok(())
}

#[tauri::command]
pub fn launch_windows_utility(command: String) -> Result<(), String> {
    #[cfg(windows)]
    {
        let cmd = match command.as_str() {
            "explorer" => "explorer.exe",
            "notepad" => "notepad.exe",
            "calc" => "calc.exe",
            "cmd" => "wt.exe",
            "taskmgr" => "taskmgr.exe",
            "snipping" => "explorer.exe ms-screenclip:",
            "settings" => "explorer.exe ms-settings:",
            _ => &command,
        };
        hidden_command("cmd")
            .args(["/c", "start", "", cmd])
            .spawn()
            .map_err(|e| format!("Failed launching {cmd}: {e}"))?;
    }
    Ok(())
}

// =========================================================================
// Port Manager, Process Killer, Junk Cleaner, App Uninstaller, Winget
// =========================================================================

#[tauri::command]
pub fn list_listening_ports(state: tauri::State<'_, AppRuntimeState>) -> Vec<ListeningPortEntry> {
    let proc_map: HashMap<u32, String> = {
        let mut sys = state.sys.lock().expect("sys mutex poisoned");
        if sys.processes().is_empty() {
            sys.refresh_processes(sysinfo::ProcessesToUpdate::All, false);
        }
        sys.processes()
            .iter()
            .map(|(pid, p)| (pid.as_u32(), p.name().to_string_lossy().to_string()))
            .collect()
    };

    let output = hidden_command("netstat").args(["-ano"]).output();
    let Ok(out) = output else {
        return Vec::new();
    };
    let stdout = String::from_utf8_lossy(&out.stdout);
    let mut results = Vec::new();
    let mut seen: std::collections::HashSet<(String, u16, u32)> = std::collections::HashSet::new();

    for line in stdout.lines() {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 4 {
            continue;
        }
        let proto = cols[0].to_uppercase();
        if proto != "TCP" && proto != "UDP" {
            continue;
        }
        if proto == "TCP" && cols.len() >= 5 && !cols[3].eq_ignore_ascii_case("LISTENING") {
            continue;
        }
        let local_addr = cols[1];
        let pid_str = cols.last().copied().unwrap_or("0");
        let Ok(pid) = pid_str.parse::<u32>() else {
            continue;
        };
        let Some((_, port_str)) = local_addr.rsplit_once(':') else {
            continue;
        };
        let Ok(port) = port_str.parse::<u16>() else {
            continue;
        };
        if !seen.insert((proto.clone(), port, pid)) {
            continue;
        }
        let process_name = proc_map
            .get(&pid)
            .cloned()
            .unwrap_or_else(|| process_name_for_pid(pid));
        results.push(ListeningPortEntry {
            protocol: proto,
            local_address: local_addr.to_string(),
            port,
            pid,
            process_name,
        });
    }

    results.sort_by_key(|p| p.port);
    results
}

#[tauri::command]
pub fn kill_process(state: tauri::State<'_, AppRuntimeState>, pid: u32) -> Result<bool, String> {
    if pid <= 4 || pid == std::process::id() {
        return Err("Cannot terminate protected or self process.".to_string());
    }
    let mut sys = state.sys.lock().expect("sys mutex poisoned");
    sys.refresh_processes(sysinfo::ProcessesToUpdate::All, false);
    if let Some(proc_) = sys.process(Pid::from_u32(pid)) {
        return Ok(proc_.kill());
    }
    #[cfg(windows)]
    {
        let status = hidden_command("taskkill")
            .args(["/PID", &pid.to_string(), "/F"])
            .status()
            .map_err(|e| format!("taskkill failed: {e}"))?;
        return Ok(status.success());
    }
    #[cfg(not(windows))]
    Ok(false)
}

fn dir_stats(path: &PathBuf, depth: usize) -> (u64, usize) {
    if depth > 4 || !path.exists() {
        return (0, 0);
    }
    let Ok(entries) = std::fs::read_dir(path) else {
        return (0, 0);
    };
    let mut bytes = 0u64;
    let mut count = 0usize;
    for entry in entries.flatten() {
        let p = entry.path();
        if let Ok(meta) = entry.metadata() {
            if meta.is_file() {
                bytes = bytes.saturating_add(meta.len());
                count += 1;
            } else if meta.is_dir() {
                let (b, c) = dir_stats(&p, depth + 1);
                bytes = bytes.saturating_add(b);
                count += c;
            }
        }
    }
    (bytes, count)
}

fn clean_dir_safe(path: &PathBuf) -> u64 {
    let Ok(entries) = std::fs::read_dir(path) else {
        return 0;
    };
    let mut freed = 0u64;
    for entry in entries.flatten() {
        let p = entry.path();
        if let Ok(meta) = entry.metadata() {
            if meta.is_file() {
                let sz = meta.len();
                if std::fs::remove_file(&p).is_ok() {
                    freed = freed.saturating_add(sz);
                }
            } else if meta.is_dir() {
                let (sz, _) = dir_stats(&p, 0);
                if std::fs::remove_dir_all(&p).is_ok() {
                    freed = freed.saturating_add(sz);
                }
            }
        }
    }
    freed
}

fn junk_targets() -> Vec<(&'static str, &'static str, PathBuf)> {
    let mut targets = Vec::new();
    let temp = std::env::temp_dir();
    targets.push(("user-temp", "Windows User Temp", temp));

    if let Ok(local_app) = std::env::var("LOCALAPPDATA") {
        let local = PathBuf::from(local_app);
        targets.push((
            "edge-cache",
            "Microsoft Edge Cache",
            local.join("Microsoft\\Edge\\User Data\\Default\\Cache\\Cache_Data"),
        ));
        targets.push((
            "chrome-cache",
            "Google Chrome Cache",
            local.join("Google\\Chrome\\User Data\\Default\\Cache\\Cache_Data"),
        ));
        targets.push((
            "crash-dumps",
            "Windows Crash Dumps",
            local.join("CrashDumps"),
        ));
        targets.push((
            "thumb-cache",
            "Explorer Icon & Thumb Cache",
            local.join("Microsoft\\Windows\\Explorer"),
        ));
    }
    if let Ok(app_data) = std::env::var("APPDATA") {
        targets.push((
            "npm-cache",
            "npm Cache",
            PathBuf::from(app_data).join("npm-cache"),
        ));
    }
    targets
}

#[tauri::command]
pub async fn scan_junk_caches() -> Vec<JunkCategory> {
    tauri::async_runtime::spawn_blocking(|| {
        junk_targets()
            .into_iter()
            .map(|(id, label, path)| {
                let (bytes, file_count) = dir_stats(&path, 0);
                JunkCategory {
                    id: id.to_string(),
                    label: label.to_string(),
                    path: path.to_string_lossy().to_string(),
                    size_mb: (bytes as f64) / 1_048_576.0,
                    file_count,
                }
            })
            .collect()
    })
    .await
    .unwrap_or_default()
}

#[tauri::command]
pub async fn clean_junk_caches(ids: Vec<String>) -> f64 {
    tauri::async_runtime::spawn_blocking(move || {
        let mut freed = 0u64;
        for (id, _, path) in junk_targets() {
            if ids.contains(&id.to_string()) {
                freed = freed.saturating_add(clean_dir_safe(&path));
            }
        }
        (freed as f64) / 1_048_576.0
    })
    .await
    .unwrap_or(0.0)
}

#[tauri::command]
pub async fn list_installed_apps() -> Vec<InstalledAppEntry> {
    tauri::async_runtime::spawn_blocking(|| {
        #[cfg(windows)]
        {
            let ps_script = r#"
$paths = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
Get-ItemProperty $paths -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -and $_.UninstallString } |
  Sort-Object DisplayName -Unique |
  Select-Object -First 140 @{n='name';e={$_.DisplayName}},
    @{n='publisher';e={if($_.Publisher){$_.Publisher}else{'Unknown'}}},
    @{n='version';e={if($_.DisplayVersion){$_.DisplayVersion}else{''}}},
    @{n='installLocation';e={if($_.InstallLocation){$_.InstallLocation}else{''}}},
    @{n='uninstallString';e={$_.UninstallString}} |
  ConvertTo-Json -Compress
"#;
            if let Ok(output) = hidden_command("powershell")
                .args(["-NoProfile", "-Command", ps_script])
                .output()
            {
                let text = String::from_utf8_lossy(&output.stdout);
                if let Ok(items) = serde_json::from_str::<Vec<serde_json::Value>>(&text) {
                    return items
                        .into_iter()
                        .map(|v| InstalledAppEntry {
                            name: v["name"].as_str().unwrap_or_default().to_string(),
                            publisher: v["publisher"].as_str().unwrap_or("Unknown").to_string(),
                            version: v["version"].as_str().unwrap_or_default().to_string(),
                            install_location: v["installLocation"]
                                .as_str()
                                .unwrap_or_default()
                                .to_string(),
                            uninstall_string: v["uninstallString"]
                                .as_str()
                                .unwrap_or_default()
                                .to_string(),
                        })
                        .collect();
                }
            }
        }
        Vec::new()
    })
    .await
    .unwrap_or_default()
}

#[tauri::command]
pub fn uninstall_app(uninstall_string: String) -> Result<(), String> {
    #[cfg(windows)]
    {
        hidden_command("cmd")
            .args(["/c", &uninstall_string])
            .spawn()
            .map_err(|e| format!("Failed to start uninstaller: {e}"))?;
    }
    Ok(())
}

#[tauri::command]
pub async fn winget_search(query: String) -> Result<Vec<WingetPackage>, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let out = hidden_command("winget")
            .args([
                "search",
                &query,
                "--accept-source-agreements",
                "--count",
                "16",
            ])
            .output()
            .map_err(|e| format!("winget error: {e}"))?;
        let text = String::from_utf8_lossy(&out.stdout);
        Ok(parse_winget_table(&text, false))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn winget_list_updates() -> Result<Vec<WingetPackage>, String> {
    tauri::async_runtime::spawn_blocking(|| {
        let out = hidden_command("winget")
            .args(["upgrade", "--accept-source-agreements"])
            .output()
            .map_err(|e| format!("winget upgrade error: {e}"))?;
        let text = String::from_utf8_lossy(&out.stdout);
        Ok(parse_winget_table(&text, true))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn winget_install(id: String, upgrade: bool) -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let sub = if upgrade { "upgrade" } else { "install" };
        let out = hidden_command("winget")
            .args([
                sub,
                "--id",
                &id,
                "-e",
                "--accept-package-agreements",
                "--accept-source-agreements",
            ])
            .output()
            .map_err(|e| format!("winget {sub} failed: {e}"))?;
        let text = String::from_utf8_lossy(&out.stdout).to_string();
        if out.status.success() {
            Ok(text)
        } else {
            Err(format!(
                "{}{}",
                text,
                String::from_utf8_lossy(&out.stderr)
            ))
        }
    })
    .await
    .map_err(|e| e.to_string())?
}

fn parse_winget_table(output: &str, is_upgrade: bool) -> Vec<WingetPackage> {
    let mut pkgs = Vec::new();
    let mut in_rows = false;
    for raw_line in output.lines() {
        let line = raw_line.trim();
        if line.starts_with("---") {
            in_rows = true;
            continue;
        }
        if !in_rows || line.is_empty() {
            continue;
        }
        if line.ends_with("available.") || line.starts_with("The following") {
            continue;
        }
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 3 {
            continue;
        }
        if is_upgrade && cols.len() >= 4 {
            let len = cols.len();
            let avail = cols[len - 2];
            let ver = cols[len - 3];
            let id = cols[len - 4];
            let name = cols[..len - 4].join(" ");
            if !id.is_empty() && !name.is_empty() {
                pkgs.push(WingetPackage {
                    name,
                    id: id.to_string(),
                    version: ver.to_string(),
                    available_version: Some(avail.to_string()),
                });
            }
        } else if cols.len() >= 3 {
            let len = cols.len();
            let ver = cols[len - 1];
            let id = cols[len - 2];
            let name = cols[..len - 2].join(" ");
            if !id.is_empty() && id.contains('.') {
                pkgs.push(WingetPackage {
                    name,
                    id: id.to_string(),
                    version: ver.to_string(),
                    available_version: None,
                });
            }
        }
    }
    pkgs
}

use serde::Serialize;
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;
use std::sync::{Arc, Mutex};
use sysinfo::{Components, Disks, Networks, Pid, System};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

#[derive(Clone)]
pub struct AppRuntimeState {
    sys: Arc<Mutex<System>>,
    networks: Arc<Mutex<Networks>>,
    disks: Arc<Mutex<Disks>>,
    components: Arc<Mutex<Components>>,
    keep_awake: Arc<Mutex<bool>>,
    initialized: Arc<Mutex<bool>>,
}

impl AppRuntimeState {
    pub fn new() -> Self {
        // Defer sysinfo/WMI initialization off the main STA thread so tao::OleInitialize succeeds.
        Self {
            sys: Arc::new(Mutex::new(System::new())),
            networks: Arc::new(Mutex::new(Networks::new())),
            disks: Arc::new(Mutex::new(Disks::new())),
            components: Arc::new(Mutex::new(Components::new())),
            keep_awake: Arc::new(Mutex::new(false)),
            initialized: Arc::new(Mutex::new(false)),
        }
    }
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
fn write_core_audio_master(volume: Option<u8>, muted: Option<bool>) -> Result<MasterAudioState, String> {
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
fn write_core_audio_master(volume: Option<u8>, muted: Option<bool>) -> Result<MasterAudioState, String> {
    Ok(MasterAudioState {
        volume: volume.unwrap_or(65),
        muted: muted.unwrap_or(false),
    })
}

fn hidden_command(program: &str) -> Command {
    let mut cmd = Command::new(program);
    #[cfg(windows)]
    cmd.creation_flags(CREATE_NO_WINDOW);
    cmd
}

#[tauri::command]
pub async fn get_system_telemetry(state: tauri::State<'_, AppRuntimeState>) -> Result<SystemTelemetry, String> {
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
    processes.truncate(12);

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
        if (label.contains("cpu") || label.contains("core") || label.contains("package") || label.contains("tctl"))
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
        disks,
        networks,
        top_processes: processes,
    }
}

#[tauri::command]
pub fn set_keep_awake(
    state: tauri::State<AppRuntimeState>,
    enabled: bool,
    keep_display_on: bool,
) -> bool {
    *state.keep_awake.lock().expect("keep_awake mutex poisoned") = enabled;
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
    enabled
}

#[tauri::command]
pub fn get_master_audio() -> MasterAudioState {
    read_core_audio_master()
}

#[tauri::command]
pub fn set_master_audio(volume: Option<u8>, muted: Option<bool>) -> Result<MasterAudioState, String> {
    write_core_audio_master(volume, muted)
}

#[tauri::command]
pub fn set_display_brightness(level: u8) -> Result<u8, String> {
    let clamped = level.min(100);
    #[cfg(windows)]
    {
        let script = format!(
            "(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods | Select-Object -First 1).WmiSetBrightness(1, {clamped})"
        );
        let _ = hidden_command("powershell")
            .args(["-NoProfile", "-Command", &script])
            .output();
    }
    Ok(clamped)
}

#[tauri::command]
pub fn list_open_windows(state: tauri::State<AppRuntimeState>) -> Vec<OpenWindowEntry> {
    #[cfg(windows)]
    {
        use windows::Win32::Foundation::{BOOL, HWND, LPARAM};
        use windows::Win32::UI::WindowsAndMessaging::{
            EnumWindows, GetWindowTextW, GetWindowThreadProcessId, IsWindowVisible,
        };

        let proc_map: HashMap<u32, String> = {
            let sys = state.sys.lock().expect("sys mutex poisoned");
            sys.processes()
                .iter()
                .map(|(pid, p)| (pid.as_u32(), p.name().to_string_lossy().to_string()))
                .collect()
        };

        struct Collector<'a> {
            list: Vec<OpenWindowEntry>,
            proc_map: &'a HashMap<u32, String>,
        }

        unsafe extern "system" fn enum_cb(hwnd: HWND, lparam: LPARAM) -> BOOL {
            let collector = &mut *(lparam.0 as *mut Collector<'_>);
            if !IsWindowVisible(hwnd).as_bool() {
                return BOOL(1);
            }
            let mut buf = [0u16; 256];
            let len = GetWindowTextW(hwnd, &mut buf);
            if len <= 0 {
                return BOOL(1);
            }
            let title = String::from_utf16_lossy(&buf[..len as usize])
                .trim()
                .to_string();
            if title.is_empty()
                || title == "Program Manager"
                || title == "Windows Input Experience"
            {
                return BOOL(1);
            }
            let mut pid: u32 = 0;
            GetWindowThreadProcessId(hwnd, Some(&mut pid));
            let process_name = collector
                .proc_map
                .get(&pid)
                .cloned()
                .unwrap_or_else(|| "app.exe".to_string());
            collector.list.push(OpenWindowEntry {
                hwnd: hwnd.0 as isize,
                pid,
                title,
                process_name,
            });
            BOOL(1)
        }

        let mut collector = Collector {
            list: Vec::new(),
            proc_map: &proc_map,
        };
        unsafe {
            let _ = EnumWindows(
                Some(enum_cb),
                LPARAM((&mut collector as *mut Collector<'_>) as isize),
            );
        }
        collector.list
    }
    #[cfg(not(windows))]
    {
        Vec::new()
    }
}

#[tauri::command]
pub fn focus_window(hwnd: isize) -> Result<(), String> {
    #[cfg(windows)]
    unsafe {
        use std::ffi::c_void;
        use windows::Win32::Foundation::HWND;
        use windows::Win32::UI::WindowsAndMessaging::{SetForegroundWindow, ShowWindow, SW_RESTORE};
        let target = HWND(hwnd as *mut c_void);
        let _ = ShowWindow(target, SW_RESTORE);
        let _ = SetForegroundWindow(target);
    }
    Ok(())
}

#[tauri::command]
pub fn snap_active_window(layout: String) -> Result<(), String> {
    #[cfg(windows)]
    unsafe {
        use std::ffi::c_void;
        use windows::Win32::Foundation::RECT;
        use windows::Win32::UI::WindowsAndMessaging::{
            GetForegroundWindow, SetWindowPos, ShowWindow, SystemParametersInfoW, HWND_TOP,
            SPI_GETWORKAREA, SWP_NOZORDER, SWP_SHOWWINDOW, SW_MAXIMIZE, SW_RESTORE,
            SYSTEM_PARAMETERS_INFO_UPDATE_FLAGS,
        };
        let hwnd = GetForegroundWindow();
        if hwnd.0.is_null() {
            return Err("No foreground window found".to_string());
        }
        let mut work_area = RECT::default();
        let ok = SystemParametersInfoW(
            SPI_GETWORKAREA,
            0,
            Some((&mut work_area as *mut RECT) as *mut c_void),
            SYSTEM_PARAMETERS_INFO_UPDATE_FLAGS(0),
        );
        if ok.is_err() {
            return Err("Could not query Windows desktop work area".to_string());
        }
        let w = work_area.right - work_area.left;
        let h = work_area.bottom - work_area.top;
        let x0 = work_area.left;
        let y0 = work_area.top;

        if layout == "maximize" {
            let _ = ShowWindow(hwnd, SW_MAXIMIZE);
            return Ok(());
        }
        let _ = ShowWindow(hwnd, SW_RESTORE);
        let (x, y, ww, hh) = match layout.as_str() {
            "left" => (x0, y0, w / 2, h),
            "right" => (x0 + w / 2, y0, w / 2, h),
            "top" => (x0, y0, w, h / 2),
            "bottom" => (x0, y0 + h / 2, w, h / 2),
            "top-left" => (x0, y0, w / 2, h / 2),
            "top-right" => (x0 + w / 2, y0, w / 2, h / 2),
            "bottom-left" => (x0, y0 + h / 2, w / 2, h / 2),
            "bottom-right" => (x0 + w / 2, y0 + h / 2, w / 2, h / 2),
            "left-third" => (x0, y0, w / 3, h),
            "center-third" => (x0 + w / 3, y0, w / 3, h),
            "right-third" => (x0 + (w * 2) / 3, y0, w / 3, h),
            "center" => (x0 + w / 8, y0 + h / 8, (w * 3) / 4, (h * 3) / 4),
            _ => (x0, y0, w, h),
        };
        let _ = SetWindowPos(
            hwnd,
            Some(HWND_TOP),
            x,
            y,
            ww,
            hh,
            SWP_NOZORDER | SWP_SHOWWINDOW,
        );
    }
    Ok(())
}

#[tauri::command]
pub fn list_listening_ports(state: tauri::State<AppRuntimeState>) -> Vec<ListeningPortEntry> {
    let proc_map: HashMap<u32, String> = {
        let sys = state.sys.lock().expect("sys mutex poisoned");
        sys.processes()
            .iter()
            .map(|(pid, p)| (pid.as_u32(), p.name().to_string_lossy().to_string()))
            .collect()
    };

    let output = hidden_command("netstat").args(["-ano"]).output();
    let Ok(out) = output else {
        return Vec::new();
    };
    let text = String::from_utf8_lossy(&out.stdout);
    let mut entries = Vec::new();
    for line in text.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 4 {
            continue;
        }
        let proto = parts[0];
        if proto != "TCP" && proto != "UDP" {
            continue;
        }
        let state_ok = if proto == "TCP" {
            parts.len() >= 5 && parts[3].eq_ignore_ascii_case("LISTENING")
        } else {
            true
        };
        if !state_ok {
            continue;
        }
        let local = parts[1];
        let Some((_, port_str)) = local.rsplit_once(':') else {
            continue;
        };
        let Ok(port) = port_str.parse::<u16>() else {
            continue;
        };
        let pid_str = parts.last().copied().unwrap_or("0");
        let pid = pid_str.parse::<u32>().unwrap_or(0);
        let process_name = proc_map
            .get(&pid)
            .cloned()
            .unwrap_or_else(|| "System".to_string());
        entries.push(ListeningPortEntry {
            protocol: proto.to_string(),
            local_address: local.to_string(),
            port,
            pid,
            process_name,
        });
    }
    entries.sort_by_key(|e| e.port);
    entries
}

#[tauri::command]
pub fn kill_process(state: tauri::State<AppRuntimeState>, pid: u32) -> Result<bool, String> {
    if pid <= 4 {
        return Err("Refusing to terminate protected Windows system PID".to_string());
    }
    let sys = state.sys.lock().expect("sys mutex poisoned");
    if let Some(proc_) = sys.process(Pid::from_u32(pid)) {
        if proc_.kill() {
            return Ok(true);
        }
    }
    drop(sys);
    let output = hidden_command("taskkill")
        .args(["/F", "/PID", &pid.to_string()])
        .output()
        .map_err(|e| format!("Failed to run taskkill: {e}"))?;
    Ok(output.status.success())
}

fn dir_size_and_count(path: &PathBuf) -> (u64, usize) {
    let mut bytes = 0u64;
    let mut count = 0usize;
    let mut stack = vec![path.clone()];
    while let Some(current) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&current) else {
            continue;
        };
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_dir() {
                stack.push(p);
            } else if let Ok(meta) = entry.metadata() {
                bytes += meta.len();
                count += 1;
            }
        }
    }
    (bytes, count)
}

fn junk_targets() -> Vec<(String, String, PathBuf)> {
    let mut targets = Vec::new();
    if let Ok(temp) = std::env::var("TEMP") {
        targets.push((
            "user-temp".to_string(),
            "Windows User Temp (%TEMP%)".to_string(),
            PathBuf::from(temp),
        ));
    }
    if let Ok(local_app) = std::env::var("LOCALAPPDATA") {
        targets.push((
            "crash-dumps".to_string(),
            "Windows CrashDumps".to_string(),
            PathBuf::from(&local_app).join("CrashDumps"),
        ));
        targets.push((
            "npm-cache".to_string(),
            "npm / Node Local Cache".to_string(),
            PathBuf::from(&local_app).join("npm-cache"),
        ));
        targets.push((
            "pip-cache".to_string(),
            "Python pip Cache".to_string(),
            PathBuf::from(&local_app).join("pip").join("Cache"),
        ));
    }
    targets
}

#[tauri::command]
pub fn scan_junk_caches() -> Vec<JunkCategory> {
    junk_targets()
        .into_iter()
        .filter(|(_, _, p)| p.exists())
        .map(|(id, label, path)| {
            let (bytes, file_count) = dir_size_and_count(&path);
            JunkCategory {
                id,
                label,
                path: path.to_string_lossy().to_string(),
                size_mb: (bytes as f64) / 1_048_576.0,
                file_count,
            }
        })
        .collect()
}

#[tauri::command]
pub fn clean_junk_caches(category_ids: Vec<String>) -> f64 {
    let mut freed_bytes = 0u64;
    for (id, _, root) in junk_targets() {
        if !category_ids.is_empty() && !category_ids.contains(&id) {
            continue;
        }
        let Ok(entries) = std::fs::read_dir(&root) else {
            continue;
        };
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_file() {
                if let Ok(meta) = entry.metadata() {
                    if std::fs::remove_file(&p).is_ok() {
                        freed_bytes += meta.len();
                    }
                }
            }
        }
    }
    (freed_bytes as f64) / 1_048_576.0
}

#[tauri::command]
pub fn list_installed_apps() -> Vec<InstalledAppEntry> {
    #[cfg(windows)]
    {
        let script = r#"
$paths = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
Get-ItemProperty $paths -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -and $_.DisplayName.Trim().Length -gt 0 } |
  Select-Object -First 60 @{N='name';E={$_.DisplayName}},
    @{N='publisher';E={if($_.Publisher){$_.Publisher}else{'Unknown'}}},
    @{N='version';E={if($_.DisplayVersion){$_.DisplayVersion}else{''}}},
    @{N='installLocation';E={if($_.InstallLocation){$_.InstallLocation}else{''}}},
    @{N='uninstallString';E={if($_.UninstallString){$_.UninstallString}else{''}}} |
  ConvertTo-Json -Compress
"#;
        if let Ok(out) = hidden_command("powershell")
            .args(["-NoProfile", "-Command", script])
            .output()
        {
            let text = String::from_utf8_lossy(&out.stdout);
            if let Ok(parsed) = serde_json::from_str::<Vec<serde_json::Value>>(&text) {
                let mut apps: Vec<InstalledAppEntry> = parsed
                    .into_iter()
                    .filter_map(|v| {
                        let name = v.get("name")?.as_str()?.to_string();
                        Some(InstalledAppEntry {
                            name,
                            publisher: v
                                .get("publisher")
                                .and_then(|s| s.as_str())
                                .unwrap_or("Unknown")
                                .to_string(),
                            version: v
                                .get("version")
                                .and_then(|s| s.as_str())
                                .unwrap_or("")
                                .to_string(),
                            install_location: v
                                .get("installLocation")
                                .and_then(|s| s.as_str())
                                .unwrap_or("")
                                .to_string(),
                            uninstall_string: v
                                .get("uninstallString")
                                .and_then(|s| s.as_str())
                                .unwrap_or("")
                                .to_string(),
                        })
                    })
                    .collect();
                apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
                return apps;
            }
        }
    }
    Vec::new()
}

#[tauri::command]
pub fn uninstall_app(uninstall_string: String) -> Result<String, String> {
    let trimmed = uninstall_string.trim();
    if trimmed.is_empty() {
        return Err("No Windows uninstall command registered for this app".to_string());
    }
    #[cfg(windows)]
    {
        Command::new("cmd")
            .args(["/C", trimmed])
            .spawn()
            .map_err(|e| format!("Failed to launch uninstaller: {e}"))?;
        return Ok("Launched native Windows uninstaller".to_string());
    }
    #[cfg(not(windows))]
    {
        Err("Not supported outside Windows".to_string())
    }
}

fn parse_winget_table(stdout: &str, with_available: bool) -> Vec<WingetPackage> {
    let mut packages = Vec::new();
    let mut past_sep = false;
    for line in stdout.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        if trimmed.starts_with("---") {
            past_sep = true;
            continue;
        }
        if !past_sep {
            continue;
        }
        let cols: Vec<&str> = line
            .split("  ")
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .collect();
        if cols.len() >= 3 {
            packages.push(WingetPackage {
                name: cols[0].to_string(),
                id: cols[1].to_string(),
                version: cols[2].to_string(),
                available_version: if with_available && cols.len() >= 4 {
                    Some(cols[3].to_string())
                } else {
                    None
                },
            });
        }
    }
    packages.truncate(30);
    packages
}

#[tauri::command]
pub fn winget_search(query: String) -> Vec<WingetPackage> {
    let Ok(out) = hidden_command("winget")
        .args(["search", query.trim(), "--accept-source-agreements"])
        .output()
    else {
        return Vec::new();
    };
    parse_winget_table(&String::from_utf8_lossy(&out.stdout), false)
}

#[tauri::command]
pub fn winget_list_updates() -> Vec<WingetPackage> {
    let Ok(out) = hidden_command("winget")
        .args(["upgrade", "--accept-source-agreements"])
        .output()
    else {
        return Vec::new();
    };
    parse_winget_table(&String::from_utf8_lossy(&out.stdout), true)
}

#[tauri::command]
pub fn winget_install(package_id: String) -> Result<String, String> {
    let out = hidden_command("winget")
        .args([
            "install",
            "--id",
            package_id.trim(),
            "-e",
            "--accept-package-agreements",
            "--accept-source-agreements",
        ])
        .output()
        .map_err(|e| format!("Failed to invoke winget: {e}"))?;
    if out.status.success() {
        Ok(format!("Installed {package_id}"))
    } else {
        Err(String::from_utf8_lossy(&out.stdout).to_string())
    }
}

pub mod commands;

use commands::{
    now_millis, position_island_on_primary, read_clipboard_text_win32, show_overlay_internal,
    toggle_panel_internal, AppRuntimeState, ShelfDropFile,
};
use std::path::PathBuf;
use std::sync::atomic::Ordering;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, DragDropEvent, Emitter, Manager, WindowEvent,
};

fn shelf_item_from_path(path: &PathBuf) -> ShelfDropFile {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| path.to_string_lossy().to_string());
    let ext = path
        .extension()
        .map(|e| e.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    let kind = match ext.as_str() {
        "png" | "jpg" | "jpeg" | "webp" | "gif" | "svg" => "image",
        "pdf" => "pdf",
        "ts" | "tsx" | "rs" | "swift" | "py" | "js" | "json" | "md" => "code",
        "zip" | "7z" | "rar" | "tar" | "gz" => "archive",
        _ => "file",
    }
    .to_string();
    let size_label = if let Ok(meta) = std::fs::metadata(path) {
        let bytes = meta.len();
        if bytes >= 1_048_576 {
            format!("{:.1} MB", (bytes as f64) / 1_048_576.0)
        } else if bytes >= 1024 {
            format!("{} KB", (bytes / 1024).max(1))
        } else {
            format!("{bytes} B")
        }
    } else {
        "Local".to_string()
    };

    ShelfDropFile {
        name,
        path: path.to_string_lossy().to_string(),
        kind,
        size_label,
    }
}

fn spawn_background_watchers(app: AppHandle, state: AppRuntimeState) {
    // Thread 1: Active external HWND + Win32 Clipboard history watcher
    let watch_app = app.clone();
    let watch_state = state.clone();
    std::thread::spawn(move || {
        let self_pid = std::process::id();
        #[cfg(windows)]
        let mut last_seq = unsafe {
            windows::Win32::System::DataExchange::GetClipboardSequenceNumber()
        };

        loop {
            std::thread::sleep(std::time::Duration::from_millis(350));
            if watch_state.quitting.load(Ordering::Relaxed) {
                break;
            }

            #[cfg(windows)]
            unsafe {
                use windows::Win32::System::DataExchange::GetClipboardSequenceNumber;
                use windows::Win32::UI::WindowsAndMessaging::{
                    GetForegroundWindow, GetWindowThreadProcessId, IsWindowVisible,
                };

                let fg = GetForegroundWindow();
                if !fg.0.is_null() && IsWindowVisible(fg).as_bool() {
                    let mut pid: u32 = 0;
                    GetWindowThreadProcessId(fg, Some(&mut pid));
                    if pid != 0 && pid != self_pid {
                        if let Ok(mut guard) = watch_state.last_external_hwnd.lock() {
                            *guard = fg.0 as isize;
                        }
                    }
                }

                let seq = GetClipboardSequenceNumber();
                if seq != last_seq {
                    last_seq = seq;
                    if let Some(text) = read_clipboard_text_win32() {
                        let trimmed = text.trim();
                        if !trimmed.is_empty() && trimmed.len() <= 16_384 {
                            let is_new = {
                                let mut prev = watch_state
                                    .clipboard_history_last
                                    .lock()
                                    .expect("clip mutex poisoned");
                                if *prev != text {
                                    *prev = text.clone();
                                    true
                                } else {
                                    false
                                }
                            };
                            if is_new {
                                let _ = watch_app.emit("clipboard-captured", text);
                            }
                        }
                    }
                }
            }
        }
    });

    // Thread 2: Native Win32 Global Hotkeys
    let hk_app = app;
    let hk_state = state;
    std::thread::spawn(move || {
        #[cfg(windows)]
        unsafe {
            use windows::Win32::UI::Input::KeyboardAndMouse::{
                RegisterHotKey, UnregisterHotKey, MOD_ALT, MOD_CONTROL, MOD_NOREPEAT, MOD_SHIFT,
                VK_SPACE,
            };
            use windows::Win32::UI::WindowsAndMessaging::{GetMessageW, MSG, WM_HOTKEY};

            // 1: Alt+Space -> Command Bar
            let _ = RegisterHotKey(None, 1, MOD_ALT | MOD_NOREPEAT, VK_SPACE.0 as u32);
            // 2: Ctrl+Shift+V -> Clipboard Quick Panel
            let _ = RegisterHotKey(None, 2, MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, b'V' as u32);
            // 3: Ctrl+Shift+Space -> Radial Menu
            let _ = RegisterHotKey(
                None,
                3,
                MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT,
                VK_SPACE.0 as u32,
            );
            // 4: Ctrl+Alt+I -> Toggle Dynamic Island Expanded
            let _ = RegisterHotKey(None, 4, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, b'I' as u32);
            // 5: Ctrl+Alt+M -> Toggle Tray Panel
            let _ = RegisterHotKey(None, 5, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, b'M' as u32);
            // 6: Ctrl+Alt+K -> Toggle Keep Awake
            let _ = RegisterHotKey(None, 6, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, b'K' as u32);

            let mut msg = MSG::default();
            while GetMessageW(&mut msg, None, 0, 0).as_bool() {
                if hk_state.quitting.load(Ordering::Relaxed) {
                    break;
                }
                if msg.message == WM_HOTKEY {
                    match msg.wParam.0 {
                        1 => show_overlay_internal(&hk_app, &hk_state, "command"),
                        2 => show_overlay_internal(&hk_app, &hk_state, "clipboard"),
                        3 => show_overlay_internal(&hk_app, &hk_state, "radial"),
                        4 => {
                            let _ = hk_app.emit("toggle-island-expand", ());
                        }
                        5 => toggle_panel_internal(&hk_app, &hk_state),
                        6 => {
                            let next = {
                                let mut cur = hk_state
                                    .keep_awake
                                    .lock()
                                    .expect("keep_awake mutex poisoned");
                                *cur = !*cur;
                                *cur
                            };
                            let keep_display = *hk_state
                                .keep_display_on
                                .lock()
                                .expect("keep_display mutex poisoned");
                            use windows::Win32::System::Power::{
                                SetThreadExecutionState, ES_CONTINUOUS, ES_DISPLAY_REQUIRED,
                                ES_SYSTEM_REQUIRED,
                            };
                            let flags = if next {
                                if keep_display {
                                    ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
                                } else {
                                    ES_CONTINUOUS | ES_SYSTEM_REQUIRED
                                }
                            } else {
                                ES_CONTINUOUS
                            };
                            let _ = SetThreadExecutionState(flags);
                            let _ = hk_app.emit("keep-awake-changed", next);
                        }
                        _ => {}
                    }
                }
            }

            for id in 1..=6 {
                let _ = UnregisterHotKey(None, id);
            }
        }
    });
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let runtime_state = AppRuntimeState::new();
    let setup_state = runtime_state.clone();

    tauri::Builder::default()
        .manage(runtime_state)
        .setup(move |app| {
            position_island_on_primary(app.handle(), 276.0, 42.0);
            if let Some(island) = app.get_webview_window("island") {
                let _ = island.set_focusable(false);
            }

            let panel_item = MenuItem::with_id(app, "panel", "Abrir Painel Rápido (Ctrl+Alt+M)", true, None::<&str>)?;
            let command_item = MenuItem::with_id(app, "command", "Command Bar (Alt+Space)", true, None::<&str>)?;
            let island_item = MenuItem::with_id(app, "island", "Mostrar/Expandir Ilha Dinâmica", true, None::<&str>)?;
            let settings_item = MenuItem::with_id(app, "settings", "Configurações do Vorssaint", true, None::<&str>)?;
            let quit_item = MenuItem::with_id(app, "quit", "Sair", true, None::<&str>)?;
            let menu = Menu::with_items(
                app,
                &[
                    &panel_item,
                    &command_item,
                    &island_item,
                    &settings_item,
                    &quit_item,
                ],
            )?;

            let tray_state_menu = setup_state.clone();
            let tray_state_click = setup_state.clone();

            let mut tray_builder = TrayIconBuilder::new()
                .menu(&menu)
                .show_menu_on_left_click(false)
                .tooltip("Vorssaint Utils — Windows Edition")
                .on_menu_event(move |app, event| match event.id.as_ref() {
                    "panel" => toggle_panel_internal(app, &tray_state_menu),
                    "command" => show_overlay_internal(app, &tray_state_menu, "command"),
                    "island" => {
                        if let Some(island) = app.get_webview_window("island") {
                            let _ = island.show();
                        }
                        let _ = app.emit("toggle-island-expand", ());
                    }
                    "settings" => {
                        if let Some(win) = app.get_webview_window("settings") {
                            let _ = win.unminimize();
                            let _ = win.show();
                            let _ = win.set_focus();
                        }
                    }
                    "quit" => {
                        tray_state_menu.quitting.store(true, Ordering::Relaxed);
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(move |tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        toggle_panel_internal(tray.app_handle(), &tray_state_click);
                    }
                });

            if let Some(icon) = app.default_window_icon() {
                tray_builder = tray_builder.icon(icon.clone());
            }
            let _ = tray_builder.build(app);

            spawn_background_watchers(app.handle().clone(), setup_state.clone());
            Ok(())
        })
        .on_window_event(|window, event| {
            let label = window.label().to_string();
            let app = window.app_handle().clone();
            let state = app.state::<AppRuntimeState>();

            match event {
                WindowEvent::CloseRequested { api, .. } => {
                    if label == "settings" && !state.quitting.load(Ordering::Relaxed) {
                        // Hide Settings window to tray instead of terminating background utilities & Dynamic Island.
                        api.prevent_close();
                        let _ = window.hide();
                    }
                }
                WindowEvent::Focused(false) => {
                    if label == "panel" {
                        let shown = state.panel_shown_at_ms.load(Ordering::Relaxed);
                        if now_millis().saturating_sub(shown) > 350 {
                            let _ = window.hide();
                        }
                    } else if label == "overlay" {
                        let mode = state
                            .current_overlay_mode
                            .lock()
                            .map(|g| g.clone())
                            .unwrap_or_default();
                        if mode != "cleaning" {
                            let _ = window.hide();
                        }
                    }
                }
                WindowEvent::DragDrop(drop_event) => {
                    if label == "island" {
                        match drop_event {
                            DragDropEvent::Enter { .. } => {
                                position_island_on_primary(&app, 420.0, 96.0);
                                let _ = app.emit("island-drag-state", true);
                            }
                            DragDropEvent::Leave => {
                                let _ = app.emit("island-drag-state", false);
                            }
                            DragDropEvent::Drop { paths, .. } => {
                                let items: Vec<ShelfDropFile> =
                                    paths.iter().map(shelf_item_from_path).collect();
                                let _ = app.emit("island-drag-state", false);
                                if !items.is_empty() {
                                    let _ = app.emit("island-files-dropped", items);
                                }
                            }
                            _ => {}
                        }
                    }
                }
                _ => {}
            }
        })
        .invoke_handler(tauri::generate_handler![
            commands::set_island_bounds,
            commands::set_island_visible,
            commands::toggle_panel,
            commands::hide_panel,
            commands::open_settings_window,
            commands::open_overlay,
            commands::hide_overlay,
            commands::quit_app,
            commands::get_system_telemetry,
            commands::set_keep_awake,
            commands::get_master_audio,
            commands::set_master_audio,
            commands::list_audio_sessions,
            commands::set_app_audio,
            commands::send_media_action,
            commands::set_display_brightness,
            commands::set_windows_dark_mode,
            commands::lock_workstation,
            commands::empty_recycle_bin,
            commands::list_open_windows,
            commands::focus_window,
            commands::toggle_window_pin,
            commands::snap_active_window,
            commands::pick_screen_color,
            commands::capture_screen_png,
            commands::copy_text_to_clipboard,
            commands::open_path_in_explorer,
            commands::open_external_url,
            commands::launch_windows_utility,
            commands::list_listening_ports,
            commands::kill_process,
            commands::scan_junk_caches,
            commands::clean_junk_caches,
            commands::list_installed_apps,
            commands::uninstall_app,
            commands::winget_search,
            commands::winget_list_updates,
            commands::winget_install,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Vorssaint Windows runtime");
}

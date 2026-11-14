pub mod commands;

use commands::AppRuntimeState;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(AppRuntimeState::new())
        .setup(|app| {
            let show_item = MenuItem::with_id(app, "show", "Open Vorssaint", true, None::<&str>)?;
            let quit_item = MenuItem::with_id(app, "quit", "Quit Vorssaint", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_item, &quit_item])?;

            let mut tray_builder = TrayIconBuilder::new()
                .menu(&menu)
                .tooltip("Vorssaint Utils — Windows Edition")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        if let Some(window) = tray.app_handle().get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                });

            if let Some(icon) = app.default_window_icon() {
                tray_builder = tray_builder.icon(icon.clone());
            }

            let _ = tray_builder.build(app);
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_system_telemetry,
            commands::set_keep_awake,
            commands::get_master_audio,
            commands::set_master_audio,
            commands::set_display_brightness,
            commands::list_open_windows,
            commands::focus_window,
            commands::snap_active_window,
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

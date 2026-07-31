use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{AppHandle, Manager, Emitter};
use tokio::net::TcpListener;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use std::sync::Arc;
use tokio::sync::Mutex;
use windows::Win32::Foundation::{BOOL, HWND, LPARAM, WPARAM};
use windows::Win32::UI::WindowsAndMessaging::{
    EnumWindows, GetWindowTextW, GetWindowThreadProcessId, IsWindowVisible, PostMessageW, SetForegroundWindow, WM_CLOSE
};
use windows::Win32::System::Threading::{OpenProcess, PROCESS_QUERY_INFORMATION, PROCESS_VM_READ};
use windows::Win32::System::ProcessStatus::{K32GetProcessMemoryInfo, PROCESS_MEMORY_COUNTERS};

struct AppState {
    writer: Arc<Mutex<Option<tokio::net::tcp::OwnedWriteHalf>>>,
    is_paused: Arc<std::sync::atomic::AtomicBool>,
}

#[derive(serde::Serialize, Clone, Debug)]
struct DesktopApp {
    hwnd: isize,
    pid: u32,
    title: String,
    memory_mb: u64,
}

unsafe extern "system" fn enum_windows_proc(hwnd: HWND, lparam: LPARAM) -> BOOL {
    if !IsWindowVisible(hwnd).as_bool() {
        return BOOL(1);
    }
    let mut title_buf = [0u16; 512];
    let len = GetWindowTextW(hwnd, &mut title_buf);
    if len == 0 {
        return BOOL(1);
    }
    let title = String::from_utf16_lossy(&title_buf[..len as usize]);
    
    // Ignore internal system windows and our own app window
    if title == "Program Manager" || title == "Settings" || title == "Windows Input Experience" || title.contains("Tab Monitor") {
        return BOOL(1);
    }

    let mut pid = 0u32;
    GetWindowThreadProcessId(hwnd, Some(&mut pid));
    if pid == 0 {
        return BOOL(1);
    }

    let apps = &mut *(lparam.0 as *mut Vec<DesktopApp>);

    if let Ok(h_process) = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, false, pid) {
        let mut counters = PROCESS_MEMORY_COUNTERS::default();
        if K32GetProcessMemoryInfo(
            h_process,
            &mut counters,
            std::mem::size_of::<PROCESS_MEMORY_COUNTERS>() as u32,
        ).as_bool() {
            let memory_mb = (counters.WorkingSetSize / (1024 * 1024)) as u64;
            if memory_mb > 15 {
                apps.push(DesktopApp {
                    hwnd: hwnd.0 as isize,
                    pid,
                    title,
                    memory_mb,
                });
            }
        }
    }

    BOOL(1)
}

fn get_desktop_apps() -> Vec<DesktopApp> {
    let mut apps: Vec<DesktopApp> = Vec::new();
    unsafe {
        let _ = EnumWindows(Some(enum_windows_proc), LPARAM(&mut apps as *mut _ as isize));
    }
    apps.sort_by(|a, b| b.memory_mb.cmp(&a.memory_mb));
    
    let mut unique_apps = Vec::new();
    let mut seen_pids = std::collections::HashSet::new();
    for app in apps {
        if seen_pids.insert(app.pid) {
            unique_apps.push(app);
        }
    }
    unique_apps.truncate(5);
    unique_apps
}

#[tauri::command]
async fn close_tabs(app: AppHandle, tab_ids: Vec<u32>) -> Result<(), String> {
    let state = app.state::<AppState>();
    let mut writer_opt = state.writer.lock().await;
    
    if let Some(writer) = writer_opt.as_mut() {
        let msg = serde_json::json!({
            "action": "CLOSE_TABS",
            "tabIds": tab_ids
        }).to_string();
        
        let msg_bytes = msg.as_bytes();
        let len_bytes = (msg_bytes.len() as u32).to_ne_bytes();
        
        if writer.write_all(&len_bytes).await.is_ok() && writer.write_all(msg_bytes).await.is_ok() {
            return Ok(());
        }
    }
    Err("Failed to send command to Chrome".into())
}

#[tauri::command]
async fn focus_tab(app: AppHandle, tab_id: u32, window_id: Option<u32>) -> Result<(), String> {
    let state = app.state::<AppState>();
    let mut writer_opt = state.writer.lock().await;
    
    if let Some(writer) = writer_opt.as_mut() {
        let msg = serde_json::json!({
            "action": "FOCUS_TAB",
            "tabId": tab_id,
            "windowId": window_id
        }).to_string();
        
        let msg_bytes = msg.as_bytes();
        let len_bytes = (msg_bytes.len() as u32).to_ne_bytes();
        
        if writer.write_all(&len_bytes).await.is_ok() && writer.write_all(msg_bytes).await.is_ok() {
            return Ok(());
        }
    }
    Err("Failed to send command to Chrome".into())
}

#[tauri::command]
fn focus_desktop_app(hwnd: isize) {
    unsafe {
        let _ = SetForegroundWindow(HWND(hwnd));
    }
}

#[tauri::command]
fn close_desktop_app(hwnd: isize) {
    unsafe {
        let _ = PostMessageW(HWND(hwnd), WM_CLOSE, WPARAM(0), LPARAM(0));
    }
}

#[tauri::command]
fn hide_window(app: AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.hide();
    }
}

async fn start_server(app: AppHandle) {
    if let Ok(listener) = TcpListener::bind("127.0.0.1:41414").await {
        loop {
            if let Ok((stream, _)) = listener.accept().await {
                let (mut read_half, write_half) = stream.into_split();
                
                let state = app.state::<AppState>();
                *state.writer.lock().await = Some(write_half);
                
                let app_clone = app.clone();
                tokio::spawn(async move {
                    loop {
                        let mut len_bytes = [0u8; 4];
                        if read_half.read_exact(&mut len_bytes).await.is_err() { break; }
                        let len = u32::from_ne_bytes(len_bytes) as usize;
                        
                        let mut msg_bytes = vec![0u8; len];
                        if read_half.read_exact(&mut msg_bytes).await.is_err() { break; }
                        
                        if let Ok(msg_str) = String::from_utf8(msg_bytes) {
                            if let Ok(mut json) = serde_json::from_str::<serde_json::Value>(&msg_str) {
                                let event_type = json.get("event").and_then(|v| v.as_str()).unwrap_or("TAB_WARNING");

                                if event_type == "TAB_RESOLVED" {
                                    let _ = app_clone.emit("tab-resolved", json);
                                    if let Some(window) = app_clone.get_webview_window("main") {
                                        let _ = window.hide();
                                    }
                                } else if event_type == "TAB_UPDATE" {
                                    let desktop_apps = get_desktop_apps();
                                    json["desktopApps"] = serde_json::to_value(desktop_apps).unwrap_or_default();
                                    let _ = app_clone.emit("tab-warning", json);
                                } else {
                                    let is_paused = app_clone.state::<AppState>().is_paused.load(std::sync::atomic::Ordering::Relaxed);
                                    if !is_paused {
                                        let desktop_apps = get_desktop_apps();
                                        json["desktopApps"] = serde_json::to_value(desktop_apps).unwrap_or_default();

                                        // Send the event to the frontend
                                        let _ = app_clone.emit("tab-warning", json);
                                        
                                        // Show and position the window bottom right
                                        if let Some(window) = app_clone.get_webview_window("main") {
                                            let _ = window.set_shadow(false);
                                            if let Ok(Some(monitor)) = window.current_monitor() {
                                                let monitor_size = monitor.size();
                                                let window_size = window.outer_size().unwrap_or_default();
                                                
                                                // 20px right margin, 60px bottom margin (for taskbar)
                                                let x = monitor_size.width.saturating_sub(window_size.width).saturating_sub(20);
                                                let y = monitor_size.height.saturating_sub(window_size.height).saturating_sub(60);
                                                
                                                let _ = window.set_position(tauri::PhysicalPosition::new(x, y));
                                            }
                                            let _ = window.show();
                                            let _ = window.set_focus();
                                        }
                                    }
                                }
                            }
                        }
                    }
                });
            }
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let is_paused = Arc::new(std::sync::atomic::AtomicBool::new(false));
            let is_paused_clone = is_paused.clone();
            
            let quit_i = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let settings_i = MenuItem::with_id(app, "settings", "Settings", true, None::<&str>)?;
            let pause_i = MenuItem::with_id(app, "pause", "Pause Monitoring", true, None::<&str>)?;
            
            let menu = Menu::with_items(app, &[&settings_i, &pause_i, &quit_i])?;

            let pause_i_handle = pause_i.clone();

            let _tray = TrayIconBuilder::new()
                .menu(&menu)
                .icon(app.default_window_icon().unwrap().clone())
                .on_menu_event(move |app, event| match event.id.as_ref() {
                    "quit" => {
                        app.exit(0);
                    }
                    "pause" => {
                        let currently_paused = is_paused_clone.load(std::sync::atomic::Ordering::Relaxed);
                        let next_state = !currently_paused;
                        is_paused_clone.store(next_state, std::sync::atomic::Ordering::Relaxed);
                        
                        if next_state {
                            let _ = pause_i_handle.set_text("Resume Monitoring");
                            if let Some(window) = app.get_webview_window("main") {
                                let _ = window.hide();
                            }
                        } else {
                            let _ = pause_i_handle.set_text("Pause Monitoring");
                        }
                    }
                    "settings" => {
                        let url = "chrome://extensions/?id=lcjcnebnibfdgjglmaojjmbndkcfffki";
                        let mut opened = false;
                        for path in &[
                            "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
                            "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
                        ] {
                            if std::path::Path::new(path).exists() {
                                let _ = std::process::Command::new(path).arg(url).spawn();
                                opened = true;
                                break;
                            }
                        }
                        if !opened {
                            let _ = std::process::Command::new("cmd").args(["/c", "start", "chrome", url]).spawn();
                        }
                    }
                    _ => {}
                })
                .build(app)?;

            app.manage(AppState {
                writer: Arc::new(Mutex::new(None)),
                is_paused,
            });

            // Start tcp server for native messaging host
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                start_server(app_handle).await;
            });

            Ok(())
        })
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![close_tabs, focus_tab, focus_desktop_app, close_desktop_app, hide_window])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

use std::io::{self, Read, Write};
use std::net::TcpStream;
use std::thread;
use std::sync::{Arc, Mutex};

fn main() {
    let port = 41414;

    let current_stream: Arc<Mutex<Option<TcpStream>>> = Arc::new(Mutex::new(None));
    let stream_writer = current_stream.clone();

    // Background manager thread: Maintains persistent TCP connection to Tauri
    thread::spawn(move || {
        loop {
            // Attempt connection to Tauri app
            if let Ok(stream) = TcpStream::connect(format!("127.0.0.1:{}", port)) {
                let mut reader_stream = match stream.try_clone() {
                    Ok(s) => s,
                    Err(_) => {
                        thread::sleep(std::time::Duration::from_secs(1));
                        continue;
                    }
                };

                *stream_writer.lock().unwrap() = Some(stream);

                // Thread loop for Tauri -> Chrome messages
                loop {
                    let mut len_bytes = [0u8; 4];
                    if reader_stream.read_exact(&mut len_bytes).is_err() { break; }
                    let len = u32::from_ne_bytes(len_bytes) as usize;
                    
                    let mut msg = vec![0u8; len];
                    if reader_stream.read_exact(&mut msg).is_err() { break; }

                    let _ = io::stdout().write_all(&len_bytes);
                    let _ = io::stdout().write_all(&msg);
                    let _ = io::stdout().flush();
                }

                // Reset stream on disconnect so reconnect loop fires
                *stream_writer.lock().unwrap() = None;
            }
            thread::sleep(std::time::Duration::from_secs(1));
        }
    });

    // Main thread: Stdin (Chrome -> Native Host -> Tauri)
    loop {
        let mut len_bytes = [0u8; 4];
        if io::stdin().read_exact(&mut len_bytes).is_err() {
            // Stdin error means Chrome closed the native messaging port -> Exit process
            break;
        }
        let len = u32::from_ne_bytes(len_bytes) as usize;
        
        let mut msg = vec![0u8; len];
        if io::stdin().read_exact(&mut msg).is_err() {
            break;
        }

        // Forward message to Tauri if TCP connection is active
        if let Ok(mut guard) = current_stream.lock() {
            if let Some(stream) = guard.as_mut() {
                if stream.write_all(&len_bytes).is_err() || stream.write_all(&msg).is_err() || stream.flush().is_err() {
                    *guard = None; // Socket error -> Clear so background thread reconnects
                }
            }
        }
    }
}

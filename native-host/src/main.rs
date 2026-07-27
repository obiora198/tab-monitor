use std::io::{self, Read, Write};
use std::net::TcpStream;
use std::thread;

fn main() {
    let port = 41414;

    // Wait until socket is available
    let mut stream = loop {
        if let Ok(s) = TcpStream::connect(format!("127.0.0.1:{}", port)) {
            break s;
        }
        thread::sleep(std::time::Duration::from_secs(1));
    };

    let mut stream_clone = stream.try_clone().unwrap();

    // Thread for Tauri -> Chrome
    thread::spawn(move || {
        loop {
            let mut len_bytes = [0u8; 4];
            if stream_clone.read_exact(&mut len_bytes).is_err() { break; }
            let len = u32::from_ne_bytes(len_bytes) as usize;
            
            let mut msg = vec![0u8; len];
            if stream_clone.read_exact(&mut msg).is_err() { break; }

            // Write to Chrome via stdout
            if io::stdout().write_all(&len_bytes).is_err() { break; }
            if io::stdout().write_all(&msg).is_err() { break; }
            if io::stdout().flush().is_err() { break; }
        }
    });

    // Main thread: Chrome -> Tauri
    loop {
        let mut len_bytes = [0u8; 4];
        if io::stdin().read_exact(&mut len_bytes).is_err() { break; }
        let len = u32::from_ne_bytes(len_bytes) as usize;
        
        let mut msg = vec![0u8; len];
        if io::stdin().read_exact(&mut msg).is_err() { break; }

        if stream.write_all(&len_bytes).is_err() { break; }
        if stream.write_all(&msg).is_err() { break; }
        if stream.flush().is_err() { break; }
    }
}

![BrutalZip Banner](file:///Users/ramkumar/.gemini/antigravity/brain/7ae7784e-2be8-405c-8ad4-2ad4b466cafc/brutalzip_banner_1770472189719.png)

# BrutalZip

BrutalZip is a high-performance, open-source macOS ZIP archiver featuring a WinRAR-inspired workflow wrapped in a bold, brutalist aesthetic.

## Feature set

- Create `.zip` archives from files and folders
- Password-protect archives (`zip -P` compatible)
- Compression level control (`0-9`)
- Optional split archive size (MB)
- Open and browse archive contents
- Integrity testing (`unzip -t`)
- Extract with overwrite toggle
- Add/update files inside existing archives
- Delete selected entries from existing archives
- Live operation log and status panel
- Native SwiftUI desktop app for macOS

## Design

The UI intentionally uses a brutalist visual language:

- heavy black frames
- sharp contrast blocks
- compressed uppercase typography
- industrial panel layout

## Build and run

```bash
swift build
swift run BrutalZip
```

## Test

```bash
swift test
```

## Architecture

- `BrutalZipCore`: ZIP engine and shell execution wrappers
- `BrutalZip`: SwiftUI desktop application
- `BrutalZipCoreTests`: integration tests over real `zip` / `unzip`

## Notes

- The app is ZIP-focused, by design.
- Encryption uses `zip`/`unzip` password mode on macOS (compatible but not modern AES-level hardening).

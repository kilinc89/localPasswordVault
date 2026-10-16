# LocalVault

A fully offline password manager for macOS, built with SwiftUI. Your vault is encrypted and never leaves your Mac — there is no network access, no cloud sync, and no telemetry.

> The interface is available in **English** and **Turkish**.

## Features

- **Master password** — create a vault on first launch (minimum 8 characters, confirmed); a wrong password never opens it.
- **Strong encryption** — PBKDF2-HMAC-SHA256 key derivation (600,000 iterations, 16-byte random salt) and AES-256-GCM encryption. Plaintext is never written to disk.
- **Local-only storage** — atomic writes to a single file with `0600` permissions.
- **Entry management** — title, username, password, URL, notes, and created/updated timestamps. Add, edit, delete.
- **Password generator** — length 8–64, uppercase / lowercase / digits / symbols, optional exclusion of ambiguous characters (`0/O`, `l/1`). Uses `SecRandomCopyBytes` with rejection sampling and guarantees at least one character from each selected class.
- **Strength meter** — entropy-based rating: Weak / Fair / Strong / Very strong.
- **Search** — instant filtering by title, username, and URL.
- **Clipboard auto-clear** — copied usernames and passwords are cleared after 30 seconds if the clipboard still holds the same value.
- **Auto-lock** — after 5 minutes of inactivity, on sleep or screen lock, or manually with `⌘L`. The key and decrypted entries are dropped from memory.
- **Show / hide password** — hidden by default in the detail view.
- **Change master password** — re-encrypts the vault with a fresh salt.
- **English / Turkish UI** — follows the system language on first launch; switch anytime from **Settings → Language** or the **Vault** menu. The choice is remembered.
- **Encrypted backup export** — copies the vault file (still encrypted) to a location you choose.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.10+ toolchain (Xcode 15.3+ or Command Line Tools)

## Building

```bash
# Debug build and run
swift build
swift run LocalVault

# Run the tests
swift test

# Release .app + .dmg (universal: arm64 + x86_64)
./scripts/build_dmg.sh
```

`build_dmg.sh` produces `build/LocalVault.app` and `dist/LocalVault.dmg`. The app is **ad-hoc signed**, so on another Mac Gatekeeper will warn on first launch — right-click the app and choose **Open**.

## Where your data lives

```
~/Library/Application Support/LocalVault/vault.lvault
```

The directory is created with `0700` permissions and the file with `0600`. Back this file up (or use the in-app export) — **if you forget your master password, the vault cannot be recovered.**

## Security model

The vault file is a small JSON envelope:

| Field        | Purpose                                              |
|--------------|------------------------------------------------------|
| `format`, `version`, `kdf` | Format identification                  |
| `iterations` | PBKDF2 iteration count                               |
| `salt`       | 16 random bytes, regenerated on password change      |
| `ciphertext` | AES-256-GCM sealed box containing all entries        |

- The header fields are bound to the ciphertext as **additional authenticated data (AAD)**, so tampering with any of them makes decryption fail.
- Because the header can only be authenticated after key derivation, its parameters are validated first: the KDF and salt length must match, and the iteration count must fall within `1,000…5,000,000`. A crafted file cannot hang the app with an enormous iteration count.
- The derived key bytes are zeroed with `memset_s` after use; the unlocked key is held in memory only until the vault locks.
- Security relies solely on the secrecy of your master password — not on the secrecy of this source code.

**Out of scope / limitations:** no protection against malware already running as your user, no Touch ID, no browser integration, no sync. Swift `String`s holding decrypted entries cannot be reliably wiped from memory.

## Project structure

```
Sources/
  VaultCore/        # UI-independent core (tested)
    Crypto.swift            # PBKDF2, AES-GCM, secure random
    Localization.swift      # English/Turkish strings and language setting
    VaultStore.swift        # On-disk format, create/unlock/save, backup
    Entry.swift             # Entry model and search
    PasswordGenerator.swift # Generator and strength estimation
  LocalVault/       # SwiftUI app
    LocalVaultApp.swift, AppState.swift, AuthViews.swift,
    VaultView.swift, GeneratorViews.swift
Tests/VaultCoreTests/       # XCTest suite for VaultCore
scripts/
  build_dmg.sh              # Release build, icon, signing, DMG
  make_icon.swift           # Generates the app icon
```

## Out of scope (v1)

Cloud sync, browser extension, Touch ID, sharing, CSV import.

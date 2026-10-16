# LocalVault — İlerleme

## İterasyon 1 (2026-10-15)
| # | Özellik | Durum | Nerede |
|---|---------|-------|--------|
| F1 | Ana parola ile kasa oluştur/aç | ✅ | `AuthViews.swift`, `VaultStore.create/unlock` |
| F2 | PBKDF2-SHA256 600k + AES-256-GCM (başlık AAD) | ✅ | `Crypto.swift`, `VaultStore.swift` |
| F3 | Yalnızca yerel, atomik yazım, 0600 izin | ✅ | `VaultStore.save` |
| F4 | Ekle/düzenle/sil | ✅ | `VaultView.swift`, `AppState.upsert/delete` |
| F5 | Parola üretici (SecRandom, rejection sampling) | ✅ | `PasswordGenerator.swift`, `GeneratorViews.swift` |
| F6 | Güç göstergesi | ✅ | `PasswordStrength`, `StrengthBar` |
| F7 | Arama | ✅ | `Entry.matches`, `.searchable` |
| F8 | Panoya kopyala + 30 sn temizleme | ✅ | `AppState.copy` |
| F9 | Otomatik kilit (5 dk, uyku, ekran kilidi, ⌘L) | ✅ | `AppState` |
| F10 | Göster/gizle | ✅ | `EntryDetailView` |
| F11 | Ana parola değiştirme | ✅ | `ChangePasswordView`, `VaultStore.changePassword` |
| F12 | Şifreli yedek dışa aktarma | ✅ | `AppState.exportBackup` |
| F13 | DMG | ✅ | `scripts/build_dmg.sh` → `dist/LocalVault.dmg` |

Doğrulama: `swift build` uyarısız, `swift test` 15/15 geçti, release universal (arm64+x86_64) `.app` ad-hoc imzalı, `hdiutil verify` VALID, uygulama başlatıldı.

## İterasyon 2 — farklı aile incelemesi (orchestrag)
- GPT (`gpt-5.6-terra`, Codex): 3 orta seviye bulgu, hepsi doğrulandı ve düzeltildi:
  1. Doğrulanmamış başlıktaki `iterations` ile uygulamayı kilitleme → KDF, salt uzunluğu ve iterasyon aralığı türetmeden önce denetleniyor (`VaultStore.readFile`).
  2. Disk yazımı başarısızsa arayüz kaydedilmemiş değişikliği gösteriyordu → önce yaz, sonra yayınla (`AppState.commit`).
  3. Yedek dışa aktarma eski yedeği kopyalamadan önce siliyordu → geçici dosya + `replaceItemAt`.
- Gemini: çalışmadı — kaynak kodu dışarı göndermek izin denetiminde engellendi; kullanıcı onayı bekleniyor.
- `swift test` 17/17, DMG yeniden üretildi, `hdiutil verify` VALID.

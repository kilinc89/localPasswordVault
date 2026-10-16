# LocalVault — macOS Yerel Parola Yöneticisi

Tamamen çevrimdışı, verileri yalnızca bu Mac'te şifreli tutan SwiftUI uygulaması.
Teknoloji: Swift 6 + SwiftUI + CryptoKit + CommonCrypto, Swift Package Manager ile derlenir, `.app` + `.dmg` script ile paketlenir.

## Temel Özellikler (MVP)

| # | Özellik | Kabul kriteri |
|---|---------|---------------|
| F1 | **Ana parola ile kasa oluşturma / açma** | İlk açılışta ana parola (min 8 karakter, tekrar onaylı) belirlenir; sonraki açılışlarda parola sorulur, yanlış parola kasayı açmaz. |
| F2 | **Güçlü şifreleme** | Anahtar PBKDF2-HMAC-SHA256 (600.000 iterasyon, 16 bayt rastgele salt) ile türetilir; kasa AES-256-GCM ile şifrelenir. Düz metin diske asla yazılmaz. |
| F3 | **Yalnızca yerel depolama** | Kasa `~/Library/Application Support/LocalVault/vault.lvault` dosyasında, atomik yazım ile saklanır. Ağ erişimi yoktur. |
| F4 | **Kayıt yönetimi** | Başlık, kullanıcı adı, parola, URL, notlar, oluşturma/güncelleme tarihi. Ekle / düzenle / sil. |
| F5 | **Parola üretici** | Uzunluk 8–64, büyük/küçük harf, rakam, sembol seçenekleri, karışabilen karakterleri (0/O, l/1) hariç tutma; `SecRandomCopyBytes` ile, her seçili sınıftan en az bir karakter. |
| F6 | **Güç göstergesi** | Entropi (bit) tabanlı Zayıf / Orta / Güçlü / Çok güçlü göstergesi. |
| F7 | **Arama** | Başlık, kullanıcı adı ve URL'de anlık filtreleme. |
| F8 | **Panoya kopyalama + otomatik temizleme** | Kullanıcı adı/parola kopyalanır; 30 sn sonra pano hâlâ aynı değeri içeriyorsa temizlenir. |
| F9 | **Otomatik kilit** | 5 dk hareketsizlikte, Mac uyku/ekran kilidinde ve manuel (⌘L) kilitlenir; bellekteki anahtar ve kayıtlar silinir. |
| F10 | **Parolayı göster/gizle** | Detay görünümünde parola varsayılan olarak gizli. |
| F11 | **Ana parola değiştirme** | Mevcut parola doğrulanır, yeni salt ile yeniden şifrelenir. |
| F12 | **Şifreli yedek dışa aktarma** | Kasa dosyası seçilen konuma kopyalanır (şifreli kalır). |
| F13 | **DMG dağıtımı** | `scripts/build_dmg.sh` → `dist/LocalVault.dmg` (Applications kısayolu ile). |
| F14 | **Türkçe / İngilizce arayüz** | İlk açılışta sistem diline göre seçilir; Ayarlar → Dil veya Kasa menüsünden anında değiştirilir, seçim hatırlanır. |

## Kapsam dışı (v1)
Bulut senkronizasyonu, tarayıcı eklentisi, Touch ID, paylaşım, CSV içe aktarma.

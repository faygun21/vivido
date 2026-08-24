# Katkı Rehberi

## 1. İlk kurulum (bir kez)

```powershell
git config --global core.longpaths true
git config --global core.autocrlf input
git config --global init.defaultBranch main
git config --global pull.rebase true
```

Bu dört satır isteğe bağlı değil:
- `core.longpaths` — `node_modules` derinliği Windows'un 260 karakter sınırını aşar, checkout kırılır.
- `core.autocrlf input` — ekip Windows + WSL karışık çalışıyor. Bu olmadan her PR'da "tüm dosyalar değişmiş" görünür.
- `pull.rebase true` — gereksiz merge commit'lerini önler, geçmiş okunabilir kalır.

Kurulum adımlarının tamamı için [`README.md`](README.md#2-hızlı-başlangıç).

---

## 2. Branch adlandırma

```
feat/W4-anchor-siralama
fix/M4-adim-gecisi-atliyor
data/poi-kategori-eslemesi
docs/kurulum-rehberi
chore/ci-cache-ekle
```

| Önek | Ne zaman |
|---|---|
| `feat/` | Yeni özellik — mümkünse gereksinim kodunu ekle (`W1`…`W7`, `M1`…`M5`) |
| `fix/` | Hata düzeltmesi |
| `data/` | ETL, veri şeması, seed |
| `docs/` | Yalnızca dokümantasyon |
| `chore/` | CI, bağımlılık, yapılandırma |
| `test/` | Yalnızca test ekleme |

`main`'e **doğrudan push kapalıdır.** Her değişiklik PR ile gelir.

---

## 3. Commit mesajı

```
<tip>: <ne yapıldığı, küçük harf, emir kipi>

feat: anchor sıralaması için geometrik ağırlık hesabı
fix: adım durum makinesi GPS sıçramasında adım atlıyordu
data: POI kategori eşleme tablosuna veteriner eklendi
docs: mobil dev client kurulum adımları
```

Tip listesi: `feat` · `fix` · `data` · `docs` · `chore` · `test` · `refactor`

Türkçe yaz — ekip Türkçe çalışıyor, tutarlılık okunabilirlikten önemli.

---

## 4. Pull Request kuralları

| Kural | Değer |
|---|---|
| Onay | **1 kişi** |
| CI | Yeşil olmadan merge yok |
| Boyut | **≤ 600 satır** — büyükse bölünmesi istenir |
| Başlık | Commit mesajı formatıyla aynı |
| Açıklama | PR şablonundaki alanlar doldurulmuş olmalı |

**İnceleme SLA'sı: 1 iş günü.** Bir PR bir günden fazla beklerse yazarın hatırlatması beklenir.

**Çapraz inceleme önerilir:** kendi alanın dışından birinin PR'ını incelemek, projenin bütününü öğrenmenin en hızlı yoludur.

---

## 5. Korumalı dosyalar (CODEOWNERS)

Bu yollara dokunan PR'lar ek onay gerektirir:

| Yol | Neden |
|---|---|
| `api/tests/**/golden/**` | Skorlama beklenen değerleri. Testi geçirmek için beklenen değeri **değiştirmek yasaktır** — bu, regresyon korumasını sahte hale getirir. Değişiklik gerekiyorsa PR'da diff tablosu + gerekçe zorunlu. |
| `db/schema/**` | Şema kontratı. Dört iş kolu buna güveniyor. |
| `api/openapi.yaml` | API kontratı. Web ve mobil buna göre kod üretiyor. |

---

## 6. Kod kuralları

### C# (`api/`)
- `Vivido.Scoring` projesine **hiçbir paket referansı eklenmez.** Saf C#, I/O yok.
- Dosya kapsamlı namespace (`namespace Vivido.Domain;`)
- Nullable reference types açık
- Public API'lerde XML doc yorumu

### TypeScript (`web/`, `mobile/`, `packages/`)
- `any` kullanma — gerekirse `unknown` + tip daraltma
- Ortak tipler `packages/shared`'da yaşar; web ve mobil oradan import eder
- API istemcisi **elle yazılmaz** — `pnpm gen:api` ile OpenAPI'den üretilir

### Genel
- Yorumları neden için yaz, ne için değil. Kod ne yaptığını zaten söylüyor.
- Sihirli sayı yok. Skorlama parametreleri **veritabanında** (`poi_categories`, `persona_category_weights`) yaşar, kodda değil.

---

## 7. Issue etiketleri

| Kategori | Etiketler |
|---|---|
| Alan | `area:api` `area:web` `area:mobile` `area:data` `area:devops` |
| Tip | `type:task` `type:bug` `type:nice-to-have` |
| Gereksinim | `W1`…`W7` `M1`…`M5` |
| Durum | `blocked` `needs-repro` |

`type:nice-to-have` etiketli hiçbir issue sprint'e alınmaz — [`backlog/v2.md`](backlog/v2.md)'ye gider.

---

## 8. Sık karşılaşılan sorunlar

| Sorun | Çözüm |
|---|---|
| `git status` her dosyayı değişmiş gösteriyor | `core.autocrlf input` ayarını yapmadın. Ayarla, sonra `git rm --cached -r . && git reset --hard` |
| Checkout'ta "Filename too long" | `git config --global core.longpaths true` |
| `pnpm install` çok yavaş / kilitleniyor | Depo OneDrive altında. `C:\dev\vivido`'ya taşı. |
| Mobilde harita boş | Expo Go kullanıyorsun. Dev client APK gerekli — [`README.md`](README.md#24-mobil-uygulama) |
| `docker compose up` bağlanamıyor | Docker Desktop kapalı. Elle başlat. |
| `extension "postgis" is not available` | Yanlış imaj. `postgis/postgis:16-3.4` olmalı. |
| Türkçe karakterli yolda Java/osmium hatası | Depoyu ASCII bir yola taşı. |

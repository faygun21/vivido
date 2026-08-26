# Staging Kurulumu

> Tek sunucuda çalışan ortak ortam. Karar ve gerekçeleri: [`docs/02-KARARLAR.md`](../docs/02-KARARLAR.md)
>
> **Bu ortam geliştirme için DEĞİLDİR.** Herkes yerelde çalışmaya devam eder
> (`pnpm dev:api` + `pnpm dev:web`, kendi PostGIS'i, `Email__Provider=console`).
> Staging yalnızca **entegrasyon ve demo** içindir.

---

## 1. Neden var

| Problem | Staging'in çözümü |
|---|---|
| Bir bilgisayarda açılan hesap diğerinde tanınmıyor | Tek veritabanı |
| Ekipteki herkesin SMTP kurması gerekiyor sanılıyordu | Tek yapılandırma herkese hizmet ediyor (yerelde zaten `console` yeterli) |
| **M1** "web ile aynı hesap" mobilde gösterilemiyor | Flutter uygulaması staging adresine bağlanıyor |
| Entegrasyon hataları 7 ayrı makinede ayrı keşfediliyor | Tek yerde, herkesin gördüğü şekilde |

---

## 2. Erişim modeli — kimin neye erişimi var

| Kim | Erişim |
|---|---|
| Yazılım ekibinin tamamı (7 kişi) | Tarayıcıdan staging adresi. **SSH yok** |
| Deploy sorumlusu + **1 yedek** | SSH |

> **Neden herkese SSH verilmiyor:** staging bir makine değil, bir URL. Yedi
> kişiye production benzeri bir sunucuda root vermek, birinin
> `docker compose down -v` yazıp veritabanını silmesinin en kısa yolu.
> Kimsenin kötü niyeti gerekmiyor.
>
> **Neden yedek kişi ŞART:** anahtar tek kişideyse, o kişi demo gününden bir
> gün önce hastalanırsa kimse deploy edemez. Bus factor 1 gerçek bir risk.

Yedek kişinin anahtarını eklemek (sunucuda):

```bash
echo "ssh-ed25519 AAAA... arkadas@makine" >> ~/.ssh/authorized_keys
```

---

## 3. Mimari

```
                 ┌──────── Caddy (80/443, otomatik HTTPS) ────────┐
  tarayıcı ─────▶│  /         →  web        (nginx + Vite çıktısı) │
  mobil    ─────▶│  /api/*    →  api        (.NET 10)              │
                 │  /tiles/*  →  tileserver                        │
                 └───────────────────┬────────────────────────────┘
                                     │ docker iç ağı (dışarı KAPALI)
                                ┌────┴────┐
                                │ postgis │
                                └─────────┘
```

**Tek origin.** Web ve API aynı adresten sunulduğu için CORS hiç devreye
girmiyor. Ayrı alt alan adı (`api.domain.xyz`) seçilseydi CORS yapılandırması
zorunlu olurdu.

---

## 4. Sunucu

| | Değer |
|---|---|
| Sağlayıcı | Hetzner Cloud |
| Tip | **CPX21** (3 vCPU AMD / 4 GB / 80 GB) |
| Mimari | **x86 — ARM DEĞİL.** OSRM ve tileserver-gl'in arm64 imajları sorunlu |
| Lokasyon | Falkenstein / Nürnberg / Helsinki (Türkiye'ye ~50–70 ms) |
| İşletim sistemi | Ubuntu 24.04 LTS |

Bellek dağılımı: postgis ~1 GB · api ~300 MB · tileserver ~500 MB ·
caddy + web ~100 MB · OS ~350 MB → **~2,5 GB.** 4 GB rahat.

---

## 5. İlk kurulum

### 5.1 Sunucuyu sertleştir

```bash
ssh root@<IP>

apt update && apt upgrade -y
apt install -y ufw fail2ban unattended-upgrades

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# SSH: yalnızca anahtar
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
```

> ⚠️ `PasswordAuthentication no` yapmadan ÖNCE anahtarınla girebildiğini
> doğrula. Aksi halde kendini kilitlersin.

### 5.2 Docker

```bash
curl -fsSL https://get.docker.com | sh
docker compose version
```

### 5.3 Dosyaları yerleştir

```bash
mkdir -p /opt/vivido && cd /opt/vivido

# Depodan yalnızca gerekli dosyalar (kaynak kod GEREKMİYOR)
#   deploy/Caddyfile → ./Caddyfile
#   deploy/docker-compose.prod.yml → ./docker-compose.prod.yml
#   db/ → ./db          (şema + migrate.sh)

cp deploy/.env.example .env
nano .env      # ⚠️ TÜM parolaları doldur, açıklamaları oku
```

`Jwt__Key` üretimi:

```bash
openssl rand -base64 48
```

### 5.4 Veri artefaktları

```bash
mkdir -p /opt/vivido/data/artifacts
cd /opt/vivido/data/artifacts

gh release download data-v1 --repo faygun21/vivido

# ⚠️ `gh release download` ARŞİVLERİ AÇMAZ, yalnızca indirir. Bu adım
# atlanırsa osrm/{car,foot} boş kalır; docker bind mount için o klasörleri
# kendisi yaratır, `osrm-routed` içeride cankaya.osrm.* bulamaz ve
# "Restarting (1)" döngüsüne girer. Site tamamen sağlıklı görünür, YALNIZCA
# rota oluşturma 503 döner. Staging'de tam olarak bu oldu.
tar -xzf osrm-car.tar.gz
tar -xzf osrm-foot.tar.gz
```

Doğrula — `cankaya.osrm` diye TEK bir dosya yoktur, `cankaya.osrm.*` uzantılı
~26 dosya olur (komuttaki yol taban addır). Zincirin son adımının çıktısına
bakmak yeterli:

```bash
ls /opt/vivido/data/artifacts/osrm/car/cankaya.osrm.cell_metrics
ls /opt/vivido/data/artifacts/osrm/foot/cankaya.osrm.cell_metrics
```

### 5.5 İmajları çek ve başlat

```bash
cd /opt/vivido
echo $GHCR_TOKEN | docker login ghcr.io -u faygun21 --password-stdin

docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

### 5.6 Şema ve veri

```bash
# Şema (initdb.d ilk açılışta çalıştı; sonraki dosyalar için)
docker compose -f docker-compose.prod.yml exec -T postgis bash /db/migrate.sh

# Referans veri + 6.000 konut + erişim matrisi
docker compose -f docker-compose.prod.yml exec -T postgis \
  psql -U vivido -d vivido -v ON_ERROR_STOP=1 -f /seed/seed.sql
```

### 5.7 Doğrula

```bash
curl -s http://<IP>/api/v1/health/ready     # Healthy
curl -s -o /dev/null -w "%{http_code}\n" http://<IP>/            # 200
curl -s http://<IP>/tiles/data/v3.json | head -c 200             # TileJSON
```

Sonra tarayıcıdan: kayıt → e-postaya gelen kod → doğrula → harita.

---

## 6. Domain ve HTTPS

Sunucu IP ile çalıştıktan **sonra**:

1. DNS'te A kaydı: `@` ve `www` → sunucu IP'si
2. `dig vividoapp.xyz +short` ile çözümlendiğini doğrula
3. `/opt/vivido/.env`:
   ```
   SITE_ADDRESS=vividoapp.xyz
   PUBLIC_TILE_URL=https://vividoapp.xyz/tiles/
   ```
4. `docker compose -f docker-compose.prod.yml up -d`

Caddy sertifikayı kendi alır ve otomatik yeniler.

> ⚠️ Cloudflare DNS kullanıyorsanız **turuncu bulut (proxy) KAPALI** olsun.
> Açıkken Caddy'nin Let's Encrypt doğrulaması sorun çıkarır.
>
> ⚠️ A kaydı çözümlenmeden `SITE_ADDRESS`'i domain'e çevirmeyin — Caddy
> sertifika alamayıp tekrar tekrar dener ve rate limit'e takılırsınız.

---

## 7. Günlük deploy

```bash
cd /opt/vivido
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml exec -T postgis bash /db/migrate.sh
docker compose -f docker-compose.prod.yml up -d
```

~30 saniye. Sunucu **derleme yapmıyor** — imajlar CI'da derlenip GHCR'ye
itiliyor. Sunucuda `dotnet publish` çalıştırmak 4 GB'lık makinede OOM riski.

---

## 8. Yedekleme

```bash
# /etc/cron.daily/vivido-backup
docker compose -f /opt/vivido/docker-compose.prod.yml exec -T postgis \
  pg_dump -U vivido vivido | gzip > /opt/vivido/backups/$(date +%F).sql.gz
find /opt/vivido/backups -name '*.sql.gz' -mtime +14 -delete
```

Ortak veritabanında biri yanlışlıkla `TRUNCATE` çekerse 6.000 konut ve
48.000 satırlık erişim matrisi gider. `seed.sql`'den yeniden yüklenebilir
ama kullanıcı hesapları geri gelmez.

---

## 9. Sorun giderme

| Belirti | Sebep |
|---|---|
| **Harita boş, kontroller çalışıyor** | `PUBLIC_TILE_URL` yanlış. tileserver TileJSON'a mutlak adres yazıyor; `/tiles` ön eki eşleşmezse karolar 404 alır ve hata görünmez |
| Sayfa yenilenince 404 | nginx SPA geri dönüşü — `web/nginx.conf` içindeki `try_files` |
| `password authentication failed` | `.env`'deki `POSTGRES_PASSWORD` volume oluşturulduğundaki parolayla aynı değil. Parola volume'e gömülüdür, sonradan değiştirilemez |
| Sertifika alınamıyor | A kaydı henüz çözümlenmiyor, ya da Cloudflare proxy açık |
| Web API'ye ulaşamıyor | Tek origin'de olmamalı. Ayrı origin kullanıyorsanız `Cors__AllowedOrigins` |
| Doğrulama e-postası gitmiyor | `Email__Password` 16 haneli uygulama şifresi mi, boşluklar silindi mi (README §2.5) |

---

## 10. Yapılmayanlar — bilinçli

| | Neden |
|---|---|
| Redis yok | R-C: skor cache'i kesildi, kod hiç kullanmıyor |
| pgadmin yok | Yönetim arayüzü internete açılmaz |
| OSRM varsayılan kapalı | Hafta 3'te rota gelince `--profile routing` ile açılır |
| İzleme/alarm yok | Üç haftalık proje. `/health/ready` yeterli |
| Ayrı prod ortamı yok | Tek staging hem entegrasyon hem demo |

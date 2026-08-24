# Vivido Mobile

Flutter istemcisi; Vivido API ile giriş/kayıt, persona ve bütçe seçimi, önemli
konum (anchor) yönetimi ve Çankaya vektör haritasını içerir.

## Yerel çalıştırma

Önce proje kökünde API, veritabanı ve tile sunucusunu çalıştırın. Android
emülatörü için varsayılan adresler hazırdır:

- API: `http://10.0.2.2:5000/api/v1`
- Tile server: `http://10.0.2.2:8080`

Ardından:

```powershell
cd mobile
flutter pub get
flutter run
```

Fiziksel telefonda `10.0.2.2` çalışmaz. Bilgisayarın telefondan erişilebilen
yerel ağ IP adresini verin ve API'yi bu arayüzde dinletecek şekilde başlatın:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000/api/v1 --dart-define=TILE_BASE_URL=http://192.168.1.10:8080
```

Adreslerdeki IP'yi bilgisayarınızın gerçek yerel ağ IP'siyle değiştirin.

## Kontrol

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

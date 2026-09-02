import 'package:flutter/material.dart';

/// Vivido tasarım belirteçleri — **tek kaynak `web/src/styles/tokens.css`**.
///
/// Buradaki isimler CSS değişkenleriyle BİREBİR aynı (`--bg` → [bg],
/// `--ink-muted` → [inkMuted], `--accent-soft` → [accentSoft]). Böylece web
/// paleti değiştiğinde hangi Dart sabitinin güncelleneceği aramaya gerek
/// kalmadan görünüyor.
///
/// ⚠️ Mobil eskiden `ColorScheme.fromSeed(#087F5B)` ile YEŞİL bir palet
/// üretiyordu; web ise terracotta (`#C0421D`). İki uygulama yan yana
/// konduğunda aynı ürün gibi durmuyordu. Renkleri Material'ın türetmesine
/// bırakmak yerine burada açıkça yazıyoruz.
///
/// ⚠️ Bu dosya eskiden yalnızca dokuz marka rengini taşıyordu. Web o zamandan
/// beri türetilmiş renkleri (`--accent-hover`, `--line-soft`, …), durum
/// renklerini (`--ok`/`--warn`/`--bad`/`--info`/`--live`) ve malzeme
/// katmanını (`--material-*`) ekledi; mobil ekranlar bu boşluğu ekran ekran
/// `Color(0xFFFFEDD5)`, `Colors.red.shade100`, `#047857` gibi elle yazılmış
/// değerlerle dolduruyordu. Hepsi buraya toplandı.
abstract final class AppColors {
  // ── 1. PALET — web ile birebir ───────────────────────────────────────

  /// `--bg` — sayfa zemini. Sıcak krem; saf beyaz DEĞİL.
  static const Color bg = Color(0xFFF9F4ED);

  /// `--surface` — kart, panel, sayfa yüzeyi.
  static const Color surface = Color(0xFFFFFFFF);

  /// `--ink` — birincil metin.
  static const Color ink = Color(0xFF333333);

  /// `--ink-muted` — ikincil metin, yardım satırları.
  static const Color inkMuted = Color(0xFF737373);

  /// `--line` — kenarlık ve ayraçlar. Nötr gri değil, zeminle uyumlu sıcak gri.
  static const Color line = Color(0xFFA79D93);

  /// `--accent` — birincil eylem rengi (terracotta).
  static const Color accent = Color(0xFFC0421D);

  /// `--accent-secondary` — vurgunun açık tonu; hover/ikincil durumlar.
  ///
  /// ⚠️ BU BİR BİRİNCİL DÜĞME RENGİ DEĞİL. Giriş/kayıt/karşılama ekranları
  /// birincil düğmeyi bu renkle boyuyordu ve auth akışı uygulamanın geri
  /// kalanından farklı bir turuncu kullanıyordu. Birincil eylem [accent].
  static const Color accentSecondary = Color(0xFFE27250);

  /// `--accent-ink` — vurgu üzerindeki metin.
  static const Color accentInk = Color(0xFFFFFFFF);

  /// `--input-bg` — form alanı zemini.
  static const Color inputBg = Color(0xFFECEAE6);

  // ── 2. PALETTEN TÜRETİLENLER ─────────────────────────────────────────
  // Yeni renk değil; mevcut renklerin tekrar tekrar elle yazılan varyantları.

  /// `--accent-hover` — accent'in %12 koyusu. Basılı/vurgulu durum.
  static const Color accentHover = Color(0xFFA53818);

  /// `--accent-active` — dokunma anındaki en koyu ton.
  static const Color accentActive = Color(0xFF8E2F13);

  /// `--accent-soft` — seçili/aktif durumların yumuşak zemini.
  static Color get accentSoft => accent.withValues(alpha: 0.10);

  /// `--accent-soft-strong` — daha belirgin seçili zemin.
  static Color get accentSoftStrong => accent.withValues(alpha: 0.16);

  /// `--accent-edge` — accent'li yüzeylerin ince kenarı.
  static Color get accentEdge => accent.withValues(alpha: 0.35);

  /// `--line-faint` / `--line-soft` / `--line-strong` — çizgi kademeleri.
  static Color get lineFaint => line.withValues(alpha: 0.22);
  static Color get lineSoft => line.withValues(alpha: 0.45);
  static Color get lineStrong => line.withValues(alpha: 0.70);

  /// Kartların gördüğü somut kenarlık rengi — `--line-faint`'in opak
  /// karşılığı. Saydam kenarlık, üst üste binen kartlarda koyulaşıyordu.
  static const Color border = Color(0xFFE3DDD5);

  /// `--surface-sunken` — krem zeminle beyaz kart arasındaki ara ton.
  static Color get surfaceSunken => Color.lerp(surface, bg, 0.6)!;

  // ── 3. DURUM RENKLERİ ────────────────────────────────────────────────
  // Skor bantları ve geri bildirim. Eşikler `packages/shared/src/utils.ts`
  // `scoreBand()` ile senkron: >=85 excellent · >=70 good · >=55 fair · poor.

  /// `--ok` — mükemmel / güçlü yön.
  static const Color ok = Color(0xFF15803D);

  /// `--good` — iyi.
  static const Color good = Color(0xFF4D7C0F);

  /// `--warn` — orta / dikkat.
  static const Color warn = Color(0xFFB45309);

  /// `--bad` — zayıf / hata.
  static const Color bad = Color(0xFF9A3412);

  /// `--info` — nötr bilgi (ör. bütçenin altında).
  static const Color info = Color(0xFF0F766E);

  /// `--live` — canlı GPS konumu (harita).
  ///
  /// Vurgu rengi BİLEREK kullanılmadı: o renk konut ve rota öğelerinin
  /// rengi. Kullanıcının kendi konumu bir içerik değil, referans noktası.
  static const Color live = Color(0xFF2563EB);

  // Skor bantları — [ok]/[good]/[warn]/[bad]'in okunur takma adları.
  // `web/src/index.css` `.score-badge--*` ile aynı değerler.
  //
  // ⚠️ Bandı SKORDAN türeten fonksiyonlar burada DEĞİL,
  // `features/properties/presentation/property_format.dart` içinde
  // (`scoreBandColor`, `scoreBandLabel`, `scoreBandOf`). Burada da bir kopya
  // vardı ve iki kopya farklı Türkçe etiket döndürüyordu — aynı ev bir
  // ekranda "Çok iyi", başka bir ekranda "Çok uygun" görünüyordu.
  static const Color bandExcellent = ok;
  static const Color bandGood = good;
  static const Color bandFair = warn;
  static const Color bandPoor = bad;

  // ── 4. HARİTA RENKLERİ ───────────────────────────────────────────────
  // Haritada çizilen şeyler paletten DEĞİL, okunabilirlikten türüyor:
  // canlı bir zeminin üstünde kendi aralarında ayrışmaları gerekiyor.
  // Değerler `web/src/shared/map/CankayaMap.tsx` ile birebir aynı.

  /// Konut pini / kümesi. Marka accent'inden bir tık parlak — harita
  /// zemini üzerinde accent yeterince ayrışmıyordu.
  ///
  /// ⚠️ Bu renk ÜÇ ayrı yerde farklı yazılıydı: mobil harita `#C0421D`,
  /// mobil katman paneli `#EA580C`, web `#ea580c`. Web kazandı.
  static const Color mapProperty = Color(0xFFEA580C);

  /// Favori konut halkası — koyu altın. Haritadaki hiçbir dolu daireyle
  /// çakışmıyor (konut `#ea580c`, okul POI `#f59e0b`, yemek `#f97316`).
  static const Color mapFavorite = Color(0xFFD97706);

  /// Rota çizgisi ve durak pinleri.
  static const Color mapRoute = Color(0xFF2563EB);

  /// Rota çizgisinin altındaki koyu gölge hattı.
  static const Color mapRouteCasing = Color(0xFF1E3A8A);

  /// Tamamlanmış rota bölümü (navigasyon).
  static const Color mapRouteTraveled = Color(0xFF94A3B8);

  /// Analiz alanı (yarıçap dairesi).
  static const Color mapAnalysis = info;

  /// Yürüme erişim alanı.
  static const Color mapWalking = Color(0xFFF59E0B);
  static const Color mapWalkingEdge = warn;

  /// Analiz merkezi noktasının koyu çerçevesi — sarı dolgu üstünde
  /// okunması için kehribardan bir tık koyu.
  static const Color mapWalkingCore = Color(0xFF7C2D12);

  /// Anchor koridoru (mor). Haritadaki diğer alanlardan ayrışsın diye
  /// paletin dışında; web `anchor-alani-*` katmanlarıyla aynı.
  static const Color mapAnchorArea = Color(0xFF7C3AED);

  /// Harita karoları yüklenene kadar görünen zemin. Gri değil, harita
  /// arka planının (`#eef2f0`) hafif yeşilimsi tonu — açılışta ekranın
  /// rengi bir anda değişmesin.
  static const Color mapLoading = Color(0xFFE8F0ED);

  /// Çankaya ilçe sınırı.
  static const Color mapDistrict = Color(0xFF0B3D35);

  /// Mahalle poligonları.
  static const Color mapNeighborhood = Color(0xFF7FB3A8);
  static const Color mapNeighborhoodEdge = Color(0xFF4A8578);
}

/// `--shadow-xs|sm|md|lg|xl` karşılıkları.
///
/// ⚠️ BÜYÜK YÜZEY DAHA KALIN OKUNUR. Eskiden 48px'lik harita düğmesi ile
/// tam ekran bir çekmece aynı `md` gölgeyi paylaşıyordu; ikisi de aynı
/// yükseklikte duruyormuş gibi görünüyordu.
///
/// Gölge rengi soğuk gri değil SICAK kahve-gri (`#332D28`): zemin krem
/// (`#F9F4ED`). Nötr gri bir gölge krem üzerinde mavimsi ve "yapıştırılmış"
/// durur.
abstract final class AppShadows {
  /// `--shadow-tint` — sıcak kahve-gri. Gölge çizen her yer bunu
  /// kullanıyor; `Colors.black26` krem zeminde mavimsi duruyordu.
  static const Color tint = Color(0xFF332D28);
  static const Color _tint = tint;

  /// Zar zor ayrışan yükseklik — çip, satır içi rozet.
  static List<BoxShadow> get xs => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// Kart, liste öğesi.
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _tint.withValues(alpha: 0.06),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Harita üstündeki küçük kontrol (FAB, arama çubuğu).
  static List<BoxShadow> get md => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: _tint.withValues(alpha: 0.09),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// Panel, açılır menü, alt sayfa.
  static List<BoxShadow> get lg => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.05),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: _tint.withValues(alpha: 0.13),
      blurRadius: 34,
      offset: const Offset(0, 14),
    ),
  ];

  /// Tam ekran çekmece, modal.
  static List<BoxShadow> get xl => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: _tint.withValues(alpha: 0.18),
      blurRadius: 64,
      offset: const Offset(0, 28),
    ),
  ];

  /// `--shadow-accent` — accent'li düğmelerin gölgesi rengini DÜĞMEDEN alır.
  /// Nötr gri bir gölge dolu turuncu bir düğmenin altında ölü durur.
  static List<BoxShadow> get accent => [
    BoxShadow(
      color: AppColors.accent.withValues(alpha: 0.32),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];
}

/// `--material-*` — harita üstünde yüzen katmanın malzemesi.
///
/// Harita canlı, renkli ve hareketli bir zemin. Üstündeki OPAK BEYAZ kutular
/// "ekrana yapıştırılmış" duruyordu. Yarı saydam + bulanık bir yüzey,
/// altındaki haritanın rengini taşıyarak aynı dünyanın parçası gibi okunur.
///
/// Flutter'da bulanıklık `BackdropFilter` ile geliyor; bu sınıf yalnızca
/// sayıları taşıyor, uygulaması `shared/widgets/glass_surface.dart`'ta.
abstract final class AppMaterials {
  /// `--material-blur` — küçük kontroller.
  static const double blurSigma = 10;

  /// `--material-blur-strong` — büyük yüzeyler.
  static const double blurSigmaStrong = 15;

  /// `--material-thin` — küçük kontroller (FAB, arama çubuğu).
  static Color get thin => AppColors.surface.withValues(alpha: 0.74);

  /// `--material-thick` — büyük yüzeyler (panel, çekmece). Metin taşıdığı
  /// için daha opak.
  static Color get thick => AppColors.surface.withValues(alpha: 0.88);

  /// `--material-edge` — malzemenin üst kenarındaki ışık; cam yüzeyin
  /// kalınlığını belli eder.
  static Color get edge => Colors.white.withValues(alpha: 0.65);

  /// `--scrim` — modal arkasındaki karartma.
  static Color get scrim => const Color(0xFF2A231D).withValues(alpha: 0.42);
}

/// Köşe yarıçapları — `--r-xs` … `--r-pill`.
///
/// Web 16 px kök font kullanıyor, yani `1.1rem ≈ 17.6 px`. Yuvarlak sayılara
/// çekildi; göz farkı ayırt edemiyor, kod okunur kalıyor.
///
/// ⚠️ Eskiden dört basamak vardı ve ekranlar aradaki değerleri elle yazıyordu
/// (`12`, `16`, `18`, `22`). Altı basamak, web ölçeğiyle birebir.
abstract final class AppRadius {
  /// `--r-xs` (0.5rem) — rozet, küçük çip.
  static const double xs = 8;

  /// `--r-sm` (0.7rem) — ikon düğmesi, çip.
  static const double sm = 11;

  /// `--r-md` (0.9rem) — girdi, küçük kart.
  static const double md = 14;

  /// `--r-lg` (1.1rem) — kart, tablo kabı.
  static const double lg = 18;

  /// `--r-xl` (1.4rem) — panel, form kartı, birincil düğme.
  static const double xl = 22;

  /// `--r-pill` — hap biçimli düğmeler.
  static const double pill = 999;
}

/// Boşluk ölçeği — 4 px tabanlı.
///
/// Web'de boşluklar `rem` cinsinden ve doğal olarak tutarlıydı; mobilde
/// her ekran kendi sayısını uyduruyordu (`4 · 6 · 7 · 8 · 10 · 12 · 14 ·
/// 16 · 18 · 20 · 22 · 24 · 28`). "Panellerin yerleri boyutlarına kadar
/// orantısız" görünmesinin sebebi buydu.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Sayfa kenar boşluğu — liste ve form ekranlarının hepsi bunu kullanır.
  static const double page = md;

  // ── Harita kabuğu ──────────────────────────────────────────────────
  // Harita üstündeki her kontrol AYNI ızgaradan besleniyor. Eskiden
  // `top + 10`, `top + 74`, `bottom: 12`, `bottom: 74`, `left: 12`,
  // genişlik `168` gibi birbiriyle ilgisiz sayılar vardı; dar telefonda
  // rota şeridi katman düğmesinin, kaydet düğmesi analiz düğmesinin
  // üstüne biniyordu.

  /// Haritanın kenarından kontrole kadar olan boşluk.
  static const double mapGutter = sm;

  /// Üst üste yığılan harita kontrolleri arası boşluk.
  static const double mapStack = sm;

  /// Yuvarlak harita düğmesinin çapı. Material'ın 48 dp dokunma hedefi.
  static const double mapControl = 48;

  /// Arama çubuğunun yüksekliği — altındaki kontrol sırası buna göre iner.
  static const double mapSearchHeight = 52;
}

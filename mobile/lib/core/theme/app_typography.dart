import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografi ölçeği — **tek kaynak `web/src/styles/tokens.css` §7**.
///
/// ⚠️ NEDEN BİR ÖLÇEK GEREKİYOR
///
/// Mobilde tipografi ölçeği HİÇ YOKTU. Her ekran kendi sayısını uyduruyordu:
/// `fontSize: 10.5`, `11.5`, `12.5`, `13.5`, `17`, `18`, `20`, `25` ve
/// `FontWeight.w700/w800/w900` gelişigüzel dağılmıştı. Aynı öneme sahip iki
/// başlık iki ekranda iki farklı boyuttaydı. "Profesyonel görünmüyor"
/// hissinin en büyük tek sebebi buydu — renk değil, tipografi.
///
/// ⚠️ TRACKING BOYUTA BAĞLI
///
/// Harf aralığı büyüdükçe optik olarak açılır: 32 px'lik bir başlıkta
/// harfler birbirinden uzak durur, 11 px'lik bir etikette okunamaz hâle
/// gelir. Bu yüzden büyük başlıklar NEGATİF, küçük etiketler POZİTİF
/// tracking alır. Tek bir `letterSpacing` değeri her boyutta yanlıştır.
///
/// CSS `em` cinsinden yazıyor (`-0.035em`), Flutter mantıksal piksel
/// istiyor — dönüşüm `em × fontSize` olarak burada yapılmış durumda.
///
/// ⚠️ LEADING TERS YÖNDE
///
/// Satır yüksekliği boyutla TERS orantılı: büyük başlık sıkı (1.06), gövde
/// metni ferah (1.6). Sabit bir `height` büyük başlıkta dağınık, küçük
/// metinde boğuk görünür.
abstract final class AppType {
  static const String fontFamily = 'Poppins';

  // Ağırlıklar — `pubspec.yaml`'da kayıtlı DÖRT kesim var (400/500/600/700).
  // `w800`/`w900` kayıtlı değil; Flutter onları sentezleyemediği için
  // (`fontSynthesis` yok) sessizce 700'e düşürüyordu. Ekranların
  // `w800`/`w900` yazması bu yüzden hiçbir görsel fark üretmiyor, sadece
  // "burada daha kalın bir şey var" yanılgısı yaratıyordu.
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// `--fs-display` — karşılama ekranı sloganı, tek seferlik büyük anlar.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 1.06,
    letterSpacing: -1.12, // -0.035em
    fontWeight: bold,
    color: AppColors.ink,
  );

  /// `--fs-h1` — sayfa başlığı.
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.16,
    letterSpacing: -0.67, // -0.028em
    fontWeight: bold,
    color: AppColors.ink,
  );

  /// `--fs-h2` — bölüm başlığı, kart başlığı.
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19.5,
    height: 1.28,
    letterSpacing: -0.35, // -0.018em
    fontWeight: semibold,
    color: AppColors.ink,
  );

  /// `--fs-h3` — alt başlık, liste öğesi başlığı.
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.35,
    letterSpacing: -0.16, // -0.01em
    fontWeight: semibold,
    color: AppColors.ink,
  );

  /// `--fs-body` — gövde metni.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.6,
    letterSpacing: 0,
    fontWeight: regular,
    color: AppColors.ink,
  );

  /// `--fs-sm` — yardım satırı, kart alt bilgisi.
  static const TextStyle sm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    height: 1.5,
    letterSpacing: 0.03, // 0.002em
    fontWeight: regular,
    color: AppColors.ink,
  );

  /// `--fs-xs` — rozet metni, ikincil etiket.
  static const TextStyle xs = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.45,
    letterSpacing: 0.1, // 0.008em
    fontWeight: medium,
    color: AppColors.ink,
  );

  /// `--fs-micro` — BÜYÜK HARFLİ mikro etiket (tablo başlığı, bölüm adı).
  ///
  /// Versal harfler doğal boşluklarını kaybeder — belirgin pozitif tracking
  /// şart, yoksa kelime tek bir blok gibi okunur.
  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.4,
    letterSpacing: 0.6, // 0.055em
    fontWeight: semibold,
    color: AppColors.inkMuted,
  );

  /// Rakamların hizalı çizilmesi için — skor rozetleri, süre/mesafe, fiyat.
  ///
  /// Poppins orantısal rakam kullanıyor: "111" ile "888" farklı genişlikte
  /// çiziliyor ve bir liste boyunca sayılar titriyor. `tnum` sabit genişlik
  /// verir; harita üstündeki canlı sayaçlarda (navigasyon mesafesi) fark
  /// gözle görülür.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  /// Yardımcı: bir stili soluk mürekkeple döndürür.
  static TextStyle muted(TextStyle style) =>
      style.copyWith(color: AppColors.inkMuted);

  /// Yardımcı: bir stili verilen ağırlıkla döndürür.
  static TextStyle weight(TextStyle style, FontWeight value) =>
      style.copyWith(fontWeight: value);

  /// Material'ın metin yuvalarına eşleme.
  ///
  /// Material bileşenleri (ListTile, AppBar, Chip, SnackBar…) kendi
  /// tipografilerini `TextTheme`den okuyor. Eşlemeyi yapmazsak o bileşenler
  /// Android'in varsayılan yazı tipi ölçeğiyle çizilir ve elle stil verdiğimiz
  /// metinlerin yanında yabancı durur.
  static TextTheme get textTheme => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: h1,
    headlineMedium: h1,
    headlineSmall: h1.copyWith(fontSize: 21, letterSpacing: -0.55),
    titleLarge: h2,
    titleMedium: h3,
    titleSmall: h3.copyWith(fontSize: 14.5),
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: sm,
    labelLarge: sm.copyWith(fontWeight: semibold),
    labelMedium: xs,
    labelSmall: micro,
  );
}

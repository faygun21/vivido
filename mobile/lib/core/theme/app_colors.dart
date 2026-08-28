import 'package:flutter/material.dart';

/// Vivido tasarım belirteçleri — **tek kaynak `web/src/index.css` `:root`**.
///
/// Buradaki isimler CSS değişkenleriyle BİREBİR aynı (`--bg` → [bg],
/// `--ink-muted` → [inkMuted]). Böylece web paleti değiştiğinde hangi Dart
/// sabitinin güncelleneceği aramaya gerek kalmadan görünüyor.
///
/// ⚠️ Mobil eskiden `ColorScheme.fromSeed(#087F5B)` ile YEŞİL bir palet
/// üretiyordu; web ise terracotta (`#C0421D`). İki uygulama yan yana
/// konduğunda aynı ürün gibi durmuyordu. Renkleri Material'ın türetmesine
/// bırakmak yerine burada açıkça yazıyoruz.
abstract final class AppColors {
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
  static const Color accentSecondary = Color(0xFFE27250);

  /// `--accent-ink` — vurgu üzerindeki metin.
  static const Color accentInk = Color(0xFFFFFFFF);

  /// `--input-bg` — form alanı zemini.
  static const Color inputBg = Color(0xFFECEAE6);

  // ── Skor bantları ────────────────────────────────────────────────────
  // Eşikler `packages/shared/src/utils.ts` `scoreBand()` ile senkron:
  //   >=85 excellent · >=70 good · >=55 fair · gerisi poor
  // Renkler `web/src/index.css` `.score-badge--*` ile aynı.

  static const Color bandExcellent = Color(0xFF15803D);
  static const Color bandGood = Color(0xFF4D7C0F);
  static const Color bandFair = Color(0xFFB45309);
  static const Color bandPoor = Color(0xFF9A3412);

  /// Skoru web'le AYNI eşiklerle banda çevirir.
  ///
  /// Eşikleri burada tekrar yazmak zorundayız (Dart, TS sabitini okuyamaz);
  /// bu yüzden değiştirirken `packages/shared/src/utils.ts` ile birlikte
  /// değiştirin — yoksa aynı ev webde "İyi", mobilde "Orta" görünür.
  static Color band(double total) {
    if (total >= 85) return bandExcellent;
    if (total >= 70) return bandGood;
    if (total >= 55) return bandFair;
    return bandPoor;
  }

  /// Bandın Türkçe adı — rozetlerde skorun altında yazar.
  static String bandLabel(double total) {
    if (total >= 85) return 'Çok iyi';
    if (total >= 70) return 'İyi';
    if (total >= 55) return 'Orta';
    return 'Zayıf';
  }
}

/// `--shadow-sm|md|lg` karşılıkları.
///
/// Web'deki gölgeler `rgb(51 51 51 / …)` yani mürekkep renginden türüyor —
/// saf siyah gölge sıcak zeminde gri ve kirli duruyordu. Aynı yaklaşım.
abstract final class AppShadows {
  static const Color _base = Color(0xFF333333);

  static List<BoxShadow> get sm => [
    BoxShadow(
      color: _base.withValues(alpha: 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _base.withValues(alpha: 0.08),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: _base.withValues(alpha: 0.10),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: _base.withValues(alpha: 0.16),
      blurRadius: 34,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Köşe yarıçapları — web'deki `border-radius` değerlerinin karşılığı.
///
/// Web 16 px kök font kullanıyor, yani `1.1rem ≈ 17.6 px`. Yuvarlak
/// sayılara çekildi; göz farkı ayırt edemiyor, kod okunur kalıyor.
abstract final class AppRadius {
  /// Küçük öğeler — rozet, çip içi (`0.7rem`).
  static const double sm = 11;

  /// Form alanı, buton (`0.9rem`).
  static const double md = 14;

  /// Kart ve panel (`1.1rem`).
  static const double lg = 18;

  /// Hap biçimli düğmeler (`999px`).
  static const double pill = 999;
}

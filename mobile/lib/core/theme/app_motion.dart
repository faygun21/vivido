import 'package:flutter/material.dart';

/// Hareket ölçeği — **tek kaynak `web/src/styles/tokens.css` §8**.
///
/// Mobilde hareket tasarımı YOKTU: birkaç yerde `Duration(milliseconds: 180)`
/// ve `Curves.easeOut` vardı, gerisi anlık geçişti. Web'in `motion.css`'i
/// süreleri AMACA göre ayırıyor, "güzel görünsün" diye değil.
///
/// ⚠️ SÜRE AMACA GÖRE, MESAFEYE GÖRE
///
/// Büyük bir yüzey (çekmece) küçük bir yüzeyden (çip) daha uzun yol alır;
/// ikisine aynı süreyi vermek büyüğü aceleci, küçüğü tembel gösterir.
///
/// ⚠️ EĞRİLER AYNA OLMAK ZORUNDA
///
/// [easeOut] iOS'un yüzey eğrisi — kritik sönümlü bir yayın CSS karşılığı,
/// sonu tamamen düz, taşma yok. [easeIn] onun AYNASI: kontrol noktaları ters
/// çevrildi ki aynı geçişin gidişi ve dönüşü aynı yolu izlesin. Farklı eğri
/// kullanan bir geçiş "geri sarılmış" gibi durur.
///
/// [spring] HAFİF taşar ve yalnızca kullanıcının kendi momentum taşıyan
/// hareketinden sonra kullanılır (kart seçimi, favori basma, rozet artışı).
/// Kendiliğinden beliren bir menüde taşma yanlıştır.
abstract final class AppMotion {
  // ── Süreler ──────────────────────────────────────────────────────────

  /// Basma geri bildirimi. Parmak altındaki tepki ALGILANIR gecikme
  /// taşıyamaz — bu eşiğin üstü "geç kaldı" diye okunur.
  static const Duration instant = Duration(milliseconds: 110);

  /// Renk, hover, küçük durum değişimi.
  static const Duration fast = Duration(milliseconds: 180);

  /// Kart, çip, açılır menü.
  static const Duration base = Duration(milliseconds: 260);

  /// Panel, çekmece — büyük yüzey daha uzun yol alır.
  static const Duration slow = Duration(milliseconds: 380);

  /// Sayfa girişi.
  static const Duration page = Duration(milliseconds: 520);

  /// Harita kamerası. Native tarafa geçtiği için ayrı: kamera hareketi bir
  /// arayüz geçişi değil, mekânda yolculuk — daha uzun olması doğru.
  static const Duration camera = Duration(milliseconds: 650);

  // ── Eğriler ──────────────────────────────────────────────────────────

  /// Giren yüzeyler. Sonu düz — taşma yok.
  static const Curve easeOut = Cubic(0.32, 0.72, 0, 1);

  /// [easeOut]'un aynası. Çıkan yüzeyler.
  static const Curve easeIn = Cubic(1, 0, 0.68, 0.28);

  /// İki yönlü geçişler (yer değiştiren, boyut değiştiren).
  static const Curve easeInOut = Cubic(0.65, 0, 0.35, 1);

  /// HAFİF taşan eğri. Yalnızca kullanıcının kendi hareketi sonrasında.
  static const Curve spring = Cubic(0.2, 1.24, 0.36, 1);

  // ── Yay fiziği ───────────────────────────────────────────────────────
  // Sürükleme bittiğinde eğri yerine YAY kullanılır: eğrinin sabit bir
  // süresi var ve parmağın hızını devralamaz, o yüzden sürükleme ile
  // animasyon arasında görünür bir dikiş kalır. Yay hızı devralır.
  //
  // Sönümleme oranı 1.0 = kritik sönümlü (taşma yok) — arayüzün varsayılanı.
  // 0.8 = hafif taşma; yalnızca kullanıcı fırlatma/savurma yaptıysa.

  /// Kritik sönümlü — taşma yok. Yeniden konumlanma, panel oturması.
  static const SpringDescription settle = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 32.2, // 2 · sqrt(260) ≈ 32.25 → oran 1.0
  );

  /// Hafif taşmalı — momentum taşıyan bir hareketten SONRA.
  static const SpringDescription bouncy = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 28.6, // 0.8 · 2 · sqrt(320) ≈ 28.6
  );

  /// Sürüklemeden gelen momentumu, dinlenme noktasına yansıtır.
  ///
  /// iOS'un kaydırma yavaşlamasıyla aynı üstel sönüm biçimi
  /// (`Designing Fluid Interfaces` örnek kodu). Fizik kitabındaki
  /// `v²/(2·a)` DEĞİL — o, fırlatmayı olduğundan kısa gösterir.
  ///
  /// Bir alt sayfayı yarıda bırakıp fırlattığında, gideceği yeri BIRAKTIĞIN
  /// noktadan değil, gitmekte OLDUĞU noktadan seçmek gerekiyor; yoksa hızlı
  /// bir savurma bile "yeterince uzağa gitmedin" diye geri döner.
  static double projectFling(double velocityPxPerSecond, {double decelerationRate = 0.998}) =>
      (velocityPxPerSecond / 1000) * decelerationRate / (1 - decelerationRate);

  /// Listede sırayla beliren öğeler arası gecikme.
  ///
  /// Toplam gecikme sınırlanmalı: 40 öğelik bir listede her öğeye 40 ms
  /// verirsek son öğe 1,6 saniye sonra gelir ve liste "yükleniyor" gibi
  /// durur. Sekizinci öğeden sonra gecikme sabitleniyor.
  static Duration stagger(int index) =>
      Duration(milliseconds: 34 * (index.clamp(0, 7)));
}

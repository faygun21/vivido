import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/property_models.dart';

/// Konut kartlarının paylaştığı biçimlendirme yardımcıları —
/// `web/src/features/explore/propertyFormat.ts` ile birebir.
///
/// ⚠️ SKOR BANDI ÜÇ FARKLI YERDE ÜÇ FARKLI RENKTEYDİ
///
/// Buradaki [scoreBandColor] `#047857/#0F766E/#B45309/#B91C1C` döndürüyordu,
/// `AppColors.band()` `#15803D/#4D7C0F/#B45309/#9A3412`, web ise
/// (`.score-badge--*`) ikincisini. Aynı ev listede bir yeşil, detayda başka
/// bir yeşil rozet alıyordu. Tek kaynak artık [AppColors]; bu dosya yalnızca
/// bant KODUNU renge çeviriyor.
///
/// ⚠️ ETİKETLER DE AYRIŞMIŞTI
///
/// Mobil "Mükemmel / İyi / Orta / Düşük", web "Çok uygun / Uygun / Orta /
/// Zayıf" diyordu. Kullanıcıya gösterilen kelime web'inki: skor bir kalite
/// yargısı değil, KULLANICIYA UYGUNLUK ölçüsü — "mükemmel ev" yanlış vaat.

String formatPrice(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// `23750` → `23.750 ₺`
String formatRent(num monthlyRent) => '${formatPrice(monthlyRent)} ₺';

/// Bant → kullanıcıya gösterilecek Türkçe etiket (web `BAND_LABEL`).
String scoreBandLabel(String band) => switch (band) {
  'excellent' => 'Çok uygun',
  'good' => 'Uygun',
  'fair' => 'Orta',
  _ => 'Zayıf',
};

/// Bant → renk. Değerler `web/src/index.css` `.score-badge--*` ile aynı.
Color scoreBandColor(String band) => switch (band) {
  'excellent' => AppColors.ok,
  'good' => AppColors.good,
  'fair' => AppColors.warn,
  _ => AppColors.bad,
};

/// Skordan bant kodunu üretir — eşikler `packages/shared/src/utils.ts`
/// `scoreBand()` ile senkron. Yalnızca bandı gelmeyen kaynaklar için
/// (harita pini gibi); DTO'da `band` varsa O kullanılmalı.
String scoreBandOf(double total) {
  if (total >= 85) return 'excellent';
  if (total >= 70) return 'good';
  if (total >= 55) return 'fair';
  return 'poor';
}

/// Dakika değerini okunur hâle getirir: `4.9` → `4,9 dk`.
///
/// 60 dakikayı geçince saate çeviriyor — bazı kategorilerin kesme süresi
/// saatleri buluyor ve "82,3 dk" okuyucunun kafasında saate çevrilmiyor.
String formatMinutes(double minutes) {
  if (minutes < 60) {
    final rounded = (minutes * 10).round() / 10;
    final text =
        rounded == rounded.roundToDouble()
            ? rounded.toStringAsFixed(0)
            : rounded.toStringAsFixed(1).replaceAll('.', ',');
    return '$text dk';
  }
  final total = minutes.round();
  final hours = total ~/ 60;
  final remaining = total % 60;
  return remaining == 0 ? '$hours sa' : '$hours sa $remaining dk';
}

String formatDistance(int metres) =>
    metres < 1000
        ? '$metres m'
        : '${(metres / 1000).toStringAsFixed(metres >= 10000 ? 0 : 1).replaceAll('.', ',')} km';

String formatDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes dk';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '$hours sa' : '$hours sa $remaining dk';
}

/// Adresi iki satıra böler: sokak üstte, mahalle/ilçe altta.
///
/// Sunucu `formatted` alanını tek satır gönderiyor ama kartta sokak adı
/// başlık gibi öne çıkmalı — mobil bu ayrımı hiç yapmıyor, tek satırı
/// olduğu gibi basıyordu ve kartın en belirgin metni "Çankaya, Ankara"
/// oluyordu (her kartta aynı).
///
/// Sokak yoksa (streets tablosu yüklenmemiş ya da yakında adlı sokak yok)
/// mahalle üst satıra terfi eder — kart boş görünmesin.
({String primary, String secondary}) splitAddress(PropertyAddress address) {
  final region = '${address.districtName} / ${address.cityName}';
  final street = address.streetName?.trim();
  final neighborhood = address.neighborhoodName?.trim();

  if (street != null && street.isNotEmpty) {
    return (
      primary: street,
      secondary: [
        if (neighborhood != null && neighborhood.isNotEmpty) neighborhood,
        region,
      ].join(', '),
    );
  }
  if (neighborhood != null && neighborhood.isNotEmpty) {
    return (primary: neighborhood, secondary: region);
  }
  return (primary: region, secondary: '');
}

/// `3 / 8` biçiminde kat bilgisi; ikisi de yoksa null.
String? formatFloor(int? floorNo, int? totalFloors) {
  if (floorNo == null && totalFloors == null) return null;
  if (floorNo == null) return '? / $totalFloors';
  if (totalFloors == null) return '$floorNo';
  return '$floorNo / $totalFloors';
}

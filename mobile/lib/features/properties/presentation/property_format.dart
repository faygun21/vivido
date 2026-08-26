import 'package:flutter/material.dart';

String formatPrice(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String scoreBandLabel(String band) => switch (band) {
  'excellent' => 'Mükemmel',
  'good' => 'İyi',
  'fair' => 'Orta',
  _ => 'Düşük',
};

Color scoreBandColor(String band) => switch (band) {
  'excellent' => const Color(0xFF047857),
  'good' => const Color(0xFF0F766E),
  'fair' => const Color(0xFFB45309),
  _ => const Color(0xFFB91C1C),
};

String formatDistance(int metres) =>
    metres < 1000
        ? '$metres m'
        : '${(metres / 1000).toStringAsFixed(metres >= 10000 ? 0 : 1)} km';

String formatDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes dk';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '$hours sa' : '$hours sa $remaining dk';
}

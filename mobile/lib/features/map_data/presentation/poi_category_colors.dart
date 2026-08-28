import 'package:flutter/material.dart';

const poiCategoryColors = <String, Color>{
  'market': Color(0xFFE11D48),
  'pharmacy': Color(0xFF16A34A),
  'health': Color(0xFF0EA5E9),
  'school': Color(0xFFF59E0B),
  'transit': Color(0xFF6366F1),
  'food': Color(0xFFF97316),
  'park': Color(0xFF22C55E),
  'gym': Color(0xFF8B5CF6),
};

const poiFallbackColor = Color(0xFF64748B);

/// POI kategorisi → harita ikonu varlığı.
///
/// Renklerin YANINDA duruyor çünkü ikisi de aynı şeyi anlatıyor: bir
/// kategorinin haritada nasıl göründüğü. Ayrı dosyalara dağılsalardı
/// kategori eklenince biri güncellenip diğeri unutulur, POI rengi olup
/// ikonu olmayan bir tür ortaya çıkardı.
///
/// Dosyalar `web/public/*.svg`'nin kopyası; eşleme web'deki
/// `getCategoryIconPath()` ile aynı mantığı izliyor ki aynı POI iki üründe
/// aynı simgeyle görünsün.
const poiCategoryIconAssets = <String, String>{
  'market': 'assets/icons/avm.svg',
  'pharmacy': 'assets/icons/hastane.svg',
  'health': 'assets/icons/hastane.svg',
  'school': 'assets/icons/kep_kahve.svg',
  'transit': 'assets/icons/bus.svg',
  'food': 'assets/icons/cafe.svg',
  'park': 'assets/icons/park.svg',
  'gym': 'assets/icons/sport_kahve.svg',
};

Color poiCategoryColor(String code) =>
    poiCategoryColors[code] ?? poiFallbackColor;

String poiCategoryColorHex(String code) {
  final color = poiCategoryColor(code);
  return '#${color.toARGB32().toRadixString(16).substring(2)}';
}

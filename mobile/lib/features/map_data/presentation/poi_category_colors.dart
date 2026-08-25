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

Color poiCategoryColor(String code) =>
    poiCategoryColors[code] ?? poiFallbackColor;

String poiCategoryColorHex(String code) {
  final color = poiCategoryColor(code);
  return '#${color.toARGB32().toRadixString(16).substring(2)}';
}

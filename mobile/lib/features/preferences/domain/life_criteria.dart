import '../../../core/models/models.dart';

const lifeCriterionLabels = <String, String>{
  'market': 'Market / süpermarket',
  'pharmacy': 'Eczane',
  'transit': 'Toplu taşıma durağı',
  'food': 'Kafe ve restoran',
  'park': 'Park ve yeşil alan',
  'gym': 'Spor salonu',
  'school': 'İlkokul / ortaokul',
  'health': 'ASM / hastane',
};

String lifeCriterionLabel(String categoryCode) =>
    lifeCriterionLabels[categoryCode] ?? categoryCode;

/// Persona ağırlıklarını varsayılan sıraya çevirir ve varsa kullanıcının
/// kaydettiği sırayla birleştirir. Backend'e sonradan yeni bir kategori
/// eklenirse eski profillerde kaybolmaması için eksik kategoriler sona eklenir.
List<String> resolveLifeCriteriaOrder({
  required Persona persona,
  List<String> savedOrder = const [],
}) {
  final indexedWeights = persona.categoryWeights.indexed.toList();
  indexedWeights.sort((left, right) {
    final byWeight = right.$2.weight.compareTo(left.$2.weight);
    return byWeight != 0 ? byWeight : left.$1.compareTo(right.$1);
  });

  final defaults = indexedWeights
      .map((entry) => entry.$2.categoryCode)
      .toList(growable: false);
  final validCodes = defaults.toSet();
  final seen = <String>{};
  final resolved = <String>[];

  for (final code in savedOrder) {
    if (validCodes.contains(code) && seen.add(code)) resolved.add(code);
  }
  for (final code in defaults) {
    if (seen.add(code)) resolved.add(code);
  }

  return resolved;
}

int lifeCriterionImportancePercent(int index, int itemCount) {
  if (itemCount <= 0 || index < 0 || index >= itemCount) return 0;
  final total = itemCount * (itemCount + 1) / 2;
  return (((itemCount - index) / total) * 100).round();
}

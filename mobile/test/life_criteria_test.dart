import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/core/models/models.dart';
import 'package:vivido_mobile/features/preferences/domain/life_criteria.dart';

void main() {
  const persona = Persona(
    code: 'student',
    displayNameTr: 'Öğrenci',
    descriptionTr: 'Test personası',
    categoryWeights: [
      PersonaCategoryWeight(categoryCode: 'market', weight: 0.5),
      PersonaCategoryWeight(categoryCode: 'school', weight: 1),
      PersonaCategoryWeight(categoryCode: 'transit', weight: 0.8),
      PersonaCategoryWeight(categoryCode: 'park', weight: 0.5),
    ],
  );

  test('persona ağırlıkları varsayılan kriter sırasına dönüşür', () {
    expect(resolveLifeCriteriaOrder(persona: persona), [
      'school',
      'transit',
      'market',
      'park',
    ]);
  });

  test('kayıtlı sıra korunur, geçersizler atılır ve eksikler eklenir', () {
    expect(
      resolveLifeCriteriaOrder(
        persona: persona,
        savedOrder: ['park', 'unknown', 'park', 'school'],
      ),
      ['park', 'school', 'transit', 'market'],
    );
  });

  test('göreli önem sıra aşağı indikçe azalır', () {
    final values = [
      for (var index = 0; index < 4; index++)
        lifeCriterionImportancePercent(index, 4),
    ];

    expect(values, [40, 30, 20, 10]);
  });
}

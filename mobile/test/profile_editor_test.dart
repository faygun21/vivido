import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/models/models.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/auth/application/session_controller.dart';
import 'package:vivido_mobile/features/home/presentation/pages/home_page.dart';

void main() {
  testWidgets('profil ve kriter sırası birlikte kaydedilir', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    double? requestedMinBudget;
    double? requestedMaxBudget;
    Map<String, dynamic>? requestedBody;
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStore: MemoryTokenStore(),
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/profile');
        requestedBody = jsonDecode(request.body) as Map<String, dynamic>;
        requestedMinBudget =
            (requestedBody!['minMonthlyBudget'] as num).toDouble();
        requestedMaxBudget =
            (requestedBody!['maxMonthlyBudget'] as num).toDouble();
        return http.Response(
          jsonEncode({
            'id': 'profile-1',
            'firstName': requestedBody!['firstName'],
            'lastName': requestedBody!['lastName'],
            'personaCode': 'student',
            'minMonthlyBudget': requestedMinBudget,
            'maxMonthlyBudget': requestedMaxBudget,
            'categoryOrder': requestedBody!['categoryOrder'],
            'anchors': <Object>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final controller =
        SessionController(client: client, repository: VividoRepository(client))
          ..profile = const UserProfile(
            id: 'profile-1',
            firstName: 'Mert',
            lastName: 'Dulgar',
            personaCode: 'student',
            minMonthlyBudget: 15000,
            maxMonthlyBudget: 20000,
            categoryOrder: _categoryOrder,
            anchors: [],
          )
          ..personas = const [
            Persona(
              code: 'student',
              displayNameTr: 'Öğrenci',
              descriptionTr: 'Kampüse yakın yaşam',
              categoryWeights: _categoryWeights,
            ),
          ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller, initialIndex: 2)),
    );

    await tester.tap(find.text('Profil ve tercihleri düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('maximum-monthly-budget')),
      '27500',
    );
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Profil tercihleri'), findsNothing);
    expect(find.text('15000 ₺ - 27500 ₺'), findsOneWidget);
    expect(requestedMinBudget, 15000);
    expect(requestedMaxBudget, 27500);
    expect(requestedBody!['firstName'], 'Mert');
    expect(requestedBody!['lastName'], 'Dulgar');
    expect(requestedBody!['categoryOrder'], _categoryOrder);
  });
}

const _categoryOrder = <String>[
  'school',
  'transit',
  'market',
  'pharmacy',
  'food',
  'park',
  'gym',
  'health',
];

const _categoryWeights = <PersonaCategoryWeight>[
  PersonaCategoryWeight(categoryCode: 'school', weight: 1),
  PersonaCategoryWeight(categoryCode: 'transit', weight: 0.9),
  PersonaCategoryWeight(categoryCode: 'market', weight: 0.8),
  PersonaCategoryWeight(categoryCode: 'pharmacy', weight: 0.7),
  PersonaCategoryWeight(categoryCode: 'food', weight: 0.6),
  PersonaCategoryWeight(categoryCode: 'park', weight: 0.5),
  PersonaCategoryWeight(categoryCode: 'gym', weight: 0.4),
  PersonaCategoryWeight(categoryCode: 'health', weight: 0.3),
];

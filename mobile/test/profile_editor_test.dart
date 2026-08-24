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
  testWidgets('profil bütçesi kaydedilirken editör güvenli kapanır', (
    tester,
  ) async {
    double? requestedBudget;
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStore: MemoryTokenStore(),
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/profile');
        requestedBudget = (jsonDecode(request.body)['monthlyBudget'] as num)
            .toDouble();
        return http.Response(
          jsonEncode({
            'id': 'profile-1',
            'personaCode': 'student',
            'monthlyBudget': requestedBudget,
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
            personaCode: 'student',
            monthlyBudget: 20000,
            anchors: [],
          )
          ..personas = const [
            Persona(
              code: 'student',
              displayNameTr: 'Öğrenci',
              descriptionTr: 'Kampüse yakın yaşam',
            ),
          ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller, initialIndex: 2)),
    );

    await tester.tap(find.text('Persona ve bütçeyi düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Aylık kira bütçesi'),
      '27500',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Profil tercihleri'), findsNothing);
    expect(find.text('27500 ₺'), findsOneWidget);
    expect(requestedBudget, 27500);
  });
}

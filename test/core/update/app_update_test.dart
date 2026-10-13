import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mon_premye_app/core/config/app_version.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/core/session/session_store.dart';
import 'package:mon_premye_app/core/update/app_update.dart';
import 'package:mon_premye_app/core/update/update_gate.dart';

void main() {
  tearDown(() => AppUpdate.instance.reset());

  test('appVersion/appBuild menm ak pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.trim(), 'version: $appVersion+$appBuild');
  });

  test('chak apèl voye x-app-build; yon 426 bloke app la', () async {
    final seen = <String?>[];
    final client = ApiClient(
      client: MockClient((req) async {
        seen.add(req.headers['x-app-build']);
        return http.Response(
          jsonEncode({
            'ok': false,
            'code': 'app_outdated',
            'message': 'Vèsyon app ou a twò ansyen.',
            'latestVersion': '9.0.0',
            'minBuild': 99,
            'downloadUrl': 'https://voupvapcash.com/download/voupvapcash.apk',
          }),
          426,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      session: SessionStore.instance,
    );

    await expectLater(client.get('/api/wallets/me'), throwsA(isA<ApiException>()));
    expect(seen.single, '$appBuild');
    expect(AppUpdate.instance.required.value?.latestVersion, '9.0.0');
  });

  testWidgets('ekran "Mete ajou" ranplase tout app la, san fason pou fèmen l', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UpdateGate(child: Text('APP A'))));
    expect(find.text('APP A'), findsOneWidget);

    AppUpdate.instance.block(const UpdateInfo(
      latestVersion: '9.0.0',
      minBuild: 99,
      downloadUrl: 'https://voupvapcash.com/download/voupvapcash.apk',
    ));
    await tester.pump();

    expect(find.text('APP A'), findsNothing);
    expect(find.text('Nouvo vèsyon obligatwa'), findsOneWidget);
    expect(find.text('Telechaje nouvo vèsyon an'), findsOneWidget);
    expect(find.textContaining('9.0.0'), findsOneWidget);
  });
}

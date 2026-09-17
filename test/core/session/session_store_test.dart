import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/session/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('limit inaktivite', () {
    test('jeton an pa valab ankò lè limit lan pase', () async {
      var clock = 1000;
      final store = SessionStore.forTests(clock: () => clock);

      await store.save('jeton', idleTimeoutMs: 5000);
      expect(store.token, 'jeton');

      clock += 4999;
      expect(store.token, 'jeton', reason: 'yon milisgond anvan limit lan');

      clock += 1;
      expect(store.isIdle, isTrue);
      expect(store.token, isNull);
      expect(store.hasSession, isFalse);
    });

    test('yon siy navigasyon repouse kontè a', () async {
      var clock = 1000;
      final store = SessionStore.forTests(clock: () => clock);

      await store.save('jeton', idleTimeoutMs: 5000);

      clock += 4000;
      store.touch();

      clock += 4000;
      expect(store.token, 'jeton', reason: '8 s an tou, men 4 s depi touche a');
      expect(store.idleRemaining, const Duration(milliseconds: 1000));
    });

    test('yon touche pa resisite yon sesyon ki deja tonbe', () async {
      var clock = 1000;
      final store = SessionStore.forTests(clock: () => clock);

      await store.save('jeton', idleTimeoutMs: 5000);
      clock += 6000;

      store.touch();

      expect(store.token, isNull, reason: 'san sa yon dènye dwèt ta louvri l');
    });

    test('limit pa defo se 5 minit', () async {
      final store = SessionStore.forTests(clock: () => 0);
      await store.save('jeton');

      expect(store.idleTimeout, const Duration(minutes: 5));
    });

    test('serveur a ka enpoze yon lòt limit', () async {
      final store = SessionStore.forTests(clock: () => 0);
      await store.save('jeton', idleTimeoutMs: 10 * 60 * 1000);

      expect(store.idleTimeout, const Duration(minutes: 10));
    });
  });

  group('demaraj', () {
    test('yon sesyon ki te rete san bouje pa retounen apre redemaraj', () async {
      SharedPreferences.setMockInitialValues({
        'voupvapcash.session.token': 'jeton',
        'voupvapcash.session.idleTimeoutMs': 5000,
        'voupvapcash.session.lastSeenAt': 1000,
      });

      final store = SessionStore.forTests(clock: () => 1000 + 6000);
      await store.load();

      expect(store.hasSession, isFalse);
      expect(store.consumeTimeoutNotice(), isTrue, reason: 'nou di poukisa');
      expect(store.consumeTimeoutNotice(), isFalse, reason: 'yon sèl fwa');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('voupvapcash.session.token'), isNull,
          reason: 'jeton an efase sou aparèy la tou');
    });

    test('yon sesyon fre survit yon redemaraj', () async {
      SharedPreferences.setMockInitialValues({
        'voupvapcash.session.token': 'jeton',
        'voupvapcash.session.idleTimeoutMs': 5000,
        'voupvapcash.session.lastSeenAt': 1000,
      });

      final store = SessionStore.forTests(clock: () => 1000 + 1000);
      await store.load();

      expect(store.token, 'jeton');
      expect(store.consumeTimeoutNotice(), isFalse);
    });

    test('yon jeton ki soti nan yon ansyen vèsyon jwenn yon limit', () async {
      // Vèsyon anvan limit lan pa t ekri `lastSeenAt`.
      SharedPreferences.setMockInitialValues({
        'voupvapcash.session.token': 'jeton',
      });

      var clock = 1000;
      final store = SessionStore.forTests(clock: () => clock);
      await store.load();

      expect(store.token, 'jeton', reason: 'nou pa dekonekte l pou granmesi');

      clock += SessionStore.defaultIdleTimeout.inMilliseconds;
      expect(store.token, isNull, reason: 'men li konte apati de demaraj la');
    });

    test('dat ekspirasyon serveur a konte tou', () async {
      SharedPreferences.setMockInitialValues({
        'voupvapcash.session.token': 'jeton',
        'voupvapcash.session.expiresAt': 5000,
        'voupvapcash.session.lastSeenAt': 4900,
      });

      final store = SessionStore.forTests(clock: () => 5001);
      await store.load();

      expect(store.hasSession, isFalse);
    });
  });
}

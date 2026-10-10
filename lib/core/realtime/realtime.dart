import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../network/api_base.dart';
import '../network/api_client.dart';
import 'realtime_transport.dart';

/// Yon chanjman sou serveur a: "kisa ki chanje", pa done yo.
class RealtimeEvent {
  const RealtimeEvent(this.topics, this.at);

  final Set<String> topics;
  final DateTime at;
}

/// Kanal tan reyèl (Server-Sent Events) ant app la ak serveur a.
///
/// Ekran yo pa mande serveur a chak X segonn ankò: lè yon bagay chanje (yon
/// tranzaksyon, yon konfimasyon Bazik, yon rechaj), serveur a voye yon siyal,
/// epi ekran ki konsène yo rechaje nan mwens pase yon segonn.
///
/// Koneksyon an louvri lè premye ekran ki bezwen l parèt ([retain]), li fèmen
/// lè dènye a disparèt ([release]). Si li koupe, li rekonekte poukont li.
class Realtime {
  Realtime._();

  static final Realtime instance = Realtime._();

  final _events = StreamController<RealtimeEvent>.broadcast();

  /// `true` lè kouran an louvri (ba anlè a montre "An dirèk").
  final ValueNotifier<bool> connected = ValueNotifier(false);

  /// Fèmen pa defo: `main()` aktive l. Tès widget yo pa louvri okenn koneksyon.
  bool _enabled = false;
  int _users = 0;
  RealtimeConnection? _connection;
  Timer? _retry;
  int _attempt = 0;

  Stream<RealtimeEvent> get events => _events.stream;

  void enable() => _enabled = true;

  void retain() {
    _users += 1;
    if (_users == 1) _connect();
  }

  void release() {
    _users = (_users - 1).clamp(0, 1 << 30);
    if (_users == 0) _close();
  }

  /// Rele [onChange] lè youn nan [topics] yo chanje. Plizyè siyal pre youn
  /// lòt = yon sèl rechajman ([debounce]).
  StreamSubscription<RealtimeEvent> listen(
    Set<String> topics,
    VoidCallback onChange, {
    Duration debounce = const Duration(milliseconds: 500),
  }) {
    Timer? timer;
    return events.where((e) => e.topics.any(topics.contains)).listen((_) {
      timer?.cancel();
      timer = Timer(debounce, onChange);
    }, onDone: () => timer?.cancel());
  }

  Future<void> _connect() async {
    if (!_enabled || _users == 0 || _connection != null) return;
    _retry?.cancel();
    try {
      final json = await ApiClient.instance.post('/api/events/ticket');
      if (_users == 0) return;
      final url = ApiBase.uri('/api/events', query: {'ticket': json['ticket']});
      _connection = openEventStream(
        url,
        onOpen: () {
          _attempt = 0;
          connected.value = true;
        },
        onEvent: _onEvent,
        onClosed: () {
          _connection = null;
          connected.value = false;
          _scheduleRetry();
        },
      );
    } catch (_) {
      _connection = null;
      connected.value = false;
      _scheduleRetry();
    }
  }

  /// Pou tès yo: simile yon evènman ki soti nan serveur a.
  @visibleForTesting
  void debugReceive(String name, String data) => _onEvent(name, data);

  void _onEvent(String name, String data) {
    if (name == 'bye') {
      // Sesyon an fini: pa rekonekte jiskaske yon ekran mande l ankò.
      _close();
      return;
    }
    if (name != 'change') return;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final topics = ((json['topics'] as List?) ?? const []).map((t) => '$t').toSet();
      _events.add(RealtimeEvent(topics, DateTime.now()));
    } catch (_) {}
  }

  void _scheduleRetry() {
    if (!_enabled || _users == 0) return;
    _retry?.cancel();
    _attempt += 1;
    final seconds = [1, 2, 5, 10, 20, 30][(_attempt - 1).clamp(0, 5)];
    _retry = Timer(Duration(seconds: seconds), _connect);
  }

  void _close() {
    _retry?.cancel();
    _connection?.close();
    _connection = null;
    connected.value = false;
  }
}

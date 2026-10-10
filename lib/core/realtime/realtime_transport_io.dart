import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'realtime_transport.dart';

/// Mobil/desktop: nou li kouran HTTP la nou menm epi nou dekoupe evènman yo.
RealtimeConnection openEventStream(
  Uri url, {
  required void Function() onOpen,
  required RealtimeEventHandler onEvent,
  required void Function() onClosed,
}) {
  final connection = _IoConnection();
  connection.start(url, onOpen, onEvent, onClosed);
  return connection;
}

class _IoConnection implements RealtimeConnection {
  final _client = http.Client();
  StreamSubscription<String>? _sub;
  bool _closed = false;

  Future<void> start(
    Uri url,
    void Function() onOpen,
    RealtimeEventHandler onEvent,
    void Function() onClosed,
  ) async {
    void finish() {
      if (_closed) return;
      _closed = true;
      _client.close();
      onClosed();
    }

    try {
      final request = http.Request('GET', url)..headers['Accept'] = 'text/event-stream';
      final response = await _client.send(request);
      if (response.statusCode != 200) return finish();
      onOpen();
      var name = 'message';
      final data = StringBuffer();
      _sub = response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.isEmpty) {
            if (data.isNotEmpty || name != 'message') onEvent(name, data.toString());
            name = 'message';
            data.clear();
          } else if (line.startsWith('event:')) {
            name = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            if (data.isNotEmpty) data.write('\n');
            data.write(line.substring(5).trim());
          }
        },
        onDone: finish,
        onError: (_) => finish(),
        cancelOnError: true,
      );
    } catch (_) {
      finish();
    }
  }

  @override
  void close() {
    _closed = true;
    _sub?.cancel();
    _client.close();
  }
}

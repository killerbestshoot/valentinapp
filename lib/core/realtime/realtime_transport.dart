import 'realtime_transport_io.dart'
    if (dart.library.js_interop) 'realtime_transport_web.dart' as impl;

/// Yon koneksyon evènman ouvè.
abstract class RealtimeConnection {
  void close();
}

typedef RealtimeEventHandler = void Function(String name, String data);

/// Louvri kouran Server-Sent Events la ([url] gen tikè a ladan l).
RealtimeConnection openEventStream(
  Uri url, {
  required void Function() onOpen,
  required RealtimeEventHandler onEvent,
  required void Function() onClosed,
}) =>
    impl.openEventStream(url, onOpen: onOpen, onEvent: onEvent, onClosed: onClosed);

import 'dart:js_interop';

import 'realtime_transport.dart';

@JS('EventSource')
extension type _EventSource._(JSObject _) implements JSObject {
  external factory _EventSource(String url);
  external int get readyState;
  external void close();
  external void addEventListener(String type, JSFunction listener);
}

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

/// Navigatè: `EventSource` natif la (li rekonekte poukont li si rezo a koupe
/// yon ti moman; si li fèmen nèt, nou mande yon nouvo tikè).
RealtimeConnection openEventStream(
  Uri url, {
  required void Function() onOpen,
  required RealtimeEventHandler onEvent,
  required void Function() onClosed,
}) {
  final source = _EventSource(url.toString());
  var closed = false;

  void listen(String type) {
    source.addEventListener(
      type,
      ((JSObject e) {
        final data = _MessageEvent._(e).data;
        onEvent(type, data is JSString ? data.toDart : '');
      }).toJS,
    );
  }

  source.addEventListener('open', ((JSObject _) => onOpen()).toJS);
  listen('hello');
  listen('change');
  listen('bye');
  source.addEventListener(
    'error',
    ((JSObject _) {
      // 2 = CLOSED: tikè a pa bon ankò (sèvè a refize rekoneksyon an).
      if (!closed && source.readyState == 2) {
        closed = true;
        onClosed();
      }
    }).toJS,
  );

  return _WebConnection(() {
    closed = true;
    source.close();
  });
}

class _WebConnection implements RealtimeConnection {
  _WebConnection(this._close);

  final void Function() _close;

  @override
  void close() => _close();
}

import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

/// A server push on the `/rt` namespace.
class RealtimeEvent {
  const RealtimeEvent(this.name, this.data);

  /// `trip.offer`, `trip.updated`, `trip.location`, `trip.message`, `trip.no_drivers`.
  final String name;
  final Map<String, dynamic> data;
}

/// Socket.IO connection to the API (`/rt`), authenticated with the session token.
///
/// Rooms are joined server-side from the token (`user:<id>`, `driver:<id>`); trip rooms are joined with [joinTrip]
/// and re-joined after every reconnect. Driver GPS goes up with [sendLocation] (no HTTP call per fix).
class RealtimeClient {
  RealtimeClient(this._api);

  final ApiClient _api;
  io.Socket? _socket;
  String? _token;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  final Set<String> _trips = {};

  Stream<RealtimeEvent> get events => _events.stream;

  /// true on (re)connect, false on disconnect.
  Stream<bool> get connection => _connected.stream;
  bool get isConnected => _socket?.connected ?? false;

  /// Events named [name].
  Stream<Map<String, dynamic>> on(String name) => events.where((e) => e.name == name).map((e) => e.data);

  /// Connects (or reconnects with a new token). No-op when signed out.
  void connect() {
    final token = _api.session.token;
    if (token == null || token.isEmpty) return;
    if (_socket != null && token == _token) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }
    disconnect();
    _token = token;
    final socket = io.io(
      '${_api.origin}/rt',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .build(),
    );
    socket.onConnect((_) {
      _connected.add(true);
      for (final id in _trips) {
        socket.emitWithAck('trip:join', {'tripId': id}, ack: (_) {});
      }
    });
    socket.onDisconnect((_) => _connected.add(false));
    socket.onAny((event, data) {
      if (data is Map) _events.add(RealtimeEvent(event, Map<String, dynamic>.from(data)));
    });
    socket.connect();
    _socket = socket;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _token = null;
  }

  /// Joins a trip's room (live location, chat, status for both sides). True when the server accepted.
  Future<bool> joinTrip(String tripId) {
    _trips.add(tripId);
    final socket = _socket;
    if (socket == null || !socket.connected) return Future.value(false);
    final done = Completer<bool>();
    socket.emitWithAck('trip:join', {'tripId': tripId}, ack: (dynamic res) {
      if (!done.isCompleted) done.complete(res is Map && res['ok'] == true);
    });
    return done.future.timeout(const Duration(seconds: 5), onTimeout: () => false);
  }

  void leaveTrip(String tripId) => _trips.remove(tripId);

  /// Driver GPS fix: updates the dispatch index and streams to the passenger of the active trip.
  void sendLocation(double lat, double lng) => _socket?.emit('driver:location', {'lat': lat, 'lng': lng});

  void dispose() {
    disconnect();
    _events.close();
    _connected.close();
  }
}

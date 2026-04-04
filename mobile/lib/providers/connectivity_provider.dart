import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

class ConnectivityNotifier extends StateNotifier<bool> {
  final ConnectivityService _svc;

  ConnectivityNotifier(this._svc) : super(_svc.isOnline) {
    _svc.onConnectivityChanged.listen((online) {
      state = online;
    });
    _svc.start();
  }

  @override
  void dispose() {
    _svc.stop();
    super.dispose();
  }

  bool get isOnline => state;
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>(
        (ref) => ConnectivityNotifier(ConnectivityService()));

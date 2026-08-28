import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract interface class ConnectivityMonitor {
  Future<List<ConnectivityResult>> check();

  Stream<List<ConnectivityResult>> get changes;
}

class PlatformConnectivityMonitor implements ConnectivityMonitor {
  PlatformConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> check() => _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}

class NetworkStatusController extends ChangeNotifier {
  NetworkStatusController(this._monitor);

  final ConnectivityMonitor _monitor;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool isOffline = false;
  bool initialized = false;

  Future<void> initialize() async {
    _subscription ??= _monitor.changes.listen(_update);
    _update(await _monitor.check());
  }

  void _update(List<ConnectivityResult> results) {
    final nextOffline =
        results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none);
    if (initialized && isOffline == nextOffline) return;
    isOffline = nextOffline;
    initialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

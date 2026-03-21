import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;
  bool _started = false;

  bool get isOffline => _isOffline;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final results = await _connectivity.checkConnectivity();
    _setOffline(_isOfflineFrom(results));
    _subscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _setOffline(_isOfflineFrom(results));
    });
  }

  void _setOffline(bool value) {
    if (_isOffline == value) return;
    _isOffline = value;
    notifyListeners();
  }

  bool _isOfflineFrom(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    if (results.contains(ConnectivityResult.none)) return true;
    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}

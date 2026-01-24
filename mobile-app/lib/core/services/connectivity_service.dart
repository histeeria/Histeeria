import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connectivity service
///
/// Monitors network connectivity status and provides
/// real-time updates about connection state.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  bool _isConnected = true;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial status
    try {
      // connectivity_plus v5.0.2 returns ConnectivityResult (single value)
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      _connectionController.add(_isConnected);
    } catch (e) {
      // Assume connected if check fails
      _isConnected = true;
      _connectionController.add(_isConnected);
    }

    // Listen for connectivity changes
    // v5.0.2 uses ConnectivityResult (single value)
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final isConnected = result != ConnectivityResult.none;

      if (_isConnected != isConnected) {
        _isConnected = isConnected;
        _connectionController.add(_isConnected);
      }
    });
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      // connectivity_plus v5.0.2 returns ConnectivityResult (single value)
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      return _isConnected;
    } catch (e) {
      // Assume connected if check fails (let actual requests handle errors)
      return true;
    }
  }

  /// Get current connection status
  bool get isConnected => _isConnected;

  /// Dispose resources
  void dispose() {
    _connectionController.close();
  }
}

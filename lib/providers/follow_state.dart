import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/interfaces/follow_repository.dart';

class FollowState extends ChangeNotifier {
  final FollowRepository _repo;

  final Set<String> _outbound = <String>{}; // you follow them
  final Set<String> _inbound = <String>{};  // they follow you

  bool _initialized = false;

  FollowState(this._repo);

  bool get initialized => _initialized;

  bool isConnected(String userId) => _outbound.contains(userId);
  bool theyConnectToYou(String userId) => _inbound.contains(userId);

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final status = await _repo.getConnectionsStatus();
      _outbound
        ..clear()
        ..addAll(status.outbound);
      _inbound
        ..clear()
        ..addAll(status.inbound);
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _initialized = true; // avoid retry loops in UI
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      final status = await _repo.getConnectionsStatus();
      _outbound
        ..clear()
        ..addAll(status.outbound);
      _inbound
        ..clear()
        ..addAll(status.inbound);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> connect(String targetUserId) async {
    if (isConnected(targetUserId)) return;
    _outbound.add(targetUserId);
    notifyListeners();
    try {
      await _repo.followUser(targetUserId);
    } catch (e) {
      _outbound.remove(targetUserId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect(String targetUserId) async {
    if (!isConnected(targetUserId)) return;
    _outbound.remove(targetUserId);
    notifyListeners();
    try {
      await _repo.unfollowUser(targetUserId);
    } catch (e) {
      _outbound.add(targetUserId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggle(String targetUserId) async {
    if (isConnected(targetUserId)) {
      await disconnect(targetUserId);
    } else {
      await connect(targetUserId);
    }
  }
}

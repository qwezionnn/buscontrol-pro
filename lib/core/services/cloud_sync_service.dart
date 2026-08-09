import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../database/database_helper.dart';
import 'auth_service.dart';

enum CloudSyncState {
  idle,
  syncing,
  synced,
  offline,
  error,
}

class CloudSyncService extends ChangeNotifier {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();

  final DatabaseHelper _database = DatabaseHelper.instance;

  CloudSyncState _state = CloudSyncState.idle;
  DateTime? _lastSyncedAt;
  String? _lastError;
  Timer? _timer;
  int _revision = 0;

  CloudSyncState get state => _state;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  int get revision => _revision;
  bool get isSyncing => _state == CloudSyncState.syncing;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> start() async {
    _timer?.cancel();
    await syncNow();
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => syncNow(silent: true),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _state = CloudSyncState.idle;
  }

  Future<void> syncNow({bool silent = false}) async {
    final user = AuthService.instance.currentUser;
    if (user == null || isSyncing) return;

    _setState(CloudSyncState.syncing, notify: !silent);

    try {
      final localSnapshot = await _database.exportCloudSnapshot();
      final localHash = _snapshotHash(localSnapshot);
      final lastHash =
          await _database.getSetting('cloud_sync_last_hash');

      final cloudRow = await _client
          .from('app_snapshots')
          .select('payload, payload_hash, updated_at')
          .eq('user_id', user.id)
          .maybeSingle();

      if (cloudRow == null) {
        await _upload(
          userId: user.id,
          snapshot: localSnapshot,
          payloadHash: localHash,
        );
        await _saveSyncMetadata(localHash);
      } else {
        final cloudHash = cloudRow['payload_hash']?.toString() ?? '';

        // Первое подключение нового устройства: если в облаке уже есть снимок,
        // облако является источником истины. Раньше lastHash == null считался
        // "локальным изменением", из-за чего пустая/новая база второго телефона
        // могла перезаписать существующую облачную копию.
        if (lastHash == null) {
          final payload = cloudRow['payload'];
          if (payload is Map) {
            await _database.importCloudSnapshot(
              Map<String, dynamic>.from(payload),
            );
            await _saveSyncMetadata(cloudHash);
            _revision++;
          }
        } else {
          final localChanged = localHash != lastHash;
          final cloudChanged = cloudHash != lastHash;

          if (!localChanged && cloudChanged) {
            final payload = cloudRow['payload'];
            if (payload is Map) {
              await _database.importCloudSnapshot(
                Map<String, dynamic>.from(payload),
              );
              await _saveSyncMetadata(cloudHash);
              _revision++;
            }
          } else if (localChanged) {
          // При конфликте офлайн-изменения текущего устройства имеют приоритет.
          await _upload(
            userId: user.id,
            snapshot: localSnapshot,
            payloadHash: localHash,
          );
            await _saveSyncMetadata(localHash);
          } else {
            await _database.setSetting(
              'cloud_sync_last_at',
              DateTime.now().toUtc().toIso8601String(),
            );
          }
        }
      }

      _lastSyncedAt = DateTime.now();
      _lastError = null;
      _setState(CloudSyncState.synced);
    } on AuthException catch (error) {
      _lastError = error.message;
      _setState(CloudSyncState.error);
    } on PostgrestException catch (error) {
      _lastError = error.message;
      _setState(CloudSyncState.error);
    } catch (error) {
      _lastError = error.toString();
      _setState(CloudSyncState.offline);
    }
  }

  Future<void> replaceCloudWithLocal() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    _setState(CloudSyncState.syncing);
    try {
      final snapshot = await _database.exportCloudSnapshot();
      final hash = _snapshotHash(snapshot);
      await _upload(
        userId: user.id,
        snapshot: snapshot,
        payloadHash: hash,
      );
      await _saveSyncMetadata(hash);
      _lastSyncedAt = DateTime.now();
      _lastError = null;
      _setState(CloudSyncState.synced);
    } catch (error) {
      _lastError = error.toString();
      _setState(CloudSyncState.error);
      rethrow;
    }
  }

  Future<void> replaceLocalWithCloud() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    _setState(CloudSyncState.syncing);
    try {
      final cloudRow = await _client
          .from('app_snapshots')
          .select('payload, payload_hash')
          .eq('user_id', user.id)
          .maybeSingle();

      if (cloudRow == null) {
        throw StateError('В облаке пока нет резервной копии.');
      }

      final payload = cloudRow['payload'];
      if (payload is! Map) {
        throw const FormatException('Облачные данные повреждены.');
      }

      await _database.importCloudSnapshot(
        Map<String, dynamic>.from(payload),
      );
      final hash = cloudRow['payload_hash']?.toString() ??
          _snapshotHash(Map<String, dynamic>.from(payload));
      await _saveSyncMetadata(hash);
      _revision++;
      _lastSyncedAt = DateTime.now();
      _lastError = null;
      _setState(CloudSyncState.synced);
    } catch (error) {
      _lastError = error.toString();
      _setState(CloudSyncState.error);
      rethrow;
    }
  }

  Future<void> _upload({
    required String userId,
    required Map<String, dynamic> snapshot,
    required String payloadHash,
  }) async {
    await _client.from('app_snapshots').upsert({
      'user_id': userId,
      'payload': snapshot,
      'payload_hash': payloadHash,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _saveSyncMetadata(String hash) async {
    await _database.setSettings({
      'cloud_sync_last_hash': hash,
      'cloud_sync_last_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  String _snapshotHash(Map<String, dynamic> snapshot) {
    return _stableHash(jsonEncode(snapshot['tables']));
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  void _setState(CloudSyncState value, {bool notify = true}) {
    _state = value;
    if (notify) notifyListeners();
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_attendance_service.dart';

abstract interface class OfflineUploader {
  Future<String> upload(Map<String, dynamic> payload);
}

class SupabaseOfflineUploader implements OfflineUploader {
  SupabaseOfflineUploader(this.client);
  final SupabaseClient client;

  @override
  Future<String> upload(Map<String, dynamic> payload) async {
    final result = await client
        .rpc('sync_offline_attendance', params: {'p_payload': payload})
        .timeout(const Duration(seconds: 25));
    if (result is! Map || result['session_id'] != payload['session']['id']) {
      throw StateError('服务端未确认完整同步，请重试。');
    }
    return result['session_id'] as String;
  }
}

/// No timers, network listeners, app lifecycle hooks or automatic retries.
class OfflineSyncService {
  OfflineSyncService(this.local, this.uploader);
  final OfflineAttendanceService local;
  final OfflineUploader uploader;
  final Set<String> _inFlight = {};

  Future<void> sync(String id, {required String ownerId}) async {
    if (!_inFlight.add(id)) throw StateError('该任务正在同步，请勿重复点击。');
    var prepared = false;
    try {
      final s = await local.getSession(id);
      if (s.isSynced) return;
      final payload = await local.prepareUpload(id, ownerId);
      prepared = true;
      final uploadedId = await uploader.upload(payload);
      if (uploadedId != id) throw StateError('服务端返回的任务不一致。');
      await local.finishUpload(id);
    } on Object catch (_) {
      if (prepared) {
        await local.finishUpload(id, error: '同步未确认成功，本机记录已保留。请联网后手动重试。');
      }
      rethrow;
    } finally {
      _inFlight.remove(id);
    }
  }
}

import 'attendance_session.dart';

class OfflineSession {
  const OfflineSession({
    required this.session,
    required this.ownerId,
    required this.syncState,
    required this.locked,
    this.closedAt,
    this.lastError,
  });

  final AttendanceSession session;
  final String ownerId;
  final String syncState;
  final bool locked;
  final DateTime? closedAt;
  final String? lastError;

  bool get isClosed => session.status == 'closed';
  bool get isSynced => syncState == 'synced';
  bool get canEdit => !locked && !isSynced;
  bool get canSync => isClosed && !isSynced;

  factory OfflineSession.fromRow(Map<String, Object?> row) => OfflineSession(
    session: AttendanceSession.fromJson(Map<String, dynamic>.from(row)),
    ownerId: row['owner_id'] as String,
    syncState: row['sync_state'] as String,
    locked: row['locked'] == 1,
    closedAt: row['closed_at'] == null
        ? null
        : DateTime.parse(row['closed_at'] as String).toLocal(),
    lastError: row['last_error'] as String?,
  );
}

import 'package:sqflite/sqflite.dart';

/// A separate app-private database. Opening it never reads/writes the cloud.
class OfflineStore {
  OfflineStore({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? path;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final location =
        path ?? '${await getDatabasesPath()}/sports_attendance_offline_v1.db';
    return _factory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE offline_settings (
              key TEXT PRIMARY KEY, value TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE offline_roster (
              scope TEXT PRIMARY KEY, owner_id TEXT NOT NULL,
              saved_at TEXT NOT NULL, groups_json TEXT NOT NULL,
              members_json TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE offline_sessions (
              id TEXT PRIMARY KEY, scope TEXT NOT NULL, owner_id TEXT NOT NULL,
              title TEXT NOT NULL, required_time TEXT NOT NULL,
              end_time TEXT NOT NULL, status TEXT NOT NULL
                CHECK(status IN ('active', 'closed')),
              created_at TEXT NOT NULL, closed_at TEXT,
              sync_state TEXT NOT NULL DEFAULT 'local',
              locked INTEGER NOT NULL DEFAULT 0, last_error TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE offline_session_members (
              id TEXT PRIMARY KEY, session_id TEXT NOT NULL
                REFERENCES offline_sessions(id) ON DELETE CASCADE,
              member_id TEXT NOT NULL, member_json TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending', 'normal', 'late', 'absent')),
              checkin_time TEXT, late_minutes INTEGER NOT NULL DEFAULT 0,
              remark TEXT, UNIQUE(session_id, member_id)
            )
          ''');
          await db.execute(
            'CREATE INDEX offline_sessions_scope ON offline_sessions(scope)',
          );
        },
      ),
    );
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}

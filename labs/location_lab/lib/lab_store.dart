import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// SQLite persistence for lab sessions, samples and events.
class LabStore {
  LabStore(this._db);

  final Database _db;

  static Future<LabStore> open(String path) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE session (
            id TEXT PRIMARY KEY,
            device_id TEXT NOT NULL,
            device_model TEXT NOT NULL,
            os_version TEXT NOT NULL,
            app_version TEXT NOT NULL,
            started_at_utc_ms INTEGER NOT NULL,
            ended_at_utc_ms INTEGER,
            requested_interval_s INTEGER NOT NULL,
            requested_accuracy TEXT NOT NULL,
            ntp_offset_ms INTEGER,
            notes TEXT NOT NULL DEFAULT ''
          )''');
        await db.execute('''
          CREATE TABLE sample (
            session_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            device_time_utc_ms INTEGER NOT NULL,
            fix_time_utc_ms INTEGER NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            accuracy_m REAL NOT NULL,
            altitude_m REAL NOT NULL,
            speed_mps REAL NOT NULL,
            heading_deg REAL NOT NULL,
            is_mocked INTEGER NOT NULL,
            lifecycle TEXT NOT NULL,
            battery_pct INTEGER NOT NULL,
            battery_state TEXT NOT NULL,
            PRIMARY KEY (session_id, seq)
          )''');
        await db.execute('''
          CREATE TABLE event (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            time_utc_ms INTEGER NOT NULL,
            kind TEXT NOT NULL,
            detail TEXT NOT NULL
          )''');
        await db.execute('CREATE INDEX event_session ON event(session_id, time_utc_ms)');
      },
    );
    return LabStore(db);
  }

  Future<void> close() => _db.close();

  Future<void> insertSession(LabSession s) =>
      _db.insert('session', s.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> endSession(String id, int endedAtUtcMs) => _db.update(
        'session',
        {'ended_at_utc_ms': endedAtUtcMs},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<LabSession?> openSession() async {
    final rows = await _db.query(
      'session',
      where: 'ended_at_utc_ms IS NULL',
      orderBy: 'started_at_utc_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LabSession.fromJson(rows.first);
  }

  Future<List<LabSession>> sessions() async {
    final rows = await _db.query('session', orderBy: 'started_at_utc_ms DESC');
    return rows.map(LabSession.fromJson).toList();
  }

  Future<void> insertSample(Sample s) => _db.insert('sample', s.toRow());

  Future<void> insertEvent(LabEvent e) => _db.insert('event', e.toRow());

  Future<List<Sample>> samples(String sessionId) async {
    final rows = await _db.query(
      'sample',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'seq ASC',
    );
    return rows.map(Sample.fromRow).toList();
  }

  Future<List<LabEvent>> events(String sessionId) async {
    final rows = await _db.query(
      'event',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'time_utc_ms ASC, id ASC',
    );
    return rows.map(LabEvent.fromRow).toList();
  }

  Future<int> sampleCount(String sessionId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM sample WHERE session_id = ?',
      [sessionId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<void> deleteSession(String id) => _db.transaction((txn) async {
        await txn.delete('sample', where: 'session_id = ?', whereArgs: [id]);
        await txn.delete('event', where: 'session_id = ?', whereArgs: [id]);
        await txn.delete('session', where: 'id = ?', whereArgs: [id]);
      });
}

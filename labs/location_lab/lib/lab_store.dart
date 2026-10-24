import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Persistence for lab sessions, samples and events.
abstract class LabStore {
  /// Opens the SQLite-backed store at [path].
  static Future<LabStore> open(String path) => SqliteLabStore.open(path);

  Future<void> close();
  Future<void> insertSession(LabSession s);
  Future<void> endSession(String id, int endedAtUtcMs);
  Future<LabSession?> openSession();
  Future<List<LabSession>> sessions();
  Future<void> insertSample(Sample s);
  Future<void> insertEvent(LabEvent e);
  Future<List<Sample>> samples(String sessionId);
  Future<List<LabEvent>> events(String sessionId);
  Future<int> sampleCount(String sessionId);

  /// Highest stored seq plus one, or 0 when the session has no samples.
  Future<int> nextSeq(String sessionId);
  Future<void> deleteSession(String id);
}

class SqliteLabStore implements LabStore {
  SqliteLabStore(this._db);

  final Database _db;

  static Future<SqliteLabStore> open(String path) async {
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
    return SqliteLabStore(db);
  }

  @override
  Future<void> close() => _db.close();

  @override
  Future<void> insertSession(LabSession s) =>
      _db.insert('session', s.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> endSession(String id, int endedAtUtcMs) => _db.update(
        'session',
        {'ended_at_utc_ms': endedAtUtcMs},
        where: 'id = ?',
        whereArgs: [id],
      );

  @override
  Future<LabSession?> openSession() async {
    final rows = await _db.query(
      'session',
      where: 'ended_at_utc_ms IS NULL',
      orderBy: 'started_at_utc_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LabSession.fromJson(rows.first);
  }

  @override
  Future<List<LabSession>> sessions() async {
    final rows = await _db.query('session', orderBy: 'started_at_utc_ms DESC');
    return rows.map(LabSession.fromJson).toList();
  }

  @override
  Future<void> insertSample(Sample s) => _db.insert('sample', s.toRow());

  @override
  Future<void> insertEvent(LabEvent e) => _db.insert('event', e.toRow());

  @override
  Future<List<Sample>> samples(String sessionId) async {
    final rows = await _db.query(
      'sample',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'seq ASC',
    );
    return rows.map(Sample.fromRow).toList();
  }

  @override
  Future<List<LabEvent>> events(String sessionId) async {
    final rows = await _db.query(
      'event',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'time_utc_ms ASC, id ASC',
    );
    return rows.map(LabEvent.fromRow).toList();
  }

  @override
  Future<int> sampleCount(String sessionId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM sample WHERE session_id = ?',
      [sessionId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  @override
  Future<int> nextSeq(String sessionId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(seq) AS m FROM sample WHERE session_id = ?',
      [sessionId],
    );
    final max = rows.first['m'] as int?;
    return max == null ? 0 : max + 1;
  }

  @override
  Future<void> deleteSession(String id) => _db.transaction((txn) async {
        await txn.delete('sample', where: 'session_id = ?', whereArgs: [id]);
        await txn.delete('event', where: 'session_id = ?', whereArgs: [id]);
        await txn.delete('session', where: 'id = ?', whereArgs: [id]);
      });
}

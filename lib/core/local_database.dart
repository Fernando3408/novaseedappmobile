import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'novaseed_mobile.db');
    _database = await openDatabase(path, version: 2, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE observations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_uuid TEXT NOT NULL UNIQUE,
          block_id INTEGER NOT NULL,
          varity_id INTEGER NOT NULL,
          feature_name TEXT NOT NULL,
          value TEXT NOT NULL,
          captured_at TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
      await db.execute('''
        CREATE TABLE field_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_uuid TEXT NOT NULL UNIQUE,
          entity TEXT NOT NULL,
          local_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          captured_at TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE field_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_uuid TEXT NOT NULL UNIQUE,
            entity TEXT NOT NULL,
            local_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            captured_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
      }
    });
    return _database!;
  }

  Future<int> addObservation({
    required String clientUuid,
    required int blockId,
    required int varityId,
    required String featureName,
    required String value,
  }) async {
    final db = await database;
    return db.insert('observations', {
      'client_uuid': clientUuid,
      'block_id': blockId,
      'varity_id': varityId,
      'feature_name': featureName,
      'value': value,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'sync_status': 'pending',
    });
  }

  Future<int> pendingCount() async {
    final db = await database;
    final rows = await db.rawQuery("SELECT (SELECT COUNT(*) FROM observations WHERE sync_status = 'pending') + (SELECT COUNT(*) FROM field_events WHERE sync_status = 'pending') AS total");
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<Map<String, dynamic>>> pendingObservations() async {
    final db = await database;
    return db.query('observations', where: 'sync_status = ?', whereArgs: ['pending']);
  }

  Future<void> markObservation(int id, String status) async {
    final db = await database;
    await db.update('observations', {'sync_status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addFieldEvent({required String clientUuid, required String entity, required String localId, required String payload}) async {
    final db = await database;
    await db.insert('field_events', {
      'client_uuid': clientUuid,
      'entity': entity,
      'local_id': localId,
      'payload': payload,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'sync_status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> pendingFieldEvents() async {
    final db = await database;
    return db.query('field_events', where: 'sync_status = ?', whereArgs: ['pending']);
  }

  Future<void> markFieldEvent(int id, String status) async {
    final db = await database;
    await db.update('field_events', {'sync_status': status}, where: 'id = ?', whereArgs: [id]);
  }
}

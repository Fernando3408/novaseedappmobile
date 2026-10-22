import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'novaseed_mobile.db');
    _database = await openDatabase(path, version: 1, onCreate: (db, version) async {
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
    final rows = await db.rawQuery("SELECT COUNT(*) AS total FROM observations WHERE sync_status = 'pending'");
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
}

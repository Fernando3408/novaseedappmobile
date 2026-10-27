import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'novaseed_mobile.db');
    _database = await openDatabase(path, version: 3, onCreate: (db, version) async {
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
      await _createCatalogTables(db);
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
      if (oldVersion < 3) await _createCatalogTables(db);
    });
    return _database!;
  }

  Future<void> _createCatalogTables(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS features (id INTEGER PRIMARY KEY, name TEXT NOT NULL, type INTEGER, year TEXT, repeat_do INTEGER, localities_viewer INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS feature_values (id INTEGER PRIMARY KEY, feature_id INTEGER NOT NULL, name TEXT, value TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS blocks (id INTEGER PRIMARY KEY, description TEXT, lines INTEGER, year INTEGER, max_positions INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS varieties (id INTEGER PRIMARY KEY, name TEXT, code TEXT, year INTEGER, berries INTEGER, berries_objective INTEGER, status INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS block_varieties (id INTEGER PRIMARY KEY, block_id INTEGER, variety_id INTEGER, position TEXT, type TEXT)');
  }

  Future<void> replaceCatalog(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((transaction) async {
      for (final table in ['features', 'feature_values', 'blocks', 'varieties', 'block_varieties']) {
        await transaction.delete(table);
      }
      for (final item in (data['features'] as List<dynamic>? ?? const [])) {
        await transaction.insert('features', {'id': item['id'], 'name': item['name'], 'type': item['type'], 'year': item['year']?.toString(), 'repeat_do': item['repeat_do'], 'localities_viewer': item['localities_viewer']});
      }
      for (final item in (data['values'] as List<dynamic>? ?? const [])) {
        await transaction.insert('feature_values', {'id': item['id'], 'feature_id': item['feature_id'], 'name': item['name'], 'value': item['value']});
      }
      for (final item in (data['blocks'] as List<dynamic>? ?? const [])) {
        await transaction.insert('blocks', {'id': item['id'], 'description': item['description'], 'lines': item['lines'], 'year': item['year'], 'max_positions': item['limit']});
      }
      for (final item in (data['varities'] as List<dynamic>? ?? const [])) {
        await transaction.insert('varieties', {'id': item['id'], 'name': item['name'], 'code': item['code'], 'year': item['year'], 'berries': item['berries'], 'berries_objective': item['berries_objective'], 'status': item['status']});
      }
      for (final item in (data['blocksvarity'] as List<dynamic>? ?? const [])) {
        await transaction.insert('block_varieties', {'id': item['id'], 'block_id': item['block_id'], 'variety_id': item['varity_id'], 'position': item['position'], 'type': item['type']});
      }
    });
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

  Future<List<Map<String, dynamic>>> catalogFeatures() async => (await database).query('features', orderBy: 'id');

  Future<List<Map<String, dynamic>>> catalogValues() async => (await database).query('feature_values', orderBy: 'id');

  Future<List<Map<String, dynamic>>> catalogAssignments() async => (await database).query('block_varieties', orderBy: 'id');

  Future<List<Map<String, dynamic>>> catalogVarieties() async => (await database).query('varieties', orderBy: 'id');
}

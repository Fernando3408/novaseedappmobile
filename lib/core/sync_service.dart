import 'local_database.dart';
import 'mobile_api_client.dart';

class SyncService {
  SyncService({required this._client, LocalDatabase? database})
      : 
        _database = database ?? LocalDatabase.instance;

  final MobileApiClient _client;
  final LocalDatabase _database;

  Future<SyncSummary> pushPending() async {
    final rows = await _database.pendingObservations();
    if (rows.isEmpty) return const SyncSummary(accepted: 0, rejected: 0);

    final mutations = rows.map((row) => {
      'client_uuid': row['client_uuid'],
      'idempotency_key': row['client_uuid'],
      'entity': 'characteristic',
      'base_version': null,
      'captured_at': row['captured_at'],
      'payload': {
        'value': row['value'],
        'feature_id': 1,
        'varity_id': row['varity_id'],
        'year': 2026,
        'block_id': row['block_id'],
      },
    }).toList();

    final response = await _client.push(mutations);
    final results = (response.data['results'] as List<dynamic>? ?? const []);
    var accepted = 0;
    var rejected = 0;
    for (final result in results) {
      final clientUuid = result['client_uuid'];
      Map<String, dynamic>? row;
      for (final candidate in rows) {
        if (candidate['client_uuid'] == clientUuid) {
          row = candidate;
          break;
        }
      }
      if (row == null) continue;
      final status = result['status'] == 'accepted' ? 'synced' : 'rejected';
      await _database.markObservation(row['id'] as int, status);
      if (status == 'synced') accepted++;
      if (status == 'rejected') rejected++;
    }
    return SyncSummary(accepted: accepted, rejected: rejected);
  }
}

class SyncSummary {
  const SyncSummary({required this.accepted, required this.rejected});
  final int accepted;
  final int rejected;
}

import 'mobile_api_client.dart';

class BootstrapService {
  BootstrapService(this._client);

  final MobileApiClient _client;

  Future<BootstrapResult> download() async {
    final response = await _client.bootstrap();
    final data = Map<String, dynamic>.from(response.data as Map);
    return BootstrapResult(
      features: _length(data['features']),
      blocks: _length(data['blocks']),
      varieties: _length(data['varities']),
      cursor: data['cursor']?.toString(),
    );
  }

  int _length(dynamic value) => value is List ? value.length : 0;
}

class BootstrapResult {
  const BootstrapResult({required this.features, required this.blocks, required this.varieties, this.cursor});

  final int features;
  final int blocks;
  final int varieties;
  final String? cursor;
}

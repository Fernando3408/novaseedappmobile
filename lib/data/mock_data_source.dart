import 'dart:convert';

import 'package:flutter/services.dart';

class MockDataSource {
  Future<Map<String, dynamic>> load() async {
    final raw = await rootBundle.loadString('assets/fixtures/novaseed_fixture.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> features() async {
    final data = await load();
    return List<Map<String, dynamic>>.from(data['features'] as List);
  }

  Future<List<Map<String, dynamic>>> blocks() async {
    final data = await load();
    return List<Map<String, dynamic>>.from(data['blocks'] as List);
  }
}

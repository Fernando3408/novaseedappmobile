import 'package:flutter/services.dart';
import 'dart:convert';

import '../core/local_database.dart';

class FixtureSeeder {
  Future<void> seed() async {
    final raw = await rootBundle.loadString('assets/fixtures/novaseed_fixture.json');
    await LocalDatabase.instance.replaceCatalog(jsonDecode(raw) as Map<String, dynamic>);
  }
}

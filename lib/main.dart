import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import 'core/local_database.dart';
import 'core/bootstrap_service.dart';
import 'core/mobile_api_client.dart';
import 'core/sync_service.dart';
import 'data/mock_data.dart';
import 'data/fixture_seeder.dart';

void main() => runApp(const NovaSeedApp());

class NovaSeedApp extends StatelessWidget {
  const NovaSeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF185C4A);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NovaSeed Campo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: forest),
        scaffoldBackgroundColor: const Color(0xFFF6F7F4),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userController = TextEditingController(text: 'demo@novaseed.local');
  final passwordController = TextEditingController(text: 'demo');
  bool obscurePassword = true;

  @override
  void dispose() {
    userController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.eco_outlined, size: 54, color: Color(0xFF185C4A)),
                  const SizedBox(height: 20),
                  Text('NovaSeed', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF185C4A))),
                  const SizedBox(height: 8),
                  Text('Aplicación de campo offline', style: TextStyle(fontSize: 17, color: Colors.grey.shade700)),
                  const SizedBox(height: 34),
                  TextField(controller: userController, decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 14),
                  TextField(controller: passwordController, obscureText: obscurePassword, decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                  const SizedBox(height: 22),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: _login, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('INGRESAR')))),
                  const SizedBox(height: 16),
                  const Center(child: Text('Modo demostración · datos locales', style: TextStyle(color: Colors.grey))),
                ]),
              ),
            ),
          ),
        ),
      );

  void _login() {
    if (userController.text.trim().isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa usuario y contraseña.')));
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const FieldShell()));
  }
}

class FieldShell extends StatefulWidget {
  const FieldShell({super.key});

  @override
  State<FieldShell> createState() => _FieldShellState();
}

class _FieldShellState extends State<FieldShell> {
  int _currentIndex = 0;
  bool _isOnline = false;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  static const pages = [
    _PageData('Ensayos', Icons.science_outlined),
    _PageData('Invernadero', Icons.house_siding_outlined),
    _PageData('Mapeo', Icons.grid_view_outlined),
    _PageData('Métricas', Icons.insights_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivity);
    _checkConnectivity();
    _seedFixture();
  }

  Future<void> _seedFixture() async {
    try {
      await FixtureSeeder().seed();
    } on StateError {
      // Native SQLite is unavailable in widget tests.
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _handleConnectivity(result);
  }

  void _handleConnectivity(List<ConnectivityResult> result) {
    final online = result.any((item) => item != ConnectivityResult.none);
    if (mounted) setState(() => _isOnline = online);
    if (online) _syncPendingSilently();
  }

  Future<void> _syncPendingSilently() async {
    try {
      await SyncService(client: MobileApiClient(baseUrl: 'https://novaseed.weblabs.cl')).pushPending();
    } catch (_) {
      // The queue remains local when the server is unavailable.
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = pages[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Text(
          'NOVASEED',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronización',
            onPressed: () => _showSync(context),
            icon: const Badge(
              label: Text('2'),
              child: Icon(Icons.sync_outlined),
            ),
          ),
          IconButton(tooltip: 'Cerrar sesión', onPressed: _logout, icon: const Icon(Icons.account_circle_outlined)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _OfflineBanner(isOnline: _isOnline),
            Expanded(child: _PageBody(title: page.title, icon: page.icon)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          for (final item in pages)
            NavigationDestination(icon: Icon(item.icon), label: item.title),
        ],
      ),
    );
  }

  Future<void> _showSync(BuildContext context) async {
    var pending = 0;
    try {
      pending = await LocalDatabase.instance.pendingCount();
    } on StateError {
      pending = 0;
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Centro de sincronización', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ListTile(leading: Icon(Icons.pending_actions), title: Text('$pending cambios pendientes'), subtitle: Text('Ensayos, invernadero y mapeo')),
            ListTile(leading: Icon(Icons.cloud_done_outlined), title: Text('Última descarga'), subtitle: Text('Aún no se ha descargado información real')),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _syncNow(context);
                },
                icon: Icon(Icons.sync),
                label: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('SINCRONIZAR AHORA')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNow(BuildContext context) async {
    try {
      final service = SyncService(
        client: MobileApiClient(baseUrl: 'https://novaseed.weblabs.cl'),
      );
      final summary = await service.pushPending();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${summary.accepted} sincronizado(s), ${summary.rejected} rechazado(s).')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible conectar con la API móvil. Los datos siguen guardados localmente.')),
      );
    }
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (title == 'Ensayos') return const _TrialsPage();
    if (title == 'Invernadero') return const _GreenhousePage();
    if (title == 'Mapeo') return const _MappingPage();
    if (title == 'Métricas') return const _MetricsPage();
    final isMetrics = title == 'Métricas';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          isMetrics ? 'Comparar beta sobre datos disponibles en el dispositivo.' : 'Trabajo de campo disponible sin conexión.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
        ),
        const SizedBox(height: 24),
        _ScopeCard(icon: icon, title: isMetrics ? 'Sin datos descargados' : 'Preparar jornada de trabajo', subtitle: isMetrics ? 'Descarga un ensayo para comenzar a comparar.' : 'La información asignada aparecerá aquí después de sincronizar.'),
        const SizedBox(height: 20),
        if (!isMetrics) ...[
          _ActionCard(icon: Icons.download_for_offline_outlined, title: 'Descargar datos', text: 'Ensayos, catálogo y asignaciones', onTap: () => _notReady(context)),
          const SizedBox(height: 12),
          _ActionCard(icon: Icons.add_chart_outlined, title: 'Nueva captura', text: 'Guardar primero en este dispositivo', onTap: () => _notReady(context)),
        ] else
          _CoverageCard(onTap: () => _notReady(context)),
      ],
    );
  }

  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo preparado para conectarse a la API móvil.')));
  }
}

class _TrialsPage extends StatefulWidget {
  const _TrialsPage();

  @override
  State<_TrialsPage> createState() => _TrialsPageState();
}

class _TrialsPageState extends State<_TrialsPage> {
  final _valueController = TextEditingController();
  String _feature = 'Altura de planta';
  String _plant = 'Variedad 03 · Planta 018';
  int _pending = 0;
  List<Map<String, dynamic>> _features = const [];
  List<Map<String, dynamic>> _values = const [];
  List<String> _plants = const [];
  String? _selectedOption;
  bool _booleanValue = false;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    try {
      await FixtureSeeder().seed();
      final features = await LocalDatabase.instance.catalogFeatures();
      final values = await LocalDatabase.instance.catalogValues();
      final assignments = await LocalDatabase.instance.catalogAssignments();
      final varieties = await LocalDatabase.instance.catalogVarieties();
      final varietyNames = {for (final variety in varieties) variety['id']: variety['name'] as String};
      final plants = assignments.map((assignment) => '${varietyNames[assignment['variety_id']] ?? 'Variedad'} · Planta ${assignment['position']}').toList();
      if (!mounted) return;
      setState(() {
        _features = features;
        _values = values;
        _plants = plants;
        if (plants.isNotEmpty) _plant = plants.first;
        if (features.isNotEmpty) _feature = features.first['name'] as String;
      });
    } on StateError {
      // Native SQLite is unavailable in widget tests.
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final count = await LocalDatabase.instance.pendingCount();
      if (mounted) setState(() => _pending = count);
    } on StateError {
      // Widget tests do not load the native SQLite plugin.
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Registrar ensayo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Captura primero en el dispositivo. La sincronización es posterior.', style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
        const SizedBox(height: 22),
        const _TrialContextCard(),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _downloadBootstrap,
          icon: const Icon(Icons.download_outlined),
          label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('DESCARGAR DATOS ASIGNADOS')),
        ),
        const SizedBox(height: 22),
        const Text('VARIEDAD / PLANTA', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _plants.isEmpty ? null : _plant,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.local_florist_outlined)),
          items: [for (final plant in _plants) DropdownMenuItem(value: plant, child: Text(plant))],
          onChanged: (value) => setState(() => _plant = value!),
        ),
        const SizedBox(height: 18),
        const Text('CARACTERÍSTICA DEL CATÁLOGO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _features.isEmpty ? null : _feature,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.tune)),
          items: [
            for (final feature in _features)
              DropdownMenuItem(value: feature['name'] as String, child: Text('${feature['name']} · tipo ${feature['type']}')),
          ],
          onChanged: (value) => setState(() => _feature = value!),
        ),
        const SizedBox(height: 18),
        const Text('VALOR REGISTRADO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
        const SizedBox(height: 8),
        _buildFeatureInput(),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('GUARDAR EN ESTE DISPOSITIVO')),
        ),
        const SizedBox(height: 12),
        Center(child: Text(_pending == 0 ? 'Sin capturas pendientes' : '$_pending captura(s) pendiente(s) de sincronización', style: TextStyle(color: Colors.grey.shade700))),
      ],
    );
  }

  Widget _buildFeatureInput() {
    final selected = _features.where((feature) => feature['name'] == _feature).firstOrNull;
    final type = selected?['type'];
    if (type == 1) {
      final featureId = selected?['id'];
      final options = _values.where((value) => value['feature_id'] == featureId).map((value) => value['name'] as String).toList();
      return DropdownButtonFormField<String>(
        initialValue: _selectedOption,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.list_alt_outlined), hintText: 'Seleccionar valor'),
        items: [for (final option in options) DropdownMenuItem(value: option, child: Text(option))],
        onChanged: (value) => setState(() => _selectedOption = value),
      );
    }
    if (type == 2) {
      return SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        tileColor: Colors.white,
        title: Text(_booleanValue ? 'Sí' : 'No'),
        value: _booleanValue,
        onChanged: (value) => setState(() => _booleanValue = value),
      );
    }
    return TextField(
      controller: _valueController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(hintText: 'Ingresar valor', prefixIcon: Icon(Icons.edit_outlined), suffixText: 'cm'),
    );
  }

  Future<void> _save() async {
    final value = _currentValue();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un valor antes de guardar.')));
      return;
    }
    await LocalDatabase.instance.addObservation(
      clientUuid: const Uuid().v4(),
      blockId: 14,
      varityId: _plant.startsWith('Variedad 03') ? 3 : 7,
      featureName: _feature,
      value: value,
    );
    final count = await LocalDatabase.instance.pendingCount();
    if (!mounted) return;
    setState(() => _pending = count);
    _valueController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado localmente. Queda pendiente de sincronización.')));
  }

  String _currentValue() {
    final type = _features.where((feature) => feature['name'] == _feature).firstOrNull?['type'];
    if (type == 1) return _selectedOption ?? '';
    if (type == 2) return _booleanValue ? 'si' : 'no';
    return _valueController.text.trim();
  }

  Future<void> _downloadBootstrap() async {
    try {
      final result = await BootstrapService(
        MobileApiClient(baseUrl: 'https://novaseed.weblabs.cl'),
      ).download();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Descargados ${result.blocks} ensayos, ${result.varieties} variedades y ${result.features} características.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo descargar. Revisa conexión, sesión y API móvil.')));
    }
  }
}

class _GreenhousePage extends StatelessWidget {
  const _GreenhousePage();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Text('Invernadero', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Cruces asignados y avances registrados en terreno.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 22),
          for (final cross in mockCrosses) ...[
            _CrossCard(cross: cross),
            const SizedBox(height: 12),
          ],
        ],
      );
}

class _CrossCard extends StatelessWidget {
  const _CrossCard({required this.cross});
  final MockGreenhouseCross cross;

  @override
  Widget build(BuildContext context) {
    final progress = cross.target == 0 ? 0.0 : cross.berries / cross.target;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('CRUCE · ${cross.code}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Chip(label: Text(cross.status), visualDensity: VisualDensity.compact)]),
          const SizedBox(height: 10),
          Text('Madre: ${cross.mother}'),
          Text('Padre: ${cross.father}'),
          const SizedBox(height: 14),
          Text('Bayas actuales: ${cross.berries} / objetivo: ${cross.target}'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress.clamp(0, 1)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => _saveGreenhouseEvent(context), icon: const Icon(Icons.add_chart_outlined), label: const Text('Registrar observación')),
        ]),
      ),
    );
  }

  Future<void> _saveGreenhouseEvent(BuildContext context) async {
    await LocalDatabase.instance.addFieldEvent(
      clientUuid: const Uuid().v4(),
      entity: 'greenhouse_observation',
      localId: cross.code,
      payload: jsonEncode({'berries': cross.berries, 'target': cross.target, 'observation': 'Captura de terreno'}),
    );
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Observación de invernadero guardada localmente.')));
  }
}

class _MappingPage extends StatefulWidget {
  const _MappingPage();

  @override
  State<_MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<_MappingPage> {
  String selected = '08';
  final Map<String, int> counts = {for (final type in ['Rojo', 'Rojo carne', 'Azul', 'Amarillo', 'Alargado']) type: 0};

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Text('Mapeo de cruces', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Selecciona una posición para revisar y registrar conteos.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 22),
          Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CRUCE C-014 · LÍNEA L-03', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('Posición $selected · Paso 2 de 3')]))),
          const SizedBox(height: 16),
          const Text('POSICIONES', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [for (final item in mockPositions) ChoiceChip(label: Text(item.$1), selected: selected == item.$1, onSelected: (_) => setState(() => selected = item.$1))]),
          const SizedBox(height: 20),
          const Text('CONTEO POR TIPO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [for (final type in counts.keys) _CountTile(label: type, count: counts[type]!, onDecrease: () => setState(() => counts[type] = counts[type]! > 0 ? counts[type]! - 1 : 0), onIncrease: () => setState(() => counts[type] = counts[type]! + 1))]),
          const SizedBox(height: 18),
          const TextField(decoration: InputDecoration(labelText: 'Observación', hintText: 'Agregar observación', prefixIcon: Icon(Icons.notes_outlined))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _savePosition, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('GUARDAR POSICIÓN'))),
        ],
      );

  Future<void> _savePosition() async {
    await LocalDatabase.instance.addFieldEvent(
      clientUuid: const Uuid().v4(),
      entity: 'mapping_position',
      localId: selected,
      payload: jsonEncode({'mapout_id': 1, 'position': selected, 'counts': counts}),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posición guardada localmente.')));
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.count, required this.onDecrease, required this.onIncrease});
  final String label;
  final int count;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) => Container(width: 145, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(children: [Text(label), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [IconButton(onPressed: onDecrease, icon: const Icon(Icons.remove)), Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), IconButton(onPressed: onIncrease, icon: const Icon(Icons.add))])]));
}

class _MetricsPage extends StatelessWidget {
  const _MetricsPage();

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 28), children: [
        Text('Comparar beta', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Cálculo sobre el conjunto disponible en el dispositivo.', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 22),
        Card(elevation: 0, color: const Color(0xFFDDEBE3), child: const Padding(padding: EdgeInsets.all(18), child: Row(children: [Icon(Icons.info_outline), SizedBox(width: 12), Expanded(child: Text('No hay datos descargados. La comparación no estima valores faltantes.'))]))),
        const SizedBox(height: 16),
        Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('COBERTURA LOCAL', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12), const Text('0 de 40 plantas descargadas'), const SizedBox(height: 10), const LinearProgressIndicator(value: 0), const SizedBox(height: 14), const Text('Última actualización: sin descarga', style: TextStyle(color: Colors.grey))]))),
       ]);
}

class _TrialContextCard extends StatelessWidget {
  const _TrialContextCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ENSAYO NS-2026-014 · AÑO 2026', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Bloque B2 · Repetición 1 · Localidad: Quilpué'),
            SizedBox(height: 4),
            Text('Datos de demostración · pendiente de descarga real', style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFE8EEE9),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.cloud_outlined, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(isOnline ? 'CONECTADO' : 'SIN CONEXIÓN', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
            const Spacer(),
            Text('2 pendientes', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      );
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: const Color(0xFFDDEBE3),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(backgroundColor: const Color(0xFF185C4A), foregroundColor: Colors.white, child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(subtitle)])),
          ]),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), leading: Icon(icon, color: const Color(0xFF185C4A), size: 30), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(text), trailing: const Icon(Icons.chevron_right), onTap: onTap),
      );
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cobertura local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            const Text('0 de 0 plantas descargadas'),
            const SizedBox(height: 10),
            const LinearProgressIndicator(value: 0),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.info_outline), label: const Text('Ver cobertura')),
          ]),
        ),
      );
}

class _PageData {
  const _PageData(this.title, this.icon);
  final String title;
  final IconData icon;
}

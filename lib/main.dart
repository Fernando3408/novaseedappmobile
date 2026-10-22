import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import 'core/local_database.dart';
import 'core/mobile_api_client.dart';
import 'core/sync_service.dart';

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
      home: const FieldShell(),
    );
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

  void _showSync(BuildContext context) {
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
            ListTile(leading: Icon(Icons.pending_actions), title: Text('2 cambios pendientes'), subtitle: Text('Se enviarán cuando vuelva la conexión')),
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
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (title == 'Ensayos') return const _TrialsPage();
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

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
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
        const Text('VARIEDAD / PLANTA', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _plant,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.local_florist_outlined)),
          items: const [
            DropdownMenuItem(value: 'Variedad 03 · Planta 018', child: Text('Variedad 03 · Planta 018')),
            DropdownMenuItem(value: 'Variedad 07 · Planta 024', child: Text('Variedad 07 · Planta 024')),
          ],
          onChanged: (value) => setState(() => _plant = value!),
        ),
        const SizedBox(height: 18),
        const Text('CARACTERÍSTICA DEL CATÁLOGO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _feature,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.tune)),
          items: const [
            DropdownMenuItem(value: 'Altura de planta', child: Text('Altura de planta · numérica')),
            DropdownMenuItem(value: 'Estado de hoja', child: Text('Estado de hoja · selección')),
          ],
          onChanged: (value) => setState(() => _feature = value!),
        ),
        const SizedBox(height: 18),
        const Text('VALOR REGISTRADO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .4)),
        const SizedBox(height: 8),
        TextField(
          controller: _valueController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ingresar valor', prefixIcon: Icon(Icons.edit_outlined), suffixText: 'cm'),
        ),
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

  Future<void> _save() async {
    if (_valueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un valor antes de guardar.')));
      return;
    }
    await LocalDatabase.instance.addObservation(
      clientUuid: const Uuid().v4(),
      blockId: 14,
      varityId: _plant.startsWith('Variedad 03') ? 3 : 7,
      featureName: _feature,
      value: _valueController.text.trim(),
    );
    final count = await LocalDatabase.instance.pendingCount();
    if (!mounted) return;
    setState(() => _pending = count);
    _valueController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado localmente. Queda pendiente de sincronización.')));
  }
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

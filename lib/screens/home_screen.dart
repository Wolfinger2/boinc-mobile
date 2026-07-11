import 'package:flutter/material.dart';

import '../models/boinc_host.dart';
import '../services/host_store.dart';
import 'add_host_screen.dart';
import 'host_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = HostStore();
  List<BoincHost> _hosts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hosts = await _store.load();
    if (!mounted) return;
    setState(() {
      _hosts = hosts;
      _loading = false;
    });
  }

  Future<void> _openEditor([BoincHost? existing]) async {
    final result = await Navigator.push<BoincHost>(
      context,
      MaterialPageRoute(builder: (_) => AddHostScreen(existing: existing)),
    );
    if (result == null) return;
    final hosts = [..._hosts];
    final index = hosts.indexWhere((item) => item.id == result.id);
    if (index < 0) {
      hosts.add(result);
    } else {
      hosts[index] = result;
    }
    await _store.save(hosts);
    if (mounted) setState(() => _hosts = hosts);
  }

  Future<void> _delete(BoincHost host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechner löschen?'),
        content: Text('${host.name} wird aus der App entfernt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    final hosts = _hosts.where((item) => item.id != host.id).toList();
    await _store.save(hosts);
    if (mounted) setState(() => _hosts = hosts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BOINC Mobile')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Rechner'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hosts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.hub_outlined, size: 72),
                      const SizedBox(height: 16),
                      Text('Noch kein BOINC-Rechner',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Füge deinen ersten Rechner hinzu. Die automatische Suche kommt in der nächsten Version.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Rechner hinzufügen')),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hosts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final host = _hosts[index];
                    return Card(
                      child: ListTile(
                        leading:
                            const CircleAvatar(child: Icon(Icons.computer)),
                        title: Text(host.name),
                        subtitle: Text('${host.address}:${host.port}'),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => HostDetailScreen(host: host))),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => value == 'edit'
                              ? _openEditor(host)
                              : _delete(host),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: Text('Bearbeiten')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Löschen')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

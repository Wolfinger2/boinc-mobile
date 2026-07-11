import 'package:flutter/material.dart';

import '../models/boinc_host.dart';
import '../models/boinc_task.dart';
import '../services/boinc_rpc_client.dart';

class HostDetailScreen extends StatefulWidget {
  const HostDetailScreen({super.key, required this.host});
  final BoincHost host;

  @override
  State<HostDetailScreen> createState() => _HostDetailScreenState();
}

class _HostDetailScreenState extends State<HostDetailScreen> {
  bool _loading = true;
  String? _error;
  List<BoincTask> _tasks = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<T> _withClient<T>(
      Future<T> Function(BoincRpcClient client) action) async {
    final client = BoincRpcClient(widget.host);
    try {
      await client.connect();
      return await action(client);
    } finally {
      await client.close();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _withClient((client) => client.getTasks());
      if (!mounted) return;
      setState(() => _tasks = tasks);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setSuspended(bool value) async {
    setState(() => _loading = true);
    try {
      await _withClient((client) => client.setRunMode(suspended: value));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value
              ? 'BOINC wurde pausiert.'
              : 'BOINC läuft wieder automatisch.')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.host.name),
        actions: [
          IconButton(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Aktualisieren')
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => _setSuspended(true),
                        icon: const Icon(Icons.pause),
                        label: const Text('Pausieren'))),
                const SizedBox(width: 10),
                Expanded(
                    child: FilledButton.icon(
                        onPressed: _loading ? null : () => _setSuspended(false),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Fortsetzen'))),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    const Icon(Icons.error_outline, size: 42),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                        onPressed: _refresh,
                        child: const Text('Erneut versuchen')),
                  ]),
                ),
              ),
            ),
          if (!_loading && _error == null && _tasks.isEmpty)
            const Expanded(
                child: Center(child: Text('Keine BOINC-Aufgaben vorhanden.'))),
          if (_error == null)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final percent =
                        (task.progress * 100).clamp(0, 100).toStringAsFixed(1);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(task.suspended
                                    ? Icons.pause_circle
                                    : task.active
                                        ? Icons.play_circle
                                        : Icons.schedule),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(task.project,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium)),
                                Text('$percent %'),
                              ]),
                              const SizedBox(height: 8),
                              Text(task.name,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (task.appName.isNotEmpty)
                                Text(task.appName,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: task.progress),
                            ]),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

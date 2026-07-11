import 'package:flutter/material.dart';

import '../models/boinc_host.dart';
import '../services/boinc_rpc_client.dart';
import '../services/network_discovery.dart';

class AddHostScreen extends StatefulWidget {
  const AddHostScreen({super.key, this.existing});
  final BoincHost? existing;

  @override
  State<AddHostScreen> createState() => _AddHostScreenState();
}

class _AddHostScreenState extends State<AddHostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _discovery = BoincNetworkDiscovery();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _port;
  late final TextEditingController _password;
  bool _busy = false;
  bool _discovering = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final host = widget.existing;
    _name = TextEditingController(text: host?.name ?? 'Mein BOINC-PC');
    _address = TextEditingController(text: host?.address ?? '');
    _port = TextEditingController(text: '${host?.port ?? 31416}');
    _password = TextEditingController(text: host?.password ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _port.dispose();
    _password.dispose();
    super.dispose();
  }

  BoincHost _createHost() => BoincHost(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        address: _address.text.trim(),
        port: int.parse(_port.text.trim()),
        password: _password.text,
      );

  Future<void> _discoverHosts() async {
    if (_discovering || _busy) return;
    setState(() => _discovering = true);
    try {
      final hosts = await _discovery.discover();
      if (!mounted) return;
      if (hosts.isEmpty) {
        await _showError(
          'Kein BOINC-Rechner gefunden',
          'Die App hat weder einen offenen BOINC-Port gefunden noch ein '
              'Helper-Signal empfangen. Prüfe, ob BOINC läuft, der '
              'Fernzugriff erlaubt ist und beide Geräte im gleichen WLAN sind.',
        );
        return;
      }

      final selected = await showModalBottomSheet<DiscoveredBoincHost>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Gefundene BOINC-Rechner',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Tippe auf einen Rechner.'),
              ),
              for (final host in hosts)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.computer)),
                  title: Text(host.displayName),
                  subtitle: Text(
                    '${host.address}:${host.port} · ${host.source}',
                  ),
                  onTap: () => Navigator.pop(context, host),
                ),
            ],
          ),
        ),
      );

      if (selected == null || !mounted) return;
      setState(() {
        _address.text = selected.address;
        _port.text = '${selected.port}';
        if (selected.name != null && selected.name!.trim().isNotEmpty) {
          _name.text = selected.name!.trim();
        }
      });
    } catch (error) {
      if (!mounted) return;
      await _showError('Suche fehlgeschlagen', '$error');
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _testAndSave() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final host = _createHost();
    final client = BoincRpcClient(host);
    try {
      await client.connect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verbindung zu BOINC erfolgreich.')),
      );
      Navigator.pop(context, host);
    } on BoincRpcException catch (error) {
      if (!mounted) return;
      await _showError('Verbindung fehlgeschlagen', error.message);
    } catch (error) {
      if (!mounted) return;
      await _showError('Verbindung fehlgeschlagen', '$error');
    } finally {
      await client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showError(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline),
        title: Text(title),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final blocked = _busy || _discovering;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Rechner bearbeiten' : 'Rechner hinzufügen'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              OutlinedButton.icon(
                onPressed: blocked ? null : _discoverHosts,
                icon: _discovering
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar),
                label: Text(
                  _discovering ? 'Suche läuft …' : 'Rechner automatisch suchen',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                enabled: !blocked,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Anzeigename',
                  prefixIcon: Icon(Icons.computer),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Bitte einen Namen eingeben'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                enabled: !blocked,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'IP-Adresse oder Hostname',
                  hintText: '192.168.2.50',
                  prefixIcon: Icon(Icons.lan),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte eine IP-Adresse oder einen Hostnamen eingeben';
                  }
                  if (value.contains('://')) {
                    return 'Nur IP oder Hostname eingeben, ohne http://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _port,
                enabled: !blocked,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  helperText: 'Standard: 31416',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  final port = int.tryParse(value?.trim() ?? '');
                  return port == null || port < 1 || port > 65535
                      ? 'Bitte einen gültigen Port eingeben'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                enabled: !blocked,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => _testAndSave(),
                decoration: InputDecoration(
                  labelText: 'BOINC-GUI-RPC-Passwort',
                  helperText: 'Steht auf dem Rechner in gui_rpc_auth.cfg.',
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    tooltip: _showPassword
                        ? 'Passwort ausblenden'
                        : 'Passwort anzeigen',
                    onPressed: blocked
                        ? null
                        : () => setState(
                              () => _showPassword = !_showPassword,
                            ),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: blocked ? null : _testAndSave,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cable),
                label: Text(
                  _busy ? 'Verbindung wird getestet …' : 'Testen und speichern',
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Die App hört zuerst auf den BOINC-Mobile-Helper '
                          'und scannt danach das lokale /24-Netz nach '
                          'Port 31416. Manuelle Eingabe bleibt möglich.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/boinc_host.dart';
import '../services/boinc_rpc_client.dart';

class AddHostScreen extends StatefulWidget {
  const AddHostScreen({super.key, this.existing});

  final BoincHost? existing;

  @override
  State<AddHostScreen> createState() => _AddHostScreenState();
}

class _AddHostScreenState extends State<AddHostScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _port;
  late final TextEditingController _password;

  bool _busy = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();

    final host = widget.existing;

    _name = TextEditingController(
      text: host?.name ?? 'Mein BOINC-PC',
    );
    _address = TextEditingController(
      text: host?.address ?? '',
    );
    _port = TextEditingController(
      text: '${host?.port ?? 31416}',
    );
    _password = TextEditingController(
      text: host?.password ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _port.dispose();
    _password.dispose();
    super.dispose();
  }

  BoincHost _createHost() {
    return BoincHost(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      address: _address.text.trim(),
      port: int.parse(_port.text.trim()),
      password: _password.text,
    );
  }

  Future<void> _testAndSave() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    final host = _createHost();
    final client = BoincRpcClient(host);

    try {
      await client.connect();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verbindung zu BOINC erfolgreich.'),
        ),
      );

      Navigator.pop(context, host);
    } on BoincRpcException catch (error) {
      if (!mounted) {
        return;
      }

      await _showConnectionError(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showConnectionError(
        'Unbekannter Fehler beim Verbindungsversuch:\n$error',
      );
    } finally {
      await client.close();

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _showConnectionError(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.error_outline),
          title: const Text('Verbindung fehlgeschlagen'),
          content: SelectableText(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? 'Rechner bearbeiten' : 'Rechner hinzufügen',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Anzeigename',
                  prefixIcon: Icon(Icons.computer),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte einen Namen eingeben';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                enabled: !_busy,
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
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  helperText: 'BOINC verwendet normalerweise Port 31416.',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  final port = int.tryParse(value?.trim() ?? '');

                  if (port == null || port < 1 || port > 65535) {
                    return 'Bitte einen gültigen Port eingeben';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => _testAndSave(),
                decoration: InputDecoration(
                  labelText: 'BOINC-GUI-RPC-Passwort',
                  helperText:
                      'Steht auf dem BOINC-Rechner in gui_rpc_auth.cfg.',
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    tooltip: _showPassword
                        ? 'Passwort ausblenden'
                        : 'Passwort anzeigen',
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _testAndSave,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
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
                          'Der BOINC-Rechner muss eingeschaltet sein. '
                          'Der Fernzugriff muss erlaubt sein und Port 31416 '
                          'darf nicht durch die Firewall blockiert werden.',
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

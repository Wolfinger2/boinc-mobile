import 'package:flutter/material.dart';

import '../models/boinc_host.dart';

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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      BoincHost(
        id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        address: _address.text.trim(),
        port: int.parse(_port.text),
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Rechner hinzufügen' : 'Rechner bearbeiten')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Anzeigename', prefixIcon: Icon(Icons.computer)),
                validator: (value) => value == null || value.trim().isEmpty ? 'Bitte Namen eingeben' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'IP-Adresse oder Hostname', hintText: '192.168.2.50', prefixIcon: Icon(Icons.lan)),
                validator: (value) => value == null || value.trim().isEmpty ? 'Bitte Adresse eingeben' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port', prefixIcon: Icon(Icons.numbers)),
                validator: (value) {
                  final port = int.tryParse(value ?? '');
                  return port == null || port < 1 || port > 65535 ? 'Ungültiger Port' : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'BOINC GUI-RPC-Passwort', prefixIcon: Icon(Icons.password)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Speichern')),
            ],
          ),
        ),
      ),
    );
  }
}

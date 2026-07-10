import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../models/boinc_host.dart';
import '../models/boinc_task.dart';

class BoincRpcException implements Exception {
  BoincRpcException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BoincRpcClient {
  BoincRpcClient(this.host);

  final BoincHost host;
  Socket? _socket;
  final _buffer = StringBuffer();
  Completer<String>? _reply;
  StreamSubscription<List<int>>? _subscription;

  Future<void> connect() async {
    await close();
    try {
      _socket = await Socket.connect(
        host.address,
        host.port,
        timeout: const Duration(seconds: 5),
      );
      _subscription = _socket!.listen(
        _onData,
        onError: (Object error) {
          _reply?.completeError(BoincRpcException('Verbindungsfehler: $error'));
          _reply = null;
        },
        onDone: () {
          _reply?.completeError(BoincRpcException('Verbindung wurde beendet.'));
          _reply = null;
        },
      );
      await _authorize();
    } on SocketException catch (error) {
      throw BoincRpcException('Rechner nicht erreichbar: ${error.message}');
    } on TimeoutException {
      throw BoincRpcException('Zeitüberschreitung beim Verbinden.');
    }
  }

  void _onData(List<int> data) {
    for (final byte in data) {
      if (byte == 3) {
        final value = _buffer.toString();
        _buffer.clear();
        _reply?.complete(value);
        _reply = null;
      } else {
        _buffer.writeCharCode(byte);
      }
    }
  }

  Future<String> _request(String body) async {
    final socket = _socket;
    if (socket == null) throw BoincRpcException('Nicht verbunden.');
    if (_reply != null) throw BoincRpcException('Vorherige Anfrage läuft noch.');

    _reply = Completer<String>();
    final packet = '<boinc_gui_rpc_request>$body</boinc_gui_rpc_request>\x03';
    socket.add(utf8.encode(packet));
    await socket.flush();

    return _reply!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _reply = null;
        throw BoincRpcException('BOINC antwortet nicht.');
      },
    );
  }

  Future<void> _authorize() async {
    final first = XmlDocument.parse(await _request('<auth1/>'));
    final nonceNodes = first.findAllElements('nonce');
    if (nonceNodes.isEmpty) {
      if (first.findAllElements('authorized').isNotEmpty) return;
      throw BoincRpcException('BOINC hat keine Anmelde-Challenge gesendet.');
    }

    final nonce = nonceNodes.first.innerText;
    final digest = md5.convert(utf8.encode('$nonce${host.password}')).toString();
    final second = XmlDocument.parse(
      await _request('<auth2><nonce_hash>$digest</nonce_hash></auth2>'),
    );

    if (second.findAllElements('authorized').isEmpty) {
      throw BoincRpcException('Passwort wurde von BOINC abgelehnt.');
    }
  }

  Future<List<BoincTask>> getTasks() async {
    final document = XmlDocument.parse(await _request('<get_state/>'));
    final projects = <String, String>{};
    for (final project in document.findAllElements('project')) {
      final url = _text(project, 'master_url');
      projects[url] = _text(project, 'project_name', fallback: url);
    }

    return document.findAllElements('result').map((result) {
      final schedulerState = int.tryParse(_text(result, 'scheduler_state')) ?? 0;
      final activeTask = result.findElements('active_task').firstOrNull;
      final fraction = activeTask == null
          ? 0.0
          : double.tryParse(_text(activeTask, 'fraction_done')) ?? 0.0;
      final suspended = activeTask != null &&
          (int.tryParse(_text(activeTask, 'suspended_via_gui')) ?? 0) != 0;
      final projectUrl = _text(result, 'project_url');

      return BoincTask(
        name: _text(result, 'name'),
        project: projects[projectUrl] ?? projectUrl,
        appName: _text(result, 'plan_class', fallback: _text(result, 'wu_name')),
        progress: fraction.clamp(0.0, 1.0),
        active: schedulerState == 2,
        suspended: suspended,
      );
    }).toList();
  }

  Future<void> setRunMode({required bool suspended}) async {
    final request = suspended
        ? '<set_run_mode><never/><duration>0</duration></set_run_mode>'
        : '<set_run_mode><auto/><duration>0</duration></set_run_mode>';
    final reply = XmlDocument.parse(await _request(request));
    if (reply.findAllElements('success').isEmpty) {
      throw BoincRpcException('BOINC konnte den Rechenmodus nicht ändern.');
    }
  }

  String _text(XmlElement parent, String name, {String fallback = ''}) {
    final nodes = parent.findElements(name);
    return nodes.isEmpty ? fallback : nodes.first.innerText.trim();
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
    _reply = null;
    _buffer.clear();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

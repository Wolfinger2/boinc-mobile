import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/boinc_host.dart';

class HostStore {
  static const _key = 'boinc_hosts_v1';

  Future<List<BoincHost>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => BoincHost.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<BoincHost> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(hosts.map((host) => host.toJson()).toList()),
    );
  }
}

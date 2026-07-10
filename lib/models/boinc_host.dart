class BoincHost {
  const BoincHost({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.password,
  });

  final String id;
  final String name;
  final String address;
  final int port;
  final String password;

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'port': port,
        'password': password,
      };

  factory BoincHost.fromJson(Map<String, dynamic> json) => BoincHost(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        port: (json['port'] as num).toInt(),
        password: json['password'] as String? ?? '',
      );
}

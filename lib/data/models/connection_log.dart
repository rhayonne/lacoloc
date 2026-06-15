import 'package:intl/intl.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'fr');

class ConnectionLog {
  final int id;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final String? userType;
  final String? ipAddress;
  final String? userAgent;
  final String? device;
  final String? browser;
  final String? timezone;
  final DateTime createdAt;

  const ConnectionLog({
    required this.id,
    this.userId,
    this.userEmail,
    this.userName,
    this.userType,
    this.ipAddress,
    this.userAgent,
    this.device,
    this.browser,
    this.timezone,
    required this.createdAt,
  });

  factory ConnectionLog.fromMap(Map<String, dynamic> m) => ConnectionLog(
        id: m['id'] as int,
        userId: m['user_id'] as String?,
        userEmail: m['user_email'] as String?,
        userName: m['user_name'] as String?,
        userType: m['user_type'] as String?,
        ipAddress: m['ip_address'] as String?,
        userAgent: m['user_agent'] as String?,
        device: m['device'] as String?,
        browser: m['browser'] as String?,
        timezone: m['timezone'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );

  String get createdAtLabel => _dateFmt.format(createdAt);

  /// Lien WHOIS / ipinfo.io pour l'adresse IP.
  String? get whoisUrl {
    final ip = ipAddress;
    if (ip == null || ip.isEmpty || ip == 'unknown') return null;
    return 'https://ipinfo.io/$ip';
  }

  String get displayDevice => [device, browser]
      .where((s) => s != null && s.isNotEmpty && s != 'Inconnu')
      .join(' / ');

  String get userTypeLabel => switch (userType) {
        'super_admin' => 'Super Admin',
        'proprietaire' => 'Propriétaire',
        'locataire' => 'Locataire',
        'admin_groupe' => 'Admin Groupe',
        _ => userType ?? '—',
      };
}

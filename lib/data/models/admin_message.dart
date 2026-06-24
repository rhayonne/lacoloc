/// Message diffusé par le super admin (table `Admin_Messages`) — historique des
/// envois.
class AdminMessage {
  final int id;
  final String senderId;
  final String title;
  final String? body;
  final String? mediaType; // 'image' | 'youtube'
  final String? mediaUrl;
  final String? audience; // libellé de l'audience ciblée
  final int recipientsCount;
  final DateTime createdAt;

  const AdminMessage({
    required this.id,
    required this.senderId,
    required this.title,
    this.body,
    this.mediaType,
    this.mediaUrl,
    this.audience,
    required this.recipientsCount,
    required this.createdAt,
  });

  factory AdminMessage.fromMap(Map<String, dynamic> m) => AdminMessage(
        id: m['id'] as int,
        senderId: m['sender_id'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        mediaType: m['media_type'] as String?,
        mediaUrl: m['media_url'] as String?,
        audience: m['audience'] as String?,
        recipientsCount: (m['recipients_count'] as int?) ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

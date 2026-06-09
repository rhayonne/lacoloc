/// Notification in-app destinée au propriétaire (table `Notifications`).
class NotificationModel {
  final int id;
  final String proprietaireId;
  final String type; // 'edl_accepte', …
  final String title;
  final String? body;
  final int? etatDeLieuxId;
  final String? locataireId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.proprietaireId,
    required this.type,
    required this.title,
    this.body,
    this.etatDeLieuxId,
    this.locataireId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> m) => NotificationModel(
        id: m['id'] as int,
        proprietaireId: m['proprietaire_id'] as String,
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        etatDeLieuxId: m['etat_de_lieux_id'] as int?,
        locataireId: m['locataire_id'] as String?,
        isRead: (m['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

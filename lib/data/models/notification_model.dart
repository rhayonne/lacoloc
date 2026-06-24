/// Notification in-app destinée au propriétaire (table `Notifications`).
class NotificationModel {
  final int id;
  final String proprietaireId;

  /// Destinataire effectif de la notification (`recipient_id`). Sur les lignes
  /// historiques (avant la généralisation), il vaut le `proprietaire_id`. Pour
  /// une notification destinée à un locataire, il vaut son id.
  final String recipientId;
  final String type; // 'edl_accepte', 'edl_a_signer', …
  final String title;
  final String? body;
  final int? etatDeLieuxId;
  final String? locataireId;
  final bool isRead;
  final DateTime createdAt;

  /// Média joint (messages du super admin) : `image` ou `youtube`.
  final String? mediaType;

  /// Pour `image` : URL de l'image. Pour `youtube` : identifiant de la vidéo
  /// (11 caractères) ou URL — résolu à l'affichage.
  final String? mediaUrl;

  const NotificationModel({
    required this.id,
    required this.proprietaireId,
    required this.recipientId,
    required this.type,
    required this.title,
    this.body,
    this.etatDeLieuxId,
    this.locataireId,
    this.isRead = false,
    required this.createdAt,
    this.mediaType,
    this.mediaUrl,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> m) => NotificationModel(
        id: m['id'] as int,
        proprietaireId: m['proprietaire_id'] as String,
        recipientId:
            (m['recipient_id'] as String?) ?? (m['proprietaire_id'] as String),
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        etatDeLieuxId: m['etat_de_lieux_id'] as int?,
        locataireId: m['locataire_id'] as String?,
        isRead: (m['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
        mediaType: m['media_type'] as String?,
        mediaUrl: m['media_url'] as String?,
      );
}

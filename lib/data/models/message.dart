/// Un message d'un fil de discussion rattaché à une demande de contact.
///
/// Le fil s'ouvre quand le proprietaire accepte la demande
/// (`Demandes_Contact.contact_etabli = true`) — avant, la RLS refuse l'insertion.
class MessageModel {
  final int id;
  final int demandeId;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Nom de l'expéditeur (embed `Users_Client!sender_id(full_name)`).
  final String? senderName;

  const MessageModel({
    required this.id,
    required this.demandeId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.senderName,
  });

  bool get isRead => readAt != null;

  /// Le message a-t-il été écrit par [userId] ?
  bool isMine(String? userId) => userId != null && senderId == userId;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return MessageModel(
      id: json['id'] as int,
      demandeId: json['demande_id'] as int,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      senderName: sender?['full_name'] as String?,
    );
  }
}

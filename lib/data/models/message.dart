/// Un message d'un fil de discussion rattaché à une demande de contact.
///
/// Le fil est ouvert dès qu'une demande existe (plus d'acceptation préalable) ;
/// la RLS de `Messages` autorise `auth.uid() IN (sender_id, recipient_id)`.
///
/// **Pas de nom d'expéditeur ici** : l'identité de l'autre partie passe par la
/// RPC `demande_counterpart_profiles`, qui applique ses préférences de
/// visibilité. Le fil affiche déjà l'interlocuteur dans son en-tête, et une
/// bulle se reconnaît à son côté ([isMine]).
class MessageModel {
  final int id;
  final int demandeId;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const MessageModel({
    required this.id,
    required this.demandeId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  /// Le message a-t-il été écrit par [userId] ?
  bool isMine(String? userId) => userId != null && senderId == userId;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
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
    );
  }
}

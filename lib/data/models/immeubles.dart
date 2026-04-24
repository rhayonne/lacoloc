class ImmeublesModel {
  final int id;
  final String nome;
  final String? description;
  final DateTime? createdAt;

  ImmeublesModel({
    required this.id,
    required this.nome,
    this.createdAt,
    this.description,
  });

  factory ImmeublesModel.fromMap(Map<String, dynamic> map) {
    return ImmeublesModel(
      id: map['id'],
      nome: map['nome'],
      description: map['description'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }
}

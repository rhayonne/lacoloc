/// Tipo de imóvel (Appartement, Maison, Studio, Loft, ...).
/// Vive na tabela `Immeuble_Types_Reference` e se relaciona com Immeubles
/// por uma tabela de junção (N-N).
class ImmeubleTypeModel {
  final int id;
  final String typeName;

  const ImmeubleTypeModel({required this.id, required this.typeName});

  factory ImmeubleTypeModel.fromMap(Map<String, dynamic> map) {
    return ImmeubleTypeModel(
      id: map['id'] as int,
      typeName: (map['name'] ?? '') as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImmeubleTypeModel &&
      other.id == id &&
      other.typeName == typeName;

  @override
  int get hashCode => Object.hash(id, typeName);
}

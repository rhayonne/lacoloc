/// Item genérico das tabelas de referência (id + nome).
/// Usado tanto por Immeuble_Types_Reference quanto por Options_Reference.
class ReferenceItem {
  final int id;
  final String name;

  const ReferenceItem({required this.id, required this.name});

  factory ReferenceItem.fromMap(Map<String, dynamic> map) {
    return ReferenceItem(
      id: map['id'] as int,
      name: (map['name'] ?? '') as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReferenceItem && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

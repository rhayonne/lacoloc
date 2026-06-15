/// Conta empresa (multi-tenant). Espelha a tabela `Entreprises`.
///
/// Uma empresa agrupa imóveis e usuários (um `admin_groupe` + propriétaires).
/// O [domain] (ex.: `empresa.fr`) é definido **somente pelo super admin** e usado
/// como sufixo dos e-mails dos usuários criados pelo admin de groupe
/// (`local@domain`).
class Entreprise {
  final int id;
  final String name;
  final String? domain;
  final bool active;
  final DateTime? createdAt;

  const Entreprise({
    required this.id,
    required this.name,
    this.domain,
    this.active = true,
    this.createdAt,
  });

  factory Entreprise.fromMap(Map<String, dynamic> map) => Entreprise(
        id: (map['id'] as num).toInt(),
        name: map['name'] as String,
        domain: map['domain'] as String?,
        active: (map['active'] as bool?) ?? true,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );
}

import 'package:flutter/widgets.dart';
import 'package:lacoloc_front/data/permissions/permissions_service.dart';

/// Exibe [child] apenas se o usuário tiver a permissão [permission]
/// (ou qualquer uma de [anyOf]). Caso contrário exibe [fallback]
/// (por padrão, nada). Reage automaticamente à carga das permissões.
///
/// Uso típico — esconder um botão de criação:
/// ```dart
/// PermissionGate(
///   permission: Perm.immeublesCreate,
///   child: FilledButton(...),
/// )
/// ```
class PermissionGate extends StatelessWidget {
  final String? permission;
  final Iterable<String>? anyOf;
  final Widget child;
  final Widget fallback;

  const PermissionGate({
    super.key,
    this.permission,
    this.anyOf,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  }) : assert(permission != null || anyOf != null,
            'Informe permission ou anyOf');

  bool get _allowed {
    final svc = PermissionsService.instance;
    if (permission != null && svc.can(permission!)) return true;
    if (anyOf != null && svc.canAny(anyOf!)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PermissionsService.instance.revision,
      builder: (_, _, _) => _allowed ? child : fallback,
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';

/// Envolve a árvore de widgets autenticados e desloga o usuário após
/// [timeout] de inatividade (sem toque ou teclado).
///
/// O contador reinicia a cada interação do usuário (tap, scroll, tecla).
/// Quando expira, chama [AuthService.signOut] (global) e chama [onTimeout]
/// para que o chamador redirecione para o login.
///
/// Uso:
/// ```dart
/// SessionGuard(onTimeout: () => Navigator.pushReplacementNamed(context, '/login'),
///   child: ProprietaireProfilPage())
/// ```
class SessionGuard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;
  final Duration timeout;

  const SessionGuard({
    super.key,
    required this.child,
    required this.onTimeout,
    this.timeout = const Duration(minutes: 30),
  });

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    await AuthService.signOut();
    if (mounted) widget.onTimeout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Centraliza e limita a largura de formulários em TABLET e DESKTOP.
/// Em MOBILE renderiza [child] sem modificação.
///
/// Uso:
/// ```dart
/// return ResponsiveFormWrapper(
///   child: SingleChildScrollView(...),
/// );
/// ```
class ResponsiveFormWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveFormWrapper({
    super.key,
    required this.child,
    this.maxWidth = 860,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isMobile) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/presentation/users/admin/connection_logs_page.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/app_tab_bar.dart';

/// Section **Maintenance** du super admin. Regroupe en onglets :
///  - **Connexions** : le journal des connexions ([ConnectionLogsPage]).
///  - **Services** : des outils de maintenance (ex. test d'envoi d'e-mail).
class MaintenancePage extends StatelessWidget {
  final int initialTab;
  final bool showTabBar;
  const MaintenancePage(
      {super.key, this.initialTab = 0, this.showTabBar = true});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Les sous-pages (Connexions / Services) fournissent leur propre
          // barre de titre (AppTopBar) ; pas de double en-tête « Maintenance ».
          if (showTabBar) ...[
            AppTabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Connexions'),
                Tab(text: 'Services'),
              ],
            ),
            const Divider(height: 1),
          ],
          const Expanded(
            child: TabBarView(
              children: [
                ConnectionLogsPage(),
                _ServicesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Onglet Services ──────────────────────────────────────────────────────────

class _ServicesTab extends StatelessWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopBar(title: 'Services'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: const [
              _EmailTestService(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Service « Test d'envoi d'e-mail » — menu sanfona (accordéon). Permet au super
/// admin d'envoyer un e-mail de test (création/activation ou réinitialisation) à
/// un destinataire, **sans créer de compte**, et d'inspecter la réponse complète
/// de la fonction edge.
class _EmailTestService extends StatefulWidget {
  const _EmailTestService();

  @override
  State<_EmailTestService> createState() => _EmailTestServiceState();
}

class _EmailTestServiceState extends State<_EmailTestService> {
  final _emailCtrl = TextEditingController();
  String _emailType = 'invite';
  bool _sending = false;
  // null = jamais envoyé ; Map vide sentinelle = en cours
  Map<String, dynamic>? _result;
  String? _clientError;

  static const _types = [
    ('invite', 'Création de compte & activation'),
    ('reset', 'Réinitialisation du mot de passe'),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _emailCtrl.text.trim();
    if (to.isEmpty || !to.contains('@')) {
      setState(() {
        _clientError = 'Saisissez une adresse e-mail valide.';
      });
      return;
    }
    setState(() {
      _sending = true;
      _clientError = null;
      _result = {};   // sentinelle "en cours" → la boîte reste visible
    });
    try {
      final r = await EtatDesLieuxDatasource.sendServiceTestEmail(
        to: to,
        emailType: _emailType,
      );
      if (mounted) setState(() { _result = r; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = {'ok': false, 'error': '$e'};
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.mail_outline),
        title: Text(
          'Test d\'envoi d\'e-mail',
          style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Envoie un e-mail de test à un destinataire (aucun compte créé).',
          style: AppTypography.labelSm
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg,
        ),
        children: [
          // ── Formulaire : inline sur large écran, colonne sur petit ──────────
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final emailField = TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.bodyMd,
              decoration: InputDecoration(
                labelText: 'E-mail destinataire',
                labelStyle: AppTypography.labelSm,
                prefixIcon: const Icon(Icons.alternate_email, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: AppRadius.borderSm),
                errorText: _clientError,
              ),
            );
            final typeField = DropdownButtonFormField<String>(
              initialValue: _emailType,
              style: AppTypography.bodyMd,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Type',
                labelStyle: AppTypography.labelSm,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: AppRadius.borderSm),
              ),
              items: _types
                  .map((t) => DropdownMenuItem(
                        value: t.$1,
                        child: Text(t.$2,
                            style: AppTypography.bodyMd,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _sending
                  ? null
                  : (v) => setState(() => _emailType = v ?? 'invite'),
            );
            final sendBtn = FilledButton.icon(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 10),
                textStyle: AppTypography.labelMd,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 16),
              label: Text(_sending ? 'Envoi…' : 'Envoyer'),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(flex: 2, child: emailField),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(flex: 1, child: typeField),
                  const SizedBox(width: AppSpacing.sm),
                  sendBtn,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                emailField,
                const SizedBox(height: AppSpacing.sm),
                typeField,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerLeft, child: sendBtn),
              ],
            );
          }),

          const SizedBox(height: AppSpacing.md),

          // ── Boîte de réponse — toujours visible ────────────────────────────
          _JsonResultBox(result: _result, sending: _sending),
        ],
      ),
    );
  }
}

/// Boîte de réponse style Swagger — **toujours visible** :
///  - `result == null` → état idle (aucun envoi encore)
///  - `result == {}` (sentinelle) + `sending == true` → en cours
///  - `result` non vide → retour de la fonction edge (succès ou erreur)
class _JsonResultBox extends StatelessWidget {
  final Map<String, dynamic>? result;
  final bool sending;
  const _JsonResultBox({required this.result, required this.sending});

  bool get _idle => result == null;
  bool get _inProgress => sending && (result?.isEmpty ?? false);
  bool get _ok =>
      (result?['ok'] == true || result?['emailSent'] == true) && !_inProgress;

  String get _pretty {
    if (_idle || result == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(result);
    } catch (_) {
      return result.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Couleur du bandeau selon l'état
    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerLabel;

    if (_idle) {
      bannerColor = AppColors.onSurfaceVariant;
      bannerIcon = Icons.terminal_outlined;
      bannerLabel = 'Réponse';
    } else if (_inProgress) {
      bannerColor = AppColors.primary;
      bannerIcon = Icons.hourglass_top_outlined;
      bannerLabel = 'Envoi en cours…';
    } else if (_ok) {
      bannerColor = Colors.green;
      bannerIcon = Icons.check_circle_outline;
      bannerLabel = 'E-mail envoyé';
    } else {
      bannerColor = AppColors.error;
      bannerIcon = Icons.error_outline;
      bannerLabel = 'Échec de l\'envoi';
    }

    return ClipRRect(
      borderRadius: AppRadius.borderSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bandeau de statut
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 8,
            ),
            color: bannerColor.withValues(alpha: _idle ? 0.07 : 0.12),
            child: Row(
              children: [
                if (_inProgress)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: bannerColor,
                    ),
                  )
                else
                  Icon(bannerIcon, size: 14, color: bannerColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    bannerLabel,
                    style: AppTypography.labelSm.copyWith(
                      color: bannerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!_idle && !_inProgress)
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _pretty));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Retour copié.')),
                      );
                    },
                    child: Tooltip(
                      message: 'Copier',
                      child: Icon(Icons.copy_outlined,
                          size: 14, color: bannerColor),
                    ),
                  ),
              ],
            ),
          ),

          // Corps JSON (sombre, monospace)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(AppSpacing.md),
            color: const Color(0xFF1E1E2E),
            child: _idle
                ? Text(
                    '// Aucune réponse pour le moment.\n// Remplissez le formulaire ci-dessus et cliquez sur Envoyer.',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF6A6A8A),
                    ),
                  )
                : SelectableText(
                    _pretty.isNotEmpty ? _pretty : '{}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFFD4D4D4),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

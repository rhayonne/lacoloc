import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:habitafrance/data/datasources/entreprises.dart';
import 'package:habitafrance/data/models/entreprise.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/phone_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuração da empresa (lado **admin de groupe**): lista os usuários da
/// empresa e cria novos **propriétaires** com e-mail `local@domínio` — o
/// domínio é fixo (definido pelo super admin) e o admin de groupe só edita o
/// `local` (parte antes do @).
class EntrepriseConfigPage extends StatefulWidget {
  final int entrepriseId;
  const EntrepriseConfigPage({super.key, required this.entrepriseId});

  @override
  State<EntrepriseConfigPage> createState() => _EntrepriseConfigPageState();
}

class _EntrepriseConfigPageState extends State<EntrepriseConfigPage> {
  late Future<Entreprise?> _future;

  @override
  void initState() {
    super.initState();
    _future = EntreprisesDatasource.byId(widget.entrepriseId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Entreprise?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final entreprise = snap.data;
        if (entreprise == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppTopBar(title: 'Configuration entreprise'),
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Entreprise introuvable.'),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTopBar(title: 'Entreprise — ${entreprise.name}'),
            Expanded(child: _ComptesTab(entreprise: entreprise)),
          ],
        );
      },
    );
  }
}

// ─── Aba Comptes ──────────────────────────────────────────────────────────────

class _ComptesTab extends StatefulWidget {
  final Entreprise entreprise;
  const _ComptesTab({required this.entreprise});

  @override
  State<_ComptesTab> createState() => _ComptesTabState();
}

class _ComptesTabState extends State<_ComptesTab> {
  late Future<List<UsersClient>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final f = EntreprisesDatasource.listMembers(widget.entreprise.id);
    setState(() {
      _future = f;
    });
  }

  Future<void> _createCompte() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateCompteDialog(entreprise: widget.entreprise),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final domain = widget.entreprise.domain;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Comptes de l\'entreprise',
                    style: AppTypography.headlineMd),
              ),
              AppButton.primary(
                icon: Icons.person_add_outlined,
                label: 'Créer un compte',
                onPressed: domain == null || domain.isEmpty ? null : _createCompte,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            domain == null || domain.isEmpty
                ? 'Domaine non défini par le super admin — création indisponible.'
                : 'Domaine : @$domain',
            style: AppTypography.labelSm.copyWith(
              color: domain == null || domain.isEmpty
                  ? AppColors.error
                  : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<UsersClient>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erreur : ${snap.error}'));
                }
                final members = snap.data ?? [];
                if (members.isEmpty) {
                  return Center(
                    child: Text('Aucun compte pour le moment.',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  );
                }
                return ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _memberTile(members[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(UsersClient m) async {
    try {
      await EntreprisesDatasource.resetPassword(userId: m.id, email: m.email, fullName: m.fullName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'E-mail de réinitialisation envoyé à ${m.email}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Widget _memberTile(UsersClient m) {
    final isAdmin = m.resolvedType == UserType.adminGroupe;
    // O admin de groupe não redefine a própria senha por aqui (só dos membros).
    final isSelf = m.id == Supabase.instance.client.auth.currentUser?.id;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryFixed,
        child: Icon(
          isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(m.fullName ?? m.email,
          style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text('${m.email}  ·  ${m.typeUserRef?.label ?? '—'}',
          style: AppTypography.labelSm
              .copyWith(color: AppColors.onSurfaceVariant)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!m.active)
            Text('Inactif',
                style: AppTypography.labelSm.copyWith(color: AppColors.error)),
          if (!isSelf)
            IconButton(
              tooltip: 'Réinitialiser le mot de passe',
              icon: const Icon(Icons.lock_reset_outlined, size: 20),
              onPressed: () => _resetPassword(m),
            ),
        ],
      ),
    );
  }
}

// ─── Dialog criar compte (propriétaire) ───────────────────────────────────────

class _CreateCompteDialog extends StatefulWidget {
  final Entreprise entreprise;
  const _CreateCompteDialog({required this.entreprise});

  @override
  State<_CreateCompteDialog> createState() => _CreateCompteDialogState();
}

class _CreateCompteDialogState extends State<_CreateCompteDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _loading = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    final local = (v['local'] as String).trim().toLowerCase();
    final email = '$local@${widget.entreprise.domain}';
    setState(() => _loading = true);
    try {
      await EntreprisesDatasource.createProprietaire(
        entrepriseId: widget.entreprise.id,
        fullName: v['full_name'] as String,
        email: email,
        phone: v['phone'] as String?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un compte propriétaire'),
      content: SizedBox(
        width: 420,
        child: FormBuilder(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'full_name',
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: FormBuilderValidators.required(),
              ),
              const SizedBox(height: AppSpacing.md),
              // E-mail : só o local-part é editável ; o domínio é fixo (sufixo).
              FormBuilderTextField(
                name: 'local',
                decoration: InputDecoration(
                  labelText: 'Identifiant e-mail',
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixText: '@${widget.entreprise.domain}',
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  (val) {
                    final s = (val ?? '').trim();
                    if (s.contains('@') || s.contains(' ')) {
                      return 'Saisissez seulement la partie avant le @.';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(s)) {
                      return 'Caractères autorisés : lettres, chiffres, . _ -';
                    }
                    return null;
                  },
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              PhoneField(name: 'phone'),
            ],
          ),
        ),
      ),
      actions: [
        AppButton.cancel(
          label: 'Annuler',
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
        AppButton.save(
          label: 'Créer',
          isBusy: _loading,
          onPressed: _loading ? null : _submit,
        ),
      ],
    );
  }
}

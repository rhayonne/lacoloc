import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lacoloc_front/data/datasources/entreprises.dart';
import 'package:lacoloc_front/data/models/entreprise.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/email_field.dart';
import 'package:lacoloc_front/utils/phone_field.dart';

/// Gestão de contas empresa (Super Admin). Criar empresas, definir o **domínio**
/// (só o super admin pode), e criar o **admin de groupe** de cada empresa.
class ComptesEntreprisesPage extends StatefulWidget {
  const ComptesEntreprisesPage({super.key});

  @override
  State<ComptesEntreprisesPage> createState() => _ComptesEntreprisesPageState();
}

class _ComptesEntreprisesPageState extends State<ComptesEntreprisesPage> {
  late Future<List<Entreprise>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final f = EntreprisesDatasource.listAll();
    setState(() {
      _future = f;
    });
  }

  Future<void> _createEntreprise() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _EntrepriseDialog(),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Comptes Entreprises',
                    style: AppTypography.headlineMd),
              ),
              FilledButton.icon(
                onPressed: _createEntreprise,
                icon: const Icon(Icons.domain_add_outlined, size: 18),
                label: const Text('Créer une entreprise'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<Entreprise>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erreur : ${snap.error}'));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Text('Aucune entreprise.',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _EntrepriseCard(
                    key: ValueKey(list[i].id),
                    entreprise: list[i],
                    onChanged: _reload,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de empresa ──────────────────────────────────────────────────────────

class _EntrepriseCard extends StatefulWidget {
  final Entreprise entreprise;
  final VoidCallback onChanged;
  const _EntrepriseCard({
    super.key,
    required this.entreprise,
    required this.onChanged,
  });

  @override
  State<_EntrepriseCard> createState() => _EntrepriseCardState();
}

class _EntrepriseCardState extends State<_EntrepriseCard> {
  bool _expanded = false;
  bool _loading = false;
  List<UsersClient>? _members;

  Future<void> _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _members == null) await _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final m = await EntreprisesDatasource.listMembers(widget.entreprise.id);
      if (mounted) setState(() => _members = m);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editEntreprise() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EntrepriseDialog(existing: widget.entreprise),
    );
    if (ok == true) widget.onChanged();
  }

  Future<void> _createAdminGroupe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminGroupeDialog(entreprise: widget.entreprise),
    );
    if (ok == true) await _loadMembers();
  }

  Future<void> _toggleEntrepriseActive() async {
    final e = widget.entreprise;
    try {
      await EntreprisesDatasource.update(e.id, active: !e.active);
      widget.onChanged();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $err')));
      }
    }
  }

  Future<void> _toggleMemberActive(UsersClient m) async {
    try {
      await EntreprisesDatasource.setMemberActive(m.id, !m.active);
      await _loadMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _resetMemberPassword(UsersClient m) async {
    try {
      await EntreprisesDatasource.resetPassword(userId: m.id, email: m.email, fullName: m.fullName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('E-mail de réinitialisation envoyé à ${m.email}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entreprise;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.business_outlined,
                color: AppColors.primary),
            title: Text(e.name,
                style:
                    AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Row(
              children: [
                Icon(Icons.alternate_email,
                    size: 14,
                    color: e.domain != null
                        ? AppColors.onSurfaceVariant
                        : AppColors.error),
                const SizedBox(width: 4),
                Text(
                  e.domain ?? 'Domaine non défini',
                  style: AppTypography.labelSm.copyWith(
                    color: e.domain != null
                        ? AppColors.onSurfaceVariant
                        : AppColors.error,
                  ),
                ),
                if (!e.active) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text('Inactive',
                      style:
                          AppTypography.labelSm.copyWith(color: AppColors.error)),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Activer / désactiver toute l'entreprise (cascade : ses membres
                // perdent toutes leurs permissions tant qu'elle est inactive).
                Tooltip(
                  message: e.active
                      ? 'Désactiver l\'entreprise'
                      : 'Activer l\'entreprise',
                  child: Switch(
                    value: e.active,
                    onChanged: (_) => _toggleEntrepriseActive(),
                  ),
                ),
                IconButton(
                  tooltip: 'Modifier l\'entreprise',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _editEntreprise,
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: _toggle,
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.outlineVariant)),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Membres',
                          style: AppTypography.labelMd
                              .copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _createAdminGroupe,
                        icon: const Icon(Icons.admin_panel_settings_outlined,
                            size: 18),
                        label: const Text('Créer un admin de groupe'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if ((_members ?? []).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text('Aucun membre.',
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant)),
                    )
                  else
                    for (final m in _members!) _memberTile(m),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _memberTile(UsersClient m) {
    final isAdmin = m.resolvedType == UserType.adminGroupe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
            size: 18,
            color: isAdmin ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${m.fullName ?? m.email}  ·  ${m.email}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMd,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.5),
              borderRadius: AppRadius.borderFull,
            ),
            child: Text(m.typeUserRef?.label ?? '—',
                style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: 'Réinitialiser le mot de passe',
            icon: const Icon(Icons.lock_reset_outlined, size: 20),
            onPressed: () => _resetMemberPassword(m),
          ),
          // Activer / désactiver ce membre (super admin).
          Tooltip(
            message: m.active ? 'Désactiver' : 'Activer',
            child: Switch(
              value: m.active,
              onChanged: (_) => _toggleMemberActive(m),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog criar/editar empresa ──────────────────────────────────────────────

class _EntrepriseDialog extends StatefulWidget {
  final Entreprise? existing;
  const _EntrepriseDialog({this.existing});

  @override
  State<_EntrepriseDialog> createState() => _EntrepriseDialogState();
}

class _EntrepriseDialogState extends State<_EntrepriseDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _loading = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    setState(() => _loading = true);
    try {
      final name = (v['name'] as String).trim();
      final domain = (v['domain'] as String?)?.trim();
      if (widget.existing == null) {
        await EntreprisesDatasource.create(name: name, domain: domain);
      } else {
        await EntreprisesDatasource.update(widget.existing!.id,
            name: name, domain: domain);
      }
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
    final e = widget.existing;
    return AlertDialog(
      title: Text(e == null ? 'Créer une entreprise' : 'Modifier l\'entreprise'),
      content: SizedBox(
        width: 420,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'name': e?.name ?? '',
            'domain': e?.domain ?? '',
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'entreprise',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: FormBuilderValidators.required(),
              ),
              const SizedBox(height: AppSpacing.md),
              FormBuilderTextField(
                name: 'domain',
                decoration: const InputDecoration(
                  labelText: 'Domaine e-mail (ex. : entreprise.fr)',
                  helperText:
                      'Utilisé comme suffixe des comptes créés par l\'admin de groupe.',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(e == null ? 'Créer' : 'Enregistrer'),
        ),
      ],
    );
  }
}

// ─── Dialog criar admin de groupe ─────────────────────────────────────────────

class _AdminGroupeDialog extends StatefulWidget {
  final Entreprise entreprise;
  const _AdminGroupeDialog({required this.entreprise});

  @override
  State<_AdminGroupeDialog> createState() => _AdminGroupeDialogState();
}

class _AdminGroupeDialogState extends State<_AdminGroupeDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _loading = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    setState(() => _loading = true);
    try {
      await EntreprisesDatasource.createAdminGroupe(
        entrepriseId: widget.entreprise.id,
        fullName: v['full_name'] as String,
        email: v['email'] as String,
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
      title: const Text('Créer un admin de groupe'),
      content: SizedBox(
        width: 420,
        child: FormBuilder(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Entreprise : ${widget.entreprise.name}',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              FormBuilderTextField(
                name: 'full_name',
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: FormBuilderValidators.required(),
              ),
              const SizedBox(height: AppSpacing.md),
              EmailField(name: 'email'),
              const SizedBox(height: AppSpacing.md),
              PhoneField(name: 'phone'),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Créer'),
        ),
      ],
    );
  }
}

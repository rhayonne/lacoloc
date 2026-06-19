import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/charge_reference.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

// ─── Modèle de sélection ─────────────────────────────────────────────────────

/// Représente la sélection d'une charge.
/// [type] ∈ {'inclus', 'fixe', 'variable'}.
/// Quand une charge n'est pas sélectionnée elle est absente de la liste —
/// pas de valeur 'aucun'.
class ChargeSelection {
  final ChargeReferenceModel ref;
  final String type; // 'inclus' | 'fixe' | 'variable'
  final double? montant; // non null uniquement quand type == 'fixe'

  const ChargeSelection({
    required this.ref,
    required this.type,
    this.montant,
  });

  bool get isInclus   => type == 'inclus';
  bool get isFixe     => type == 'fixe';
  bool get isVariable => type == 'variable';

  ChargeSelection copyWith({String? type, double? montant}) => ChargeSelection(
        ref: ref,
        type: type ?? this.type,
        montant: (type ?? this.type) == 'fixe' ? (montant ?? this.montant) : null,
      );
}

// ─── Widget principal ─────────────────────────────────────────────────────────

/// Sélecteur de charges sur 3 colonnes (≥720 px), 2 colonnes (≥480 px) ou
/// 1 colonne (mobile). Chaque charge dispose de quatre options :
/// Aucun (défaut, non affiché) · Inclus dans le loyer · Montant fixe · Variable.
class ChargesSelector extends StatefulWidget {
  final List<ChargeReferenceModel> available;
  final List<ChargeSelection> initial;
  final ValueChanged<List<ChargeSelection>> onChanged;
  final bool enabled;

  const ChargesSelector({
    super.key,
    required this.available,
    required this.initial,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<ChargesSelector> createState() => _ChargesSelectorState();
}

class _ChargesSelectorState extends State<ChargesSelector> {
  // chargeRefId → sélection courante (absent = désactivé)
  late final Map<int, ChargeSelection> _selected;
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _selected = {for (final s in widget.initial) s.ref.id: s};
    for (final s in widget.initial) {
      if (s.type == 'fixe') {
        _controllers[s.ref.id] = TextEditingController(
          text: s.montant?.toStringAsFixed(2) ?? '',
        );
      } else {
        continue;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// [newType] == 'none' → retire la charge ; sinon ajoute/met à jour.
  void _setOption(ChargeReferenceModel ref, String newType) {
    if (!widget.enabled) return;
    setState(() {
      if (newType == 'none') {
        _selected.remove(ref.id);
        _controllers.remove(ref.id)?.dispose();
      } else {
        final prev = _selected[ref.id];
        _selected[ref.id] = ChargeSelection(
          ref: ref,
          type: newType,
          montant: newType == 'fixe' ? prev?.montant : null,
        );
        if (newType == 'fixe') {
          _controllers[ref.id] ??= TextEditingController(
            text: prev?.montant?.toStringAsFixed(2) ?? '',
          );
        } else {
          _controllers.remove(ref.id)?.dispose();
        }
      }
    });
    _notify();
  }

  void _setMontant(ChargeReferenceModel ref, String raw) {
    if (!widget.enabled) return;
    final v = double.tryParse(raw.replaceAll(',', '.'));
    final prev = _selected[ref.id];
    if (prev == null) return;
    _selected[ref.id] = prev.copyWith(montant: v);
    _notify();
  }

  void _notify() =>
      widget.onChanged(List.unmodifiable(_selected.values.toList()));

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.available.isEmpty) {
      return Text(
        'Aucune charge disponible. Contactez le super admin.',
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 720 ? 3 : w >= 480 ? 2 : 1;
        const spacing = AppSpacing.sm;
        final itemW = (w - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: widget.available.map((ref) {
            final sel = _selected[ref.id];
            return SizedBox(
              width: itemW,
              child: _ChargeCard(
                ref: ref,
                selection: sel,
                controller: _controllers[ref.id],
                enabled: widget.enabled,
                onOptionChanged: (t) => _setOption(ref, t),
                onMontantChanged: (v) => _setMontant(ref, v),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChargeCard extends StatelessWidget {
  final ChargeReferenceModel ref;
  final ChargeSelection? selection;
  final TextEditingController? controller;
  final bool enabled;
  final ValueChanged<String> onOptionChanged;
  final ValueChanged<String> onMontantChanged;

  const _ChargeCard({
    required this.ref,
    required this.selection,
    required this.controller,
    required this.enabled,
    required this.onOptionChanged,
    required this.onMontantChanged,
  });

  String get _currentType => selection?.type ?? 'none';
  bool get _isActive => selection != null;
  bool get _isFixe   => selection?.type == 'fixe';

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _isActive
            ? AppColors.primaryFixed.withValues(alpha: 0.45)
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isActive ? AppColors.primary : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête charge ────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                ref.iconData,
                size: 18,
                color: _isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  ref.nom,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: _isActive ? FontWeight.w600 : FontWeight.normal,
                    color: _isActive ? AppColors.onSurface : AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Options ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'none',
                  icon: Icon(Icons.block_outlined, size: 13),
                  label: Text('Aucun'),
                ),
                ButtonSegment(
                  value: 'inclus',
                  icon: Icon(Icons.check_circle_outline, size: 13),
                  label: Text('Inclus'),
                ),
                ButtonSegment(
                  value: 'fixe',
                  icon: Icon(Icons.euro, size: 13),
                  label: Text('Fixe'),
                ),
                ButtonSegment(
                  value: 'variable',
                  icon: Icon(Icons.show_chart, size: 13),
                  label: Text('Var.'),
                ),
              ],
              selected: {_currentType},
              onSelectionChanged: enabled
                  ? (s) => onOptionChanged(s.first)
                  : null,
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(AppTypography.labelSm),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          // ── Champ montant (uniquement si fixe) ────────────────────────────
          if (_isFixe) ...[
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant (€/mois)',
                prefixText: '€ ',
                isDense: true,
              ),
              onChanged: onMontantChanged,
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/address_search.dart';
import 'package:lacoloc_front/data/models/address_suggestion.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Campo de endereço com autocomplete via API Adresse (BAN - data.gouv.fr).
///
/// Ao selecionar uma sugestão, [onSuggestionSelected] é chamado com todos
/// os dados (cidade, departamento, região) para preencher os demais campos.
class AddressAutocompleteField extends StatefulWidget {
  final String initialValue;
  final void Function(String) onChanged;
  final void Function(AddressSuggestion) onSuggestionSelected;

  const AddressAutocompleteField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.onSuggestionSelected,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  TextEditingController? _innerCtrl;

  // Versão incrementada a cada tecla; garante que só a última busca é exibida.
  int _searchVersion = 0;

  @override
  void dispose() {
    _innerCtrl?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => widget.onChanged(_innerCtrl!.text);

  Future<Iterable<AddressSuggestion>> _fetch(TextEditingValue value) async {
    final version = ++_searchVersion;
    if (value.text.trim().length < 3) return const [];
    // Debounce de 280 ms: só chama a API se nenhuma tecla foi pressionada depois.
    await Future.delayed(const Duration(milliseconds: 280));
    if (_searchVersion != version || !mounted) return const [];
    return AddressSearchService.search(value.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<AddressSuggestion>(
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: _fetch,
      displayStringForOption: (s) => s.label,
      fieldViewBuilder: (_, ctrl, focusNode, onFieldSubmitted) {
        if (_innerCtrl != ctrl) {
          _innerCtrl?.removeListener(_onTextChanged);
          _innerCtrl = ctrl;
          _innerCtrl!.addListener(_onTextChanged);
        }
        return TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          decoration: const InputDecoration(
            labelText: 'Adresse complète',
            prefixIcon: Icon(Icons.location_on_outlined),
            hintText: 'Ex : 10 rue de la Paix, Paris',
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: AppRadius.borderMd,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 256),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = options.elementAt(i);
                  final sub = [
                    if (s.city.isNotEmpty) s.city,
                    if (s.department.isNotEmpty) s.department,
                    if (s.region.isNotEmpty) s.region,
                  ].join(' · ');
                  return InkWell(
                    onTap: () => onSelected(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label, style: AppTypography.bodyMd),
                                if (sub.isNotEmpty)
                                  Text(
                                    sub,
                                    style: AppTypography.labelSm.copyWith(
                                        color: AppColors.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (s) {
        widget.onChanged(s.label);
        widget.onSuggestionSelected(s);
      },
    );
  }
}

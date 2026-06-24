import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

/// Champ numérique avec flèches ▲▼ (incrément/décrément) **et** saisie directe,
/// intégré à `flutter_form_builder` (la valeur est stockée en `String` pour
/// rester compatible avec les lectures existantes `values['<name>']`).
///
/// [step] = pas d'incrément ; [min]/[max] = bornes ; [decimal] autorise les
/// décimales. [onValue] notifie la valeur courante (pour un calcul dérivé,
/// ex. montant démonstratif).
class NumberStepperField extends StatefulWidget {
  final String name;
  final String? initialValue;
  final String labelText;
  final String? helperText;
  final IconData? prefixIcon;
  final double step;
  final double min;
  final double? max;
  final bool decimal;
  final ValueChanged<double?>? onValue;

  const NumberStepperField({
    super.key,
    required this.name,
    required this.labelText,
    this.initialValue,
    this.helperText,
    this.prefixIcon,
    this.step = 1,
    this.min = 0,
    this.max,
    this.decimal = false,
    this.onValue,
  });

  @override
  State<NumberStepperField> createState() => _NumberStepperFieldState();
}

class _NumberStepperFieldState extends State<NumberStepperField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      widget.decimal ? v.toString() : v.toStringAsFixed(0);

  void _bump(FormFieldState<String> field, double delta) {
    final current =
        double.tryParse((_ctrl.text).replaceAll(',', '.')) ?? widget.min;
    var next = current + delta;
    if (next < widget.min) next = widget.min;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    final text = _fmt(next);
    _ctrl.text = text;
    field.didChange(text);
    widget.onValue?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<String>(
      name: widget.name,
      initialValue: widget.initialValue,
      builder: (field) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: widget.labelText,
            helperText: widget.helperText,
            prefixIcon:
                widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
            errorText: field.errorText,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.decimal),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9]')),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) {
                    field.didChange(v);
                    widget.onValue
                        ?.call(double.tryParse(v.replaceAll(',', '.')));
                  },
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _bump(field, widget.step),
                    child: const Icon(Icons.keyboard_arrow_up, size: 20),
                  ),
                  InkWell(
                    onTap: () => _bump(field, -widget.step),
                    child: const Icon(Icons.keyboard_arrow_down, size: 20),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

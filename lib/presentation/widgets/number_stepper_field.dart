import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

/// Champ numérique avec flèches ▲▼ (incrément/décrément) **et** saisie directe,
/// intégré à `flutter_form_builder` (valeur stockée en `String` pour rester
/// compatible avec les lectures `values['<name>']`).
///
/// Rendu : un **seul** champ bordé (pas de cadre dans le cadre) — les flèches
/// sont un `suffixIcon`, le libellé flotte normalement sur la bordure.
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

  String _fmt(double v) => widget.decimal ? v.toString() : v.toStringAsFixed(0);

  void _bump(FormFieldState<String> field, double delta) {
    final current =
        double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? widget.min;
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
        return TextField(
          controller: _ctrl,
          keyboardType:
              TextInputType.numberWithOptions(decimal: widget.decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9]')),
          ],
          decoration: InputDecoration(
            labelText: widget.labelText,
            helperText: widget.helperText,
            prefixIcon:
                widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
            errorText: field.errorText,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 38, minHeight: 46),
            suffixIcon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Arrow(
                    icon: Icons.keyboard_arrow_up,
                    onTap: () => _bump(field, widget.step)),
                _Arrow(
                    icon: Icons.keyboard_arrow_down,
                    onTap: () => _bump(field, -widget.step)),
              ],
            ),
          ),
          onChanged: (v) {
            field.didChange(v);
            widget.onValue?.call(double.tryParse(v.replaceAll(',', '.')));
          },
        );
      },
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Arrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

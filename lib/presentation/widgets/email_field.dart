import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

class _EmailInputFormatter extends TextInputFormatter {
  static final _allowed = RegExp(r'[a-zA-Z0-9._%+\-@]');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final filtered =
        newValue.text.split('').where((c) => _allowed.hasMatch(c)).join();
    if (filtered == newValue.text) return newValue;
    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

final _emailRegex =
    RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

class EmailField extends StatelessWidget {
  final String name;
  final String? labelText;
  final bool required;
  final String? initialValue;
  final void Function(String?)? onChanged;

  const EmailField({
    super.key,
    required this.name,
    this.labelText = 'E-mail',
    this.required = false,
    this.initialValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      name: name,
      initialValue: initialValue,
      decoration: InputDecoration(labelText: labelText),
      keyboardType: TextInputType.emailAddress,
      inputFormatters: [_EmailInputFormatter()],
      onChanged: onChanged,
      validator: FormBuilderValidators.compose([
        if (required) FormBuilderValidators.required(),
        (v) {
          final value = v?.trim() ?? '';
          if (value.isEmpty) return null;
          return _emailRegex.hasMatch(value) ? null : 'Adresse e-mail invalide';
        },
      ]),
    );
  }
}

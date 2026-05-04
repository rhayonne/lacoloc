import 'package:flutter/material.dart';
import 'package:form_builder_phone_field/form_builder_phone_field.dart';

class PhoneField extends StatelessWidget {
  final String name;
  final String? initialValue;
  final String? labelText;
  final bool required;
  final void Function(String?)? onChanged;

  const PhoneField({
    super.key,
    required this.name,
    this.initialValue,
    this.labelText = 'Téléphone',
    this.required = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderPhoneField(
      name: name,
      initialValue: initialValue,
      defaultSelectedCountryIsoCode: 'FR',
      decoration: InputDecoration(labelText: labelText),
      onChanged: onChanged,
    );
  }
}

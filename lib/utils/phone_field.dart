import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_phone_field/form_builder_phone_field.dart';

class PhoneField extends StatefulWidget {
  final String name;
  final String? initialValue;
  final String? labelText;
  final bool required;
  final bool enabled;
  final void Function(String?)? onChanged;

  const PhoneField({
    super.key,
    required this.name,
    this.initialValue,
    this.labelText = 'Téléphone',
    this.required = false,
    this.enabled = true,
    this.onChanged,
  });

  /// Converts any stored phone value to full international format.
  /// Numbers without a + prefix are assumed French (+33).
  static String? normalize(String? v) {
    if (v == null || v.isEmpty) return null;
    if (v.startsWith('+')) return v;
    if (v.startsWith('0')) return '+33${v.substring(1)}';
    return '+33$v';
  }

  /// Reads the full international phone number from a [FormBuilderState].
  ///
  /// Uses [instantValue] (not [value]) so the number is available even when
  /// the form's `save()` was never called — `value` only reflects `_savedValue`,
  /// which stays empty until `save()`/`saveAndValidate()` runs. Both apply the
  /// field's [valueTransformer], so the result is the complete international
  /// number (e.g. "+33612345678").
  static String? fullNumberFromState(
    FormBuilderState? state,
    String fieldName,
  ) {
    final val = state?.instantValue[fieldName] as String?;
    return (val != null && val.isNotEmpty) ? val : null;
  }

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  // Current country dial code, e.g. "+33". Initialised from initialValue and
  // updated whenever the user changes the country picker (onChanged fires).
  String _dialCode = '+33';

  @override
  void initState() {
    super.initState();
    final normalized = PhoneField.normalize(widget.initialValue) ?? '';
    if (normalized.startsWith('+')) {
      final match = RegExp(r'^\+\d+').firstMatch(normalized);
      if (match != null) _dialCode = match.group(0)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderPhoneField(
      name: widget.name,
      initialValue: PhoneField.normalize(widget.initialValue),
      defaultSelectedCountryIsoCode: 'FR',
      priorityListByIsoCode: const ['FR', 'BE', 'CH', 'LU'],
      enabled: widget.enabled,
      decoration: InputDecoration(labelText: widget.labelText),
      onChanged: (fullNumber) {
        // FormBuilderPhoneField fires onChanged with the full number only
        // when the country picker changes. Capture the new dial code so
        // valueTransformer below uses the correct prefix.
        if (fullNumber != null && fullNumber.startsWith('+')) {
          final match = RegExp(r'^\+\d+').firstMatch(fullNumber);
          if (match != null && mounted) {
            setState(() => _dialCode = match.group(0)!);
          }
        }
        widget.onChanged?.call(fullNumber);
      },
      // Ensures FormBuilderState.value / saveAndValidate() always returns the
      // full international number instead of the raw national digits that
      // FormBuilderPhoneField stores internally.
      valueTransformer: (national) {
        if (national == null || national.isEmpty) return null;
        if (national.startsWith('+')) return national;
        return '$_dialCode$national';
      },
    );
  }
}

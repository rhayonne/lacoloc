class AddressSuggestion {
  final String label;
  final String city;
  final String postcode;
  final String department;
  final String region;

  const AddressSuggestion({
    required this.label,
    required this.city,
    required this.postcode,
    required this.department,
    required this.region,
  });

  factory AddressSuggestion.fromProperties(Map<String, dynamic> props) {
    final ctx = (props['context'] as String? ?? '').split(', ');
    return AddressSuggestion(
      label: props['label'] as String? ?? '',
      city: props['city'] as String? ?? '',
      postcode: props['postcode'] as String? ?? '',
      department: ctx.length > 1 ? ctx[1] : '',
      region: ctx.length > 2 ? ctx[2] : '',
    );
  }
}

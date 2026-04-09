class FieldValue {
  final DateTime createdAt;
  final double value;

  const FieldValue({required this.createdAt, required this.value});
}

class Field {
  final int id;
  final String? label;
  final List<FieldValue> values;

  const Field({required this.id, this.label, this.values = const []});

  String get displayLabel => label?.isNotEmpty == true ? label! : 'Field $id';

  double? get lastValue => values.isEmpty ? null : values.last.value;
  DateTime? get lastUpdated => values.isEmpty ? null : values.last.createdAt;
}

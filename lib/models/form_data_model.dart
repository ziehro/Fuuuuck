// lib/models/form_data_model.dart

// Enum to represent the various input types for the dynamic form
enum InputFieldType {
  text,
  number,
  multiChoice,
  singleChoice,
  slider,
}

// Data structure to represent a form field for dynamic rendering
class FormFieldData {
  final String label;
  final InputFieldType type;
  final List<String>? options; // For single/multi-choice
  final int? minValue; // For slider
  final int? maxValue; // For slider
  dynamic initialValue; // Stores the current value of the field

  FormFieldData({
    required this.label,
    required this.type,
    this.options,
    this.minValue,
    this.maxValue,
    this.initialValue,
  });
}
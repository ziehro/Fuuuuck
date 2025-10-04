// lib/widgets/add_beach/dynamic_form_page.dart
import 'package:flutter/material.dart';
import 'package:mybeachbook/models/form_data_model.dart';
import 'package:mybeachbook/widgets/add_beach/form_field_widget.dart';

class DynamicFormPage extends StatelessWidget {
  final List<FormFieldData> fields;
  final Map<String, dynamic> formData;

  // Optional controllers for specific numeric fields
  final TextEditingController? widthController;
  final TextEditingController? lengthController;
  final TextEditingController? bluffHeightController;

  const DynamicFormPage({
    super.key,
    required this.fields,
    required this.formData,
    this.widthController,
    this.lengthController,
    this.bluffHeightController,
  });

  // Get dedicated controller if one exists for this field
  TextEditingController? _getDedicatedController(String fieldLabel) {
    switch (fieldLabel) {
      case 'Width':
        return widthController;
      case 'Length':
        return lengthController;
      case 'Bluff Height':
        return bluffHeightController;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeepAlivePage(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: fields.map((field) {
          return FormFieldWidget(
            field: field,
            formData: formData,
            controller: _getDedicatedController(field.label),
          );
        }).toList(),
      ),
    );
  }
}

// A helper widget to keep the state of each page in the PageView alive.
class KeepAlivePage extends StatefulWidget {
  final Widget child;

  const KeepAlivePage({super.key, required this.child});

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context); // This is important!
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
// lib/widgets/add_beach/form_field_widget.dart
import 'package:flutter/material.dart';
import 'package:mybeachbook/models/form_data_model.dart';
import 'package:mybeachbook/services/gemini_service.dart';
import 'package:mybeachbook/util/long_press_descriptions.dart';

class FormFieldWidget extends StatefulWidget {
  final FormFieldData field;
  final Map<String, dynamic> formData;
  final TextEditingController? controller; // Optional controller for text/number fields

  const FormFieldWidget({
    super.key,
    required this.field,
    required this.formData,
    this.controller,
  });

  @override
  State<FormFieldWidget> createState() => _FormFieldWidgetState();
}

class _FormFieldWidgetState extends State<FormFieldWidget> {
  final GeminiService _geminiService = GeminiService();
  late TextEditingController _localController;
  bool _usingProvidedController = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    if (widget.controller != null) {
      // Use the provided controller
      _localController = widget.controller!;
      _usingProvidedController = true;

      // Initialize the controller with existing form data if it's empty
      if (_localController.text.isEmpty && widget.formData.containsKey(widget.field.label)) {
        _localController.text = widget.formData[widget.field.label].toString();
      }
    } else {
      // Create our own controller
      _localController = TextEditingController(
        text: widget.formData[widget.field.label]?.toString() ?? '',
      );
      _usingProvidedController = false;

      // Add listener to sync with form data
      _localController.addListener(() {
        final value = _localController.text;
        if (widget.field.type == InputFieldType.number) {
          final numValue = double.tryParse(value);
          if (numValue != null) {
            widget.formData[widget.field.label] = numValue;
          } else if (value.isEmpty) {
            widget.formData.remove(widget.field.label);
          }
        } else if (widget.field.type == InputFieldType.text) {
          if (value.isNotEmpty) {
            widget.formData[widget.field.label] = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          } else {
            widget.formData[widget.field.label] = [];
          }
        }
      });
    }
  }

  void _showInfoDialog(String subject) {
    // Get the description from our new map, or use a default if not found.
    final String description = longPressDescriptions[subject] ?? 'No description available.';

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<GeminiInfo>(
          // We still fetch the image from Gemini
          future: _geminiService.getInfoAndImage(subject, description: description),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading info...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('Could not load information.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                ],
              );
            }

            final info = snapshot.data!;
            return AlertDialog(
              title: Text(subject),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: info.image,
                    ),
                    const SizedBox(height: 16),
                    // Use the description from our map
                    Text(info.description),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showInfoDialog(widget.field.label),
      child: AbsorbPointer(
        absorbing: false,
        child: _buildFormField(),
      ),
    );
  }

  Widget _buildFormField() {
    switch (widget.field.type) {
      case InputFieldType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: _localController,
            decoration: InputDecoration(labelText: widget.field.label, hintText: 'Enter Here, separated by commas'),
            onSaved: (value) {
              if (value != null && value.isNotEmpty) {
                widget.formData[widget.field.label] = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              } else {
                widget.formData[widget.field.label] = [];
              }
            },
          ),
        );
      case InputFieldType.number:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: _localController,
            decoration: InputDecoration(labelText: widget.field.label, hintText: 'Enter Here'),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a number';
              if (double.tryParse(value) == null) return 'Please enter a valid number';
              return null;
            },
            onSaved: (value) => widget.formData[widget.field.label] = double.tryParse(value ?? '0.0'),
          ),
        );
      case InputFieldType.slider:
        if (!widget.formData.containsKey(widget.field.label)) {
          widget.formData[widget.field.label] = widget.field.minValue ?? 0;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.field.label}: ${(widget.formData[widget.field.label] ?? widget.field.minValue ?? 0).round()}', style: Theme.of(context).textTheme.bodyLarge),
              Slider(
                value: (widget.formData[widget.field.label] ?? widget.field.minValue ?? 0).toDouble(),
                min: (widget.field.minValue ?? 0).toDouble(),
                max: (widget.field.maxValue ?? 5).toDouble(),
                divisions: (widget.field.maxValue ?? 5) - (widget.field.minValue ?? 0),
                label: (widget.formData[widget.field.label] ?? widget.field.minValue ?? 0).round().toString(),
                onChanged: (double value) {
                  setState(() {
                    widget.formData[widget.field.label] = value.round();
                  });
                },
                onChangeEnd: (double value) {
                  widget.formData[widget.field.label] = value.round();
                },
              ),
            ],
          ),
        );
      case InputFieldType.singleChoice:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildSingleChoiceDropdown(widget.field.label, widget.field.options!),
        );
      case InputFieldType.multiChoice:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildMultiChoiceChips(widget.field.label, widget.field.options!),
        );
    }
  }

  Widget _buildSingleChoiceDropdown(String label, List<String> options) {
    if (!widget.formData.containsKey(label)) {
      widget.formData[label] = null;
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: widget.formData[label] as String?,
      items: options.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          widget.formData[label] = newValue;
        });
      },
      onSaved: (newValue) => widget.formData[label] = newValue,
    );
  }

  Widget _buildMultiChoiceChips(String label, List<String> options) {
    if (!widget.formData.containsKey(label)) {
      widget.formData[label] = <String>[];
    }
    List<String> selectedOptions = List<String>.from(widget.formData[label] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options.map((option) {
            final bool isSelected = selectedOptions.contains(option);
            return GestureDetector(
              onLongPress: () => _showInfoDialog(option),
              child: FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      selectedOptions.add(option);
                    } else {
                      selectedOptions.remove(option);
                    }
                    widget.formData[label] = selectedOptions;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Only dispose the controller if we created it ourselves
    if (!_usingProvidedController) {
      _localController.dispose();
    }
    super.dispose();
  }
}
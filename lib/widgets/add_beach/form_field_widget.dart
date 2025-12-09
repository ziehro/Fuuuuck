// lib/widgets/add_beach/form_field_widget.dart
import 'package:flutter/material.dart';
import 'package:mybeachbook/models/form_data_model.dart';
import 'package:mybeachbook/services/gemini_service.dart';
import 'package:mybeachbook/util/long_press_descriptions.dart';

import '../../util/shell_icons.dart';

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
    final String description = longPressDescriptions[subject] ?? 'No description available.';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(subject),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Use a simple icon instead of AI-generated image
                Icon(
                  _getIconForSubject(subject),
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(description),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

// Helper to get appropriate icon
  IconData _getIconForSubject(String subject) {
    // Flora
    if (['Seaweed Beach', 'Seaweed Rocks', 'Kelp Beach', 'Tree types'].contains(subject)) {
      return Icons.eco;
    }
    // Fauna
    if (['Anemones', 'Barnacles', 'Bugs', 'Snails', 'Oysters', 'Clams', 'Limpets', 'Turtles', 'Mussels', 'Birds'].contains(subject)) {
      return Icons.pets;
    }
    // Wood
    if (['Kindling', 'Firewood', 'Logs', 'Trees'].contains(subject)) {
      return Icons.park;
    }
    // Composition
    if (['Sand', 'Pebbles', 'Rocks', 'Boulders', 'Stone'].contains(subject)) {
      return Icons.terrain;
    }
    return Icons.info;
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

    final bool isShellField = label == 'Which Shells';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Use Column instead of Wrap for vertical layout
        if (isShellField)
          ...options.map((option) {
            final bool isSelected = selectedOptions.contains(option);
            final ImageProvider? imageProvider = ShellIcons.getImageProvider(option);

            return GestureDetector(
              onLongPress: () => _showInfoDialog(option),
              child: Card(
                elevation: isSelected ? 4 : 1,
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : null,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedOptions.remove(option);
                      } else {
                        selectedOptions.add(option);
                      }
                      widget.formData[label] = selectedOptions;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        // Large shell image
                        if (imageProvider != null)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[300],
                            ),
                            child: const Icon(Icons.image, size: 40),
                          ),

                        const SizedBox(width: 16),

                        // Shell name
                        Expanded(
                          child: Text(
                            option,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),

                        // Checkmark
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                            size: 32,
                          )
                        else
                          Icon(
                            Icons.circle_outlined,
                            color: Colors.grey[400],
                            size: 32,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList()
        else
        // Keep original Wrap layout for other multi-choice fields
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
// lib/util/beach_form_fields.dart
import 'package:fuuuuck/models/form_data_model.dart';

final List<FormFieldData> beachFormFields = [
  // Flora
  FormFieldData(label: 'Seaweed Beach', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Seaweed Rocks', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Kelp Beach', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Tree types', type: InputFieldType.text),

  // Fauna
  FormFieldData(label: 'Anemones', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Barnacles', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Bugs', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Snails', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Oysters', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Clams', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Limpets', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Turtles', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Mussels', type: InputFieldType.slider, minValue: 1, maxValue: 7),
  FormFieldData(label: 'Birds', type: InputFieldType.text),
  FormFieldData(label: 'Which Shells', type: InputFieldType.multiChoice, options: ['Butter Clam', 'Mussel', 'Crab', 'Oyster', 'Whelks', 'Turban', 'Sand dollars', 'Cockles', 'Starfish', 'Limpets']),

  // Wood
  FormFieldData(label: 'Kindling', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Firewood', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Logs', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Trees', type: InputFieldType.slider, minValue: 1, maxValue: 5),

  // Composition
  FormFieldData(label: 'Width', type: InputFieldType.number),
  FormFieldData(label: 'Length', type: InputFieldType.number),
  FormFieldData(label: 'Sand', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Pebbles', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Baseball Rocks', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Rocks', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Boulders', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Stone', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Coal', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Mud', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Midden', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Islands', type: InputFieldType.slider, minValue: 1, maxValue: 5),
  FormFieldData(label: 'Bluff Height', type: InputFieldType.number),
  FormFieldData(label: 'Bluffs Grade', type: InputFieldType.slider, minValue: 0, maxValue: 90),
  FormFieldData(label: 'Shape', type: InputFieldType.singleChoice, options: ['Concave', 'Convex', 'Isthmus', 'Horseshoe', 'Straight']),
  FormFieldData(label: 'Bluff Comp', type: InputFieldType.multiChoice, options: ['Sand', 'Rock', 'Thick Brush', 'Grass']),
  FormFieldData(label: 'Rock Type', type: InputFieldType.singleChoice, options: ['Igneous', 'Sedimentary', 'Metamorphic']),

  // Other
  FormFieldData(label: 'Boats on Shore', type: InputFieldType.slider, minValue: 0, maxValue: 1),
  FormFieldData(label: 'Caves', type: InputFieldType.slider, minValue: 0, maxValue: 1),
  FormFieldData(label: 'Patio Nearby?', type: InputFieldType.slider, minValue: 0, maxValue: 1),
  FormFieldData(label: 'Gold', type: InputFieldType.slider, minValue: 0, maxValue: 1),
  FormFieldData(label: 'Lookout', type: InputFieldType.slider, minValue: 0, maxValue: 1),
  FormFieldData(label: 'Private', type: InputFieldType.slider, minValue: 0, maxValue: 1),
  FormFieldData(label: 'Stink', type: InputFieldType.slider, minValue: 0, maxValue: 1),
  FormFieldData(label: 'Windy', type: InputFieldType.slider, minValue: 0, maxValue: 2),
  FormFieldData(label: 'Garbage', type: InputFieldType.slider, minValue: 1, maxValue: 9),
  FormFieldData(label: 'People', type: InputFieldType.slider, minValue: 0, maxValue: 5),
  FormFieldData(label: 'Best Tide', type: InputFieldType.singleChoice, options: ['Low', 'Mid', 'High', "Don't Matter"]),
  FormFieldData(label: 'Parking', type: InputFieldType.singleChoice, options: ['Parked on the beach', '1 minute', '5 minutes', '10 minutes', '30 minutes', '1 hour plus', 'Boat access only']),
  FormFieldData(label: 'Treasure', type: InputFieldType.text),
  FormFieldData(label: 'New Items', type: InputFieldType.text),
  FormFieldData(label: 'Man Made', type: InputFieldType.multiChoice, options: ['Seawall', 'Sewar Line', 'Walkway', 'Garbage Cans', 'Tents', 'Picnic Tables', 'Benches', 'Houses', 'Playground', 'Bathrooms', 'Campground', 'Protective Structure To Escape the Weather', 'Boat Dock', 'Boat Launch']),
  FormFieldData(label: 'Shade', type: InputFieldType.multiChoice, options: ['in the morning', 'in the evening', 'in the afternoon', 'none']),
];
// lib/util/beach_icons.dart
import 'package:flutter/material.dart';

class BeachIcons {
  // Map display names to icon filenames
  static const Map<String, String> _iconMap = {
    // Shells
    'Butter Clam': 'butter_clam',
    'Mussel': 'mussel',
    'Crab': 'crab',
    'Oyster': 'oyster',
    'Whelks': 'whelks',
    'Turban': 'turban',
    'Sand dollars': 'sand_dollars',
    'Cockles': 'cockles',
    'Starfish': 'starfish',
    'Which Shells': 'which_shells',

    // Beach Materials
    'Sand': 'sand',
    'Pebbles': 'pebbles',
    'Baseball Rocks': 'baseball_rocks',
    'Rocks': 'rocks',
    'Boulders': 'boulders',
    'Stone': 'stone',
    'Coal': 'coal',
    'Mud': 'mud',
    'Midden': 'midden',
    'Islands': 'islands',

    // Marine Life
    'Seaweed Beach': 'seaweed_beach',
    'Seaweed Rocks': 'seaweed_rocks',
    'Kelp Beach': 'kelp_beach',
    'Anemones': 'anemones',
    'Barnacles': 'barnacles',
    'Bugs': 'bugs',
    'Snails': 'snails',
    'Oysters': 'oysters_living',
    'Clams': 'clams_living',
    'Limpets': 'limpets_living',

    // Wood & Trees
    'Kindling': 'kindling',
    'Firewood': 'firewood',
    'Logs': 'logs',
    'Trees': 'trees',
    'Tree types': 'tree_types',
    'Turtles': 'turtles',
    'Mussels': 'mussels_living',
    'Birds': 'birds',
    'Garbage': 'garbage',
    'People': 'people',

    // Beach Features
    'Width': 'width',
    'Length': 'length',
    'Bluff Height': 'bluff_height',
    'Bluffs Grade': 'bluffs_grade',
    'Boats on Shore': 'boats_on_shore',
    'Caves': 'caves',
    'Lookout': 'lookout',
    'Patio Nearby?': 'patio_nearby',
    'Gold': 'gold',
    'Private': 'private',

    // Conditions
    'Stink': 'stink',
    'Windy': 'windy',
    'Shape': 'shape',
    'Bluff Comp': 'bluff_comp',
    'Rock Type': 'rock_type',
    'Best Tide': 'best_tide',
    'Parking': 'parking',
    'Treasure': 'treasure',
    'New Items': 'new_items',
    'Man Made': 'man_made',

    // Shade
    'Shade': 'shade',
  };

  static ImageProvider? getIcon(String displayName) {
    final filename = _iconMap[displayName];
    if (filename == null) return null;

    return AssetImage('assets/icons/$filename.png');
  }

  static bool hasIcon(String displayName) {
    return _iconMap.containsKey(displayName);
  }
}
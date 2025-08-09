// lib/util/metric_ranges.dart

class MetricRange {
  final int min;
  final int max;

  const MetricRange(this.min, this.max);
}

const Map<String, MetricRange> metricRanges = {
  'Boats on Shore': MetricRange(0, 1),
  'Caves': MetricRange(0, 1),
  'Patio Nearby?': MetricRange(0, 1),
  'Gold': MetricRange(0, 1),
  'Lookout': MetricRange(0, 1),
  'Private': MetricRange(0, 1),
  'Stink': MetricRange(0, 1),
  'Windy': MetricRange(0, 2),
  'Trees': MetricRange(1, 5),
  'Logs': MetricRange(1, 5),
  'Firewood': MetricRange(1, 5),
  'Kindling': MetricRange(1, 5),
  'Baseball Rocks': MetricRange(1, 5),
  'Boulders': MetricRange(1, 5),
  'Sand': MetricRange(1, 5),
  'Pebbles': MetricRange(1, 5),
  'Rocks': MetricRange(1, 5),
  'Islands': MetricRange(1, 5),
  'Mud': MetricRange(1, 5),
  'Midden': MetricRange(1, 5),
  'Stone': MetricRange(1, 5),
  'Coal': MetricRange(1, 5),
  'Anemones': MetricRange(1, 7),
  'Barnacles': MetricRange(1, 7),
  'Seaweed Beach': MetricRange(1, 7),
  'Seaweed Rocks': MetricRange(1, 7),
  'Kelp Beach': MetricRange(1, 7),
  'Bugs': MetricRange(1, 7),
  'Snails': MetricRange(1, 7),
  'Oysters': MetricRange(1, 7),
  'Clams': MetricRange(1, 7),
  'Limpets': MetricRange(1, 7),
  'Turtles': MetricRange(1, 7),
  'Mussels': MetricRange(1, 7),
  'Bluffs Grade': MetricRange(1, 9),
  'Garbage': MetricRange(1, 9),
  'People': MetricRange(0, 5),
  'Width':  MetricRange(0, 300),   // adjust if you use different units
  'Length': MetricRange(0, 2000),  // adjust as needed
};
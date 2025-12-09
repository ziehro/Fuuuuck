// lib/util/long_press_descriptions.dart

const Map<String, String> longPressDescriptions = {
  // Flora
  'Seaweed Beach': 'Indicates the amount of seaweed washed up on the main beach area.',
  'Seaweed Rocks': 'Indicates the amount of seaweed found on the rocks.',
  'Kelp Beach': 'Indicates the amount of kelp washed up on the beach.',
  'Tree types': 'A list of tree species that contributors have identified near the beach.',

  // Fauna
  'Anemones': 'A measure of the anemone population found in tide pools or on rocks. These marine animals resemble flowers, with a soft, cylindrical body and a central mouth surrounded by tentacles.',
  'Barnacles': 'A measure of the barnacle population on rocks or other surfaces. They are small crustaceans with a hard outer shell that permanently attach themselves to surfaces.',
  'Bugs': 'A general measure of annoying insects like flies or mosquitoes.',
  'Clams': 'A measure of the clam population, often identified by their shells. Clams are bivalve mollusks with two shells of equal size connected by a hinge.',
  'Limpets': 'A measure of the limpet population on rocks. Limpets are aquatic snails with a cone-shaped shell, known for their ability to cling tightly to rocks.',
  'Mussels': 'A measure of the mussel population on rocks or in beds. They are bivalve mollusks, typically with a dark blue or black elongated shell.',
  'Oysters': 'A measure of the oyster population, including live oysters and shells. Oysters are bivalve mollusks with an irregular, rough shell.',
  'Snails': 'A measure of the sea snail population. These are gastropod mollusks, typically with a spiral shell.',
  'Turtles': 'A measure of turtle presence, such as sightings or nests. A rare sight!',
  'Birds': 'A list of bird species that contributors have identified at the beach.',
  'Which Shells': 'Indicates which types of shells were most commonly found on the beach.',

  // Wood
  'Kindling': 'Measures the availability of small, dry twigs and branches suitable for starting a fire.',
  'Firewood': 'Measures the availability of medium-sized driftwood, perfect for a campfire.',
  'Logs': 'Measures the availability of large logs that can still be moved by a person.',
  'Trees': 'Measures the presence of very large, unmovable trees or logs washed ashore.',

  // Composition
  'Width': 'The average width of the beach from the water line to the back, measured in steps.',
  'Length': 'The total length of the walkable beach area, measured in steps.',
  'Sand': 'A rating of the quality and quantity of sand.',
  'Pebbles': 'The amount of small, smooth stones on the beach.',
  'Baseball Rocks': 'The amount of rocks on the beach that are approximately the size of a baseball.',
  'Rocks': 'The amount of rocks larger than a baseball but smaller than a boulder.',
  'Boulders': 'The amount of very large rocks on the beach.',
  'Stone': 'Indicates the presence of solid, flat bedrock, as opposed to loose rocks.',
  'Coal': 'Indicates the presence of coal pieces, which can be found on some local beaches.',
  'Mud': 'Measures the amount of mud, which can affect accessibility and cleanliness.',
  'Midden': 'Indicates the presence of a shell midden, an archaeological site consisting of ancient shell deposits.',
  'Islands': 'Notes the presence and proximity of islands visible from the beach.',
  'Bluff Height': 'The estimated height of any bluffs or cliffs behind the beach, measured in feet.',
  'Bluffs Grade': 'The steepness or angle of the bluffs behind the beach, measured in degrees.',
  'Shape': 'The overall shape of the coastline at the beach (e.g., a long straight line, a curved cove).',
  'Bluff Comp': 'The primary materials that make up the bluffs (e.g., sand, rock, clay).',
  'Rock Type': 'The most noticeable or common type of rock found on the beach, categorized as Igneous, Sedimentary, or Metamorphic.',

  // Other
  'Boats on Shore': 'Indicates if there are boats moored or beached nearby.',
  'Caves': 'Indicates the presence of sea caves accessible from the beach.',
  'Patio Nearby?': 'Indicates if there is a restaurant or pub with a patio within walking distance.',
  'Gold': 'Indicates whether there is a potential for gold panning on the beach.',
  'Lookout': 'Indicates if there is a designated scenic lookout point nearby.',
  'Private': 'Indicates if access to the beach is via private property.',
  'Stink': 'A rating of any noticeable, unpleasant odors, such as from decaying seaweed.',
  'Windy': 'A measure of how windy the beach typically is.',
  'Garbage': 'A rating of the amount of litter or garbage on the beach. Lower is better!',
  'People': 'A general measure of how crowded the beach typically is.',
  'Best Tide': 'The recommended tide level (Low, Mid, or High) for the best experience at this beach.',
  'Parking': 'Information on the distance and type of parking available for the beach.',
  'Treasure': 'A place for contributors to note any unique or interesting items they have found.',
  'New Items': 'A field for contributors to add new, unlisted items they have observed.',
  'Man Made': 'The presence of man-made structures on or near the beach, such as seawalls or benches.',
  'Shade': 'Information on the availability of shade at different times of the day.',
};

class LongPressDescriptions {
  static String getDescription(String key) {
    return longPressDescriptions[key] ?? 'No description available.';
  }
}
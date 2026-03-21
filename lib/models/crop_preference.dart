/// All supported crop types shown in the onboarding preference dialog.
/// Updated to match the specific Philippine lowland crops from our data.
const List<String> allCrops = [
  'Rice (Wet Season)',
  'Rice (Dry Season)',
  'White Corn',
  'Squash',
  'Pechay',
  'Upo (Bottle Gourd)',
  'Eggplant',
  'Tomato',
  'Watermelon',
  'Banana',
];

/// Maps each crop type to the equipment tool-type categories relevant to it,
/// based on standard Philippine farming practices and the lowland crop calendar.
const Map<String, List<String>> cropToolTypes = {
  'Rice (Wet Season)': [
    'Floating Tiller (Pagong)', // Crucial for flooded muddy paddies during the wet season
    'Hand Tractor (Kuliglig)', 
    'Machine', // Threshers, water pumps
    'Hand Tool', // Sickles, bolos
    'Harvester (Halimaw)', 
    'Rice Mill (Gilingan)',
  ],
  'Rice (Dry Season)': [
    'Tractor', // 4-wheel tractors are better suited for dry land prep
    'Implements', // Rotavators, plows
    'Hand Tractor (Kuliglig)', 
    'Machine', // Water pumps are highly critical during the dry season
    'Hand Tool', 
    'Harvester (Halimaw)', 
    'Rice Mill (Gilingan)',
  ],
  'White Corn': [
    'Tractor', 
    'Implements', 
    'Hand Tractor (Kuliglig)', 
    'Machine', // Corn shellers, pumps
    'Hand Tool', 
    'Harvester (Halimaw)', // Corn harvesters
  ],
  'Squash': [
    'Hand Tractor (Kuliglig)', 
    'Tractor', 
    'Implements', 
    'Machine', 
    'Hand Tool',
  ],
  'Pechay': [
    'Hand Tractor (Kuliglig)', // For making raised beds quickly
    'Machine', // Sprinklers, knapsack sprayers
    'Hand Tool', // Rakes, hoes, trowels (heavy machinery is overkill here)
  ],
  'Upo (Bottle Gourd)': [
    'Hand Tractor (Kuliglig)', 
    'Machine', 
    'Hand Tool', // Heavily reliant on hand tools for building trellises
  ],
  'Eggplant': [
    'Hand Tractor (Kuliglig)', 
    'Tractor', 
    'Implements', 
    'Machine', 
    'Hand Tool',
  ],
  'Tomato': [
    'Hand Tractor (Kuliglig)', 
    'Tractor', 
    'Implements', 
    'Machine', 
    'Hand Tool',
  ],
  'Watermelon': [
    'Tractor', 
    'Implements', 
    'Hand Tractor (Kuliglig)', 
    'Machine', // Water pumps are vital for concentrating sugars in the dry season
    'Hand Tool',
  ],
  'Banana': [
    'Hand Tool', // Bolos and spades for digging holes and desuckering
    'Machine', // Knapsack sprayers for disease control
    'Hand Tractor (Kuliglig)', // Used with trailers for hauling harvests
  ],
};

/// Returns the union of all tool-type categories for the given selected crops.
/// Equipment whose [category] is in this set should be tagged "Recommended".
Set<String> recommendedToolTypes(List<String> selectedCrops) {
  final result = <String>{};
  for (final crop in selectedCrops) {
    // We use ?? [] as a fallback in case an older saved crop name 
    // (like 'Squash/Upo') is passed into the new mapping.
    result.addAll(cropToolTypes[crop] ?? []);
  }
  return result;
}

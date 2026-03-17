/// All supported crop types shown in the onboarding preference dialog.
const List<String> allCrops = [
  'Rice (Wet)',
  'Rice (Dry)',
  'White Corn',
  'Squash/Upo',
  'Leafy/Small Vegetables',
  'Watermelon',
];

/// Maps each crop type to the equipment tool-type categories relevant to it,
/// based on the onboarding logic reference table.
const Map<String, List<String>> cropToolTypes = {
  'Rice (Wet)': [
    'Floating Tiller', 'Hand Tractor', 'Machine', 'Hand Tool', 'Harvester (Halimaw)', 'Rice Mill',
  ],
  'Rice (Dry)': [
    'Tractor', 'Implements', 'Hand Tractor', 'Machine', 'Hand Tool', 'Harvester (Halimaw)', 'Rice Mill',
  ],
  'White Corn': [
    'Tractor', 'Implements', 'Hand Tractor', 'Machine', 'Hand Tool', 'Harvester (Halimaw)',
  ],
  'Squash/Upo': [
    'Hand Tractor', 'Tractor', 'Implements', 'Machine', 'Hand Tool',
  ],
  'Leafy/Small Vegetables': [
    'Hand Tractor', 'Machine', 'Hand Tool',
  ],
  'Watermelon': [
    'Tractor', 'Implements', 'Hand Tractor', 'Machine', 'Hand Tool',
  ],
};

/// Returns the union of all tool-type categories for the given selected crops.
/// Equipment whose [category] is in this set should be tagged "Recommended".
Set<String> recommendedToolTypes(List<String> selectedCrops) {
  final result = <String>{};
  for (final crop in selectedCrops) {
    result.addAll(cropToolTypes[crop] ?? []);
  }
  return result;
}

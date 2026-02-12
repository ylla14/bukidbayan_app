import 'package:bukidbayan_app/models/equipment.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/spec_row.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';


class ProductSpecs extends StatelessWidget {
  final Equipment item;

  const ProductSpecs({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final specs = <SpecRow>[];

    // Always show category
    specs.add(SpecRow(title: 'Category', value: item.category ?? 'Unknown'));

    // Conditionally show only if not null
    if (item.brand != null) specs.add(SpecRow(title: 'Brand', value: item.brand!));
    if (item.yearModel != null) specs.add(SpecRow(title: 'Year Model', value: item.yearModel!));
    if (item.power != null) specs.add(SpecRow(title: 'Power', value: item.power!));
    if (item.fuelType != null) specs.add(SpecRow(title: 'Fuel Type', value: item.fuelType!));
    if (item.condition != null) specs.add(SpecRow(title: 'Condition', value: item.condition!));
    if (item.attachments != null) specs.add(SpecRow(title: 'Attachments', value: item.attachments!));
    if (item.operatorIncluded != null) {
      specs.add(SpecRow(
          title: 'Operator Included?',
          value: item.operatorIncluded! ? 'Yes' : 'No'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Technical Specifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ...specs,
        ],
      ),
    );
  }
}

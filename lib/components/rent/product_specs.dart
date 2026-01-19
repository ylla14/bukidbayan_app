import 'package:bukidbayan_app/widgets/spec_row.dart';
import 'package:flutter/material.dart';
import '../../../mock_data/rent_items.dart';

class ProductSpecs extends StatelessWidget {
  final RentItem item;

  const ProductSpecs({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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
          SpecRow(title: 'Category', value: item.category),
          SpecRow(title: 'Brand', value: item.brand ?? '---'),
          SpecRow(title:'Year Model', value: item.yearModel ?? '---'),
          SpecRow(title: 'Power', value: item.power ?? '---'),
          SpecRow(title: 'Fuel Type', value: item.fuelType ?? '---'),
          SpecRow(title: 'Condition', value: item.condition ?? '---'),
          SpecRow(title: 'Attachments', value: item.attachments ?? '---'),
          SpecRow(
            title: 'Operator Included?',
            value: item.operatorIncluded == null
                ? '---'
                : (item.operatorIncluded! ? 'Yes' : 'No'),
          ),
        ],
      ),
    );
  }
}

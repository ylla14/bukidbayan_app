import 'package:flutter/material.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/mock_data/rent_items.dart';


class RentItemExpandable extends StatelessWidget {
  final RentItem item;
  const RentItemExpandable({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            item.imageUrl.first,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title + Category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            // Price aligned to the right
            Text(
                  '₱${item.price} ${_getRateSuffix(item.rentRate)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
          ],
        ),
        trailing: const Icon(Icons.expand_more),
        children: [
          const Divider(),
          if (item.availableFrom != null && item.availableTo != null)
            _detailRow('Availability', '${item.availableFrom} – ${item.availableTo}'),
          if (item.brand != null) _detailRow('Brand', item.brand!),
          if (item.yearModel != null) _detailRow('Year Model', item.yearModel!),
          if (item.operatorIncluded != null)
            _detailRow('Operator Included', item.operatorIncluded! ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
  String _getRateSuffix(String rentRate) {
    switch (rentRate.toLowerCase()) {
      case 'per hour':
        return '/hour';
      case 'per day':
        return '/day';
      case 'per week':
        return '/week';
      case 'per month':
        return '/month';
      default:
        return '';
    }
  }
}


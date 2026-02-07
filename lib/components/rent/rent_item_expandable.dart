import 'package:bukidbayan_app/models/equipment.dart';
import 'package:flutter/material.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';

class RentItemExpandable extends StatelessWidget {
  final Equipment item;
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
        child: SizedBox(
          width: 60,
          height: 60,
          child: _buildImage(item.imageUrls.first),
        ),
      ),
       title: Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // LEFT SIDE: NAME + CATEGORY (WRAPS PROPERLY)
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.category ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    ),

    const SizedBox(width: 8),

    // RIGHT SIDE: PRICE (FIXED WIDTH, NO OVERFLOW)
    Text(
      '₱${item.price} ${_getRateSuffix(item.rentalUnit)}',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.right,
    ),
  ],
),


        trailing: const Icon(Icons.expand_more),
        children: [
          const Divider(),
          if (item.availableFrom != null && item.availableUntil != null)
            _detailRow('Availability', '${item.availableFrom} – ${item.availableUntil}'),
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

  // Add this helper function inside RentItemExpandable
Widget _buildImage(String imageUrl) {
  bool isNetworkUrl(String url) => url.startsWith('http://') || url.startsWith('https://');
  bool isAssetUrl(String url) => url.startsWith('assets/');

  if (isNetworkUrl(imageUrl)) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
        ),
      ),
    );
  } else if (isAssetUrl(imageUrl)) {
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
        ),
      ),
    );
  } else {
    // fallback
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.agriculture, size: 40, color: Colors.grey),
      ),
    );
  }
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

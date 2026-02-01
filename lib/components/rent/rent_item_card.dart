import 'package:bukidbayan_app/widgets/availability_chip.dart';
import 'package:flutter/material.dart';

class RentItemCard extends StatelessWidget {
  final String title;
  final String price;
  final String? ownerName;
  final String imageUrl;
  final String rentalUnit;
  final bool isAvailable;

  const RentItemCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.price,
    this.ownerName,
    required this.rentalUnit,
    required this.isAvailable,

  });

  bool _isNetworkUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');
  bool _isAssetUrl(String url) => url.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // IMAGE
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildImage()),

                  // AVAILABILITY CHIP
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AvailabilityChip(isAvailable: isAvailable)
                  ),
                ],
              ),
            ),
          ),


          // DETAILS
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),

                const SizedBox(height: 4),

                // PRICE ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$price',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getRateSuffix(rentalUnit),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'est.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (_isNetworkUrl(imageUrl)) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stack) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
      );
    } else if (_isAssetUrl(imageUrl)) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.agriculture, size: 50, color: Colors.grey),
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
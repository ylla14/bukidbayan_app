import 'package:bukidbayan_app/widgets/availability_chip.dart';
import 'package:flutter/material.dart';

class RentItemCard extends StatelessWidget {
  final String title;
  final String price;
  final String? ownerName;
  final String imageUrl;
  final String rentalUnit;
  final bool isAvailable;
  final bool isPending;
  final bool isRecommended;
  final double? rating;        // NEW
  final int? reviewCount;      // NEW

  const RentItemCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.price,
    this.ownerName,
    required this.rentalUnit,
    required this.isAvailable,
    this.isPending = false,
    this.isRecommended = false,
    this.rating,               // NEW
    this.reviewCount,          // NEW
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
                    child: AvailabilityChip(
                      isAvailable: isAvailable,
                      isPending: isPending,
                    ),
                  ),

                  // RECOMMENDED BADGE
                  if (isRecommended)
                    Positioned(
                    bottom: 8, // changed from top: 8
                    left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.eco_rounded,
                                color: Colors.white, size: 11),
                            SizedBox(width: 3),
                            Text(
                              'Recommended',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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

// PRICE + RATING ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Price
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _getRateSuffix(rentalUnit),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),

                    const Spacer(),

                    // Rating
                    Icon(
                      (rating != null && rating! > 0)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 15,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating != null && rating! > 0
                          ? rating!.toStringAsFixed(1)
                          : 'N/A',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (reviewCount != null) ...[
                      const SizedBox(width: 2),
                      Text(
                        '(${reviewCount})',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
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
      case 'per kg':
        return '/kg';
      case 'per hectare':
        return '/ha';
      default:
        return '';
    }
  } 
}
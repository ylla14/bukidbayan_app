import 'package:flutter/material.dart';

class RentItemCard extends StatelessWidget {
  final String title;
  final String price;
  final String imageUrl;

  const RentItemCard({super.key, required this.title, required this.imageUrl, required this.price});

  // Helper to check if URL is a real image URL (Cloudinary, http/https)
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // Helper to check if URL is an asset path
  bool _isAssetUrl(String url) {
    return url.startsWith('assets/');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: _buildImage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "est.", // small indicator
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            )
          ),
        ],
      ),
    );
  }

  // Build appropriate image widget based on URL type
  Widget _buildImage() {
    // If it's a Cloudinary or network URL
    if (_isNetworkUrl(imageUrl)) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.grey,
              ),
            ),
          );
        },
      );
    }
    // If it's an asset path
    else if (_isAssetUrl(imageUrl)) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 50,
                color: Colors.grey,
              ),
            ),
          );
        },
      );
    }
    // Fallback for placeholder or invalid URLs
    else {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(
            Icons.agriculture,
            size: 50,
            color: Colors.grey,
          ),
        ),
      );
    }
  }
}

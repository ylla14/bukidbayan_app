import 'package:flutter/material.dart';

class ProductImageCarousel extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final Function(int) onPageChanged;
  final Function(String) onImageTap;

  const ProductImageCarousel({
    super.key,
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onImageTap,
  });

  // Helper to check if URL is a network URL (Cloudinary, http/https)
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // Helper to check if URL is an asset path
  bool _isAssetUrl(String url) {
    return url.startsWith('assets/');
  }

  // Build appropriate image widget based on URL type
  Widget _buildImage(String imageUrl) {
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
                size: 100,
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
                size: 100,
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
            size: 100,
            color: Colors.grey,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: images.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, index) => GestureDetector(
              onTap: () => onImageTap(images[index]),
              child: _buildImage(images[index]),
            ),
          ),

          Positioned(
            bottom: 12,
            child: Row(
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 10 : 8,
                  height: currentIndex == index ? 10 : 8,
                  decoration: BoxDecoration(
                    color: currentIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

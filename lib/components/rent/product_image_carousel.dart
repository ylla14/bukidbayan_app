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
              // child: Image.network(images[index], fit: BoxFit.cover),
              child: Image.asset(images[index], fit: BoxFit.cover),
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

import 'package:flutter/material.dart';

class CampaignCoverImage extends StatelessWidget {
  final String imagePath;
  final bool isAssetImage;
  final BoxFit fit;

  const CampaignCoverImage({
    super.key,
    required this.imagePath,
    required this.isAssetImage,
    this.fit = BoxFit.cover,
  });

  bool _isRemoteUrl(String path) {
    final uri = Uri.tryParse(path.trim());
    return uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
  }

  bool _isDataUri(String path) {
    final uri = Uri.tryParse(path.trim());
    return uri != null && uri.scheme.toLowerCase() == 'data';
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: 36, color: Colors.grey.shade500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedPath = imagePath.trim();
    if (trimmedPath.isEmpty) {
      return _buildFallback();
    }

    if (isAssetImage) {
      return Image.asset(
        trimmedPath,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    if (_isRemoteUrl(trimmedPath)) {
      return Image.network(
        trimmedPath,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    if (_isDataUri(trimmedPath)) {
      try {
        final bytes = UriData.parse(trimmedPath).contentAsBytes();
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    }

    return _buildFallback();
  }
}

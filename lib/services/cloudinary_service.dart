import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class CloudinaryService {
  // Cloudinary Configuration
  static const String CLOUD_NAME = 'ddgxxpdt9';

  static const String UPLOAD_PRESET = 'bukidbayan_upload';

  // Cloudinary upload URL
  static const String UPLOAD_URL =
      'https://api.cloudinary.com/v1_1/$CLOUD_NAME/image/upload';

  /// Upload a single image to Cloudinary
  /// Returns the secure URL of the uploaded image
  Future<String> uploadImage(XFile imageFile) async {
    try {
      // Read image bytes
      final Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await imageFile.readAsBytes();
      } else {
        imageBytes = await File(imageFile.path).readAsBytes();
      }

      // Convert to base64 for upload
      final base64Image = base64Encode(imageBytes);
      final imageData = 'data:image/jpeg;base64,$base64Image';

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(UPLOAD_URL));

      // Add upload preset
      request.fields['upload_preset'] = UPLOAD_PRESET;

      // Add the image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageFile.name,
        ),
      );

      // Add tags for better organization
      request.fields['tags'] = 'bukidbayan,equipment';

      // Add folder organization
      request.fields['folder'] = 'bukidbayan/equipment';

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Return the secure URL
        final secureUrl = responseData['secure_url'] as String;

        print('Image uploaded successfully: $secureUrl');
        return secureUrl;
      } else {
        throw Exception(
          'Cloudinary upload failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload multiple images to Cloudinary
  /// Returns a list of secure URLs
  /// Shows upload progress through optional callback
  Future<List<String>> uploadMultipleImages(
    List<XFile> imageFiles, {
    Function(int current, int total)? onProgress,
  }) async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      try {
        // Notify progress
        if (onProgress != null) {
          onProgress(i + 1, imageFiles.length);
        }

        final url = await uploadImage(imageFiles[i]);
        uploadedUrls.add(url);

        print('Uploaded ${i + 1}/${imageFiles.length}: ${imageFiles[i].name}');
      } catch (e) {
        print('Error uploading image ${imageFiles[i].name}: $e');
        // Continue with other images even if one fails
      }
    }

    return uploadedUrls;
  }

  /// Delete an image from Cloudinary
  /// Note: Deletion requires authentication, so this would need
  /// to be implemented server-side or with API keys
  /// For now, unused images can be managed from Cloudinary console
  Future<void> deleteImage(String imageUrl) async {
    // Extract public_id from URL
    // This requires API key and secret (server-side operation)
    // For free tier, you can manually delete from Cloudinary console

    print('Delete image from Cloudinary console: $imageUrl');

    // TODO: Implement server-side deletion with Cloud Functions
    // or use Cloudinary's Admin API with proper authentication
  }

  /// Get optimized image URL with transformations
  /// Cloudinary allows on-the-fly image transformations
  String getOptimizedImageUrl(
    String originalUrl, {
    int? width,
    int? height,
    String? quality = 'auto',
    String? format = 'auto',
  }) {
    // Extract upload path from URL
    final uploadIndex = originalUrl.indexOf('/upload/');
    if (uploadIndex == -1) return originalUrl;

    // Build transformation string
    final transformations = <String>[];

    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    if (quality != null) transformations.add('q_$quality');
    if (format != null) transformations.add('f_$format');

    final transformString = transformations.join(',');

    // Insert transformations into URL
    final beforeUpload = originalUrl.substring(0, uploadIndex + 8);
    final afterUpload = originalUrl.substring(uploadIndex + 8);

    return '$beforeUpload$transformString/$afterUpload';
  }

  /// Get thumbnail URL (smaller size for lists/grids)
  String getThumbnailUrl(String originalUrl) {
    return getOptimizedImageUrl(
      originalUrl,
      width: 400,
      height: 300,
      quality: 'auto',
      format: 'auto',
    );
  }

  /// Get full-size optimized URL (for detail views)
  String getFullSizeUrl(String originalUrl) {
    return getOptimizedImageUrl(
      originalUrl,
      width: 1200,
      quality: 'auto',
      format: 'auto',
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class CloudinaryService {
  static const String CLOUD_NAME = 'ddgxxpdt9';
  static const String UPLOAD_PRESET = 'bukidbayan_upload';
  static const String _BASE_URL =
      'https://api.cloudinary.com/v1_1/$CLOUD_NAME';

  // ── Detect video by extension ──────────────────────────────
  static bool _isVideo(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(ext);
  }

  // ── Correct MIME type per extension ───────────────────────
  static String _mimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'avi':  return 'video/x-msvideo';
      case 'mkv':  return 'video/x-matroska';
      case 'webm': return 'video/webm';
      case 'm4v':  return 'video/x-m4v';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      default:     return 'image/jpeg';
    }
  }

  /// Upload a single image OR video to Cloudinary.
  /// Automatically routes to /image/upload or /video/upload.
  /// Returns the secure URL.
  Future<String> uploadImage(XFile file) async {
    final isVideo = _isVideo(file.name);
    // ── Key fix: use /video/upload for videos, /image/upload for images ──
    final uploadUrl = '$_BASE_URL/${isVideo ? 'video' : 'image'}/upload';

    try {
      final Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = await file.readAsBytes();
      } else {
        fileBytes = await File(file.path).readAsBytes();
      }

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['upload_preset'] = UPLOAD_PRESET;
      request.fields['tags'] = 'bukidbayan,equipment';
      request.fields['folder'] = 'bukidbayan/equipment';

      // ── Correct MIME so Cloudinary doesn't reject the file ──
      final mime = _mimeType(file.name).split('/');
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: file.name,
          contentType: http.MediaType(mime[0], mime[1]),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final secureUrl = responseData['secure_url'] as String;
        print('✅ Cloudinary ${isVideo ? 'video' : 'image'} uploaded: $secureUrl');
        return secureUrl;
      } else {
        throw Exception(
          'Cloudinary upload failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to upload ${isVideo ? 'video' : 'image'}: $e');
    }
  }

  /// Upload multiple files (mix of images and videos).
  Future<List<String>> uploadMultipleImages(
    List<XFile> files, {
    Function(int current, int total)? onProgress,
  }) async {
    final List<String> uploadedUrls = [];
    for (int i = 0; i < files.length; i++) {
      if (onProgress != null) onProgress(i + 1, files.length);
      try {
        final url = await uploadImage(files[i]);
        uploadedUrls.add(url);
        print('Uploaded ${i + 1}/${files.length}: ${files[i].name}');
      } catch (e) {
        print('Error uploading ${files[i].name}: $e');
      }
    }
    return uploadedUrls;
  }

  Future<void> deleteImage(String imageUrl) async {
    print('Delete from Cloudinary console: $imageUrl');
  }

  String getOptimizedImageUrl(
    String originalUrl, {
    int? width,
    int? height,
    String? quality = 'auto',
    String? format = 'auto',
  }) {
    final uploadIndex = originalUrl.indexOf('/upload/');
    if (uploadIndex == -1) return originalUrl;
    final transformations = <String>[];
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    if (quality != null) transformations.add('q_$quality');
    if (format != null) transformations.add('f_$format');
    final transformString = transformations.join(',');
    final beforeUpload = originalUrl.substring(0, uploadIndex + 8);
    final afterUpload = originalUrl.substring(uploadIndex + 8);
    return '$beforeUpload$transformString/$afterUpload';
  }

  String getThumbnailUrl(String originalUrl) => getOptimizedImageUrl(
      originalUrl, width: 400, height: 300, quality: 'auto', format: 'auto');

  String getFullSizeUrl(String originalUrl) => getOptimizedImageUrl(
      originalUrl, width: 1200, quality: 'auto', format: 'auto');
}
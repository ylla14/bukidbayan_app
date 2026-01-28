import 'dart:convert';
import 'dart:io';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RentRequestService {
  final List<RentRequest> _requests = [];

  /// 🔹 Save image locally
  Future<String> saveFileLocally(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    print('📂 Saving file to directory: ${dir.path}');

    final path =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final newFile = await File(file.path).copy(path);

    print('✅ File saved at: $path');
    return newFile.path;
  }

  /// 🔹 CREATE / SAVE request
  Future<void> saveRequest(RentRequest request) async {
    _requests.add(request);

    final prefs = await SharedPreferences.getInstance();
    final savedRequests = prefs.getStringList('rentRequests') ?? [];
    savedRequests.add(jsonEncode(request.toMap()));
    await prefs.setStringList('rentRequests', savedRequests);
  }

  /// 🔹 READ ALL saved requests
  Future<List<RentRequest>> getAllRequests() async {
    if (_requests.isNotEmpty) return List.unmodifiable(_requests);

    final prefs = await SharedPreferences.getInstance();
    final savedRequests = prefs.getStringList('rentRequests') ?? [];
    final requests = savedRequests
        .map((e) => RentRequest.fromMap(jsonDecode(e)))
        .toList();
    _requests.addAll(requests);
    return List.unmodifiable(_requests);
  }

  /// 🔹 SAVE ALL requests (overwrite)
  Future<void> saveAllRequests(List<RentRequest> requests) async {
    _requests.clear();
    _requests.addAll(requests);

    final prefs = await SharedPreferences.getInstance();
    final savedRequests = requests.map((r) => jsonEncode(r.toMap())).toList();
    await prefs.setStringList('rentRequests', savedRequests);
  }

  /// 🔹 DELETE request by object reference
  Future<void> deleteRequest(RentRequest request) async {
    _requests.remove(request);

    // Delete from storage
    final prefs = await SharedPreferences.getInstance();
    final savedRequests = _requests.map((r) => jsonEncode(r.toMap())).toList();
    await prefs.setStringList('rentRequests', savedRequests);

    // Delete proof files if any
    if (request.landSizeProofPath != null) {
      final file = File(request.landSizeProofPath!);
      if (await file.exists()) await file.delete();
    }
    if (request.cropHeightProofPath != null) {
      final file = File(request.cropHeightProofPath!);
      if (await file.exists()) await file.delete();
    }
  }
}

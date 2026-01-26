import 'dart:convert';
import 'dart:io';

import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RentRequestService {
  /// Internal cache (optional)
  final List<RentRequest> _requests = [];

  /// 🔹 Save image locally
  Future<String> saveFileLocally(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final newFile = await File(file.path).copy(path);
    return newFile.path;
  }

  /// 🔹 CREATE / SAVE request
  Future<void> saveRequest(RentRequest request) async {
    // Save locally in memory
    _requests.add(request);

    // Save to SharedPreferences (local persistence)
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

  /// 🔹 FILTER requests by item
  Future<List<RentRequest>> getRequestsByItem(String itemId) async {
    final all = await getAllRequests();
    return all.where((r) => r.itemId == itemId).toList();
  }

  /// 🔹 DELETE request (if needed)
  Future<void> deleteRequest(RentRequest request) async {
    _requests.remove(request);
    final prefs = await SharedPreferences.getInstance();
    final savedRequests = prefs.getStringList('rentRequests') ?? [];
    savedRequests.removeWhere(
        (r) => RentRequest.fromMap(jsonDecode(r)).start == request.start);
    await prefs.setStringList('rentRequests', savedRequests);
  }
}

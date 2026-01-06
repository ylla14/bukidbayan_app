import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _usersKey = 'users';

  Future<void> signUp(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing users
    final String? usersJson = prefs.getString(_usersKey);
    List users = usersJson != null ? jsonDecode(usersJson) : [];

    // Check if email already exists
    final exists = users.any((u) => u['email'] == email);
    if (exists) {
      throw Exception('User already exists');
    }

    // Add new user
    users.add({
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    });

    // Save back
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  Future<bool> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) return false;

    List users = jsonDecode(usersJson);

    return users.any(
      (u) => u['email'] == email && u['password'] == password,
    );
  }

  Future<void> printAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) {
      print('No users found');
      return;
    }

    List users = jsonDecode(usersJson);
    print('=== STORED USERS ===');
    for (var u in users) {
      print(u);
    }
  }

}



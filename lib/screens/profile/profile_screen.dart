// profile_screen.dart
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    User? user = _auth.currentUser;
    if (user != null) {
      Map<String, dynamic>? data = await _authService.getUserData(user.uid);
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  void _showEditDialog(String field, String currentValue) {
    final TextEditingController controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${field.capitalize()}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field.capitalize(),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  User? user = _auth.currentUser;
                  if (user != null) {
                    await _authService.updateUserData(user.uid, {
                      field: controller.text.trim(),
                    });
                    
                    // Update display name if first or last name changed
                    if (field == 'firstName' || field == 'lastName') {
                      String firstName = field == 'firstName' 
                          ? controller.text.trim() 
                          : _userData?['firstName'] ?? '';
                      String lastName = field == 'lastName' 
                          ? controller.text.trim() 
                          : _userData?['lastName'] ?? '';
                      await user.updateDisplayName('$firstName $lastName');
                    }
                    
                    await _loadUserData();
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(onLogout: logout),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('No user logged in'))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Profile Header
                          Container(
                            padding: const EdgeInsets.all(24),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context).primaryColor.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    _getInitials(),
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Name
                                Text(
                                  user.displayName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Email
                                Text(
                                  user.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Profile Information Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profile Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Divider(height: 24),
                                  
                                  _buildInfoRow(
                                    icon: Icons.person,
                                    label: 'First Name',
                                    value: _userData?['firstName'] ?? 'N/A',
                                    onEdit: () => _showEditDialog(
                                      'firstName',
                                      _userData?['firstName'] ?? '',
                                    ),
                                  ),
                                  
                                  _buildInfoRow(
                                    icon: Icons.person_outline,
                                    label: 'Last Name',
                                    value: _userData?['lastName'] ?? 'N/A',
                                    onEdit: () => _showEditDialog(
                                      'lastName',
                                      _userData?['lastName'] ?? '',
                                    ),
                                  ),
                                  
                                  _buildInfoRow(
                                    icon: Icons.email,
                                    label: 'Email',
                                    value: user.email ?? 'N/A',
                                    onEdit: null, // Email can't be edited easily
                                  ),
                                  
                                  _buildInfoRow(
                                    icon: Icons.verified_user,
                                    label: 'Email Verified',
                                    value: user.emailVerified ? 'Yes' : 'No',
                                    onEdit: null,
                                  ),
                                  
                                  if (_userData?['createdAt'] != null)
                                    _buildInfoRow(
                                      icon: Icons.calendar_today,
                                      label: 'Member Since',
                                      value: _formatDate(_userData!['createdAt']),
                                      onEdit: null,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Action Buttons
                          if (!user.emailVerified)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    await user.sendEmailVerification();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Verification email sent!'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.email),
                                label: const Text('Verify Email'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 12),
                          
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (user.email != null) {
                                  try {
                                    await _authService.resetPassword(user.email!);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password reset email sent!'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.lock_reset),
                              label: const Text('Reset Password'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              color: Theme.of(context).primaryColor,
            ),
        ],
      ),
    );
  }

  String _getInitials() {
    String firstName = _userData?['firstName'] ?? '';
    String lastName = _userData?['lastName'] ?? '';
    
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();
    
    return initials.isEmpty ? '?' : initials;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date = timestamp.toDate();
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
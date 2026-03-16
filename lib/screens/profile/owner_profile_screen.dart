import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class OwnerProfileScreen extends StatefulWidget {
  final String ownerId;

  const OwnerProfileScreen({super.key, required this.ownerId});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    setState(() => _isLoading = true);
    final data = await _authService.getUserData(widget.ownerId);
    setState(() {
      _userData  = data;
      _isLoading = false;
    });
  }

  String _getInitials() {
    final first = (_userData?['firstName'] as String? ?? '');
    final last  = (_userData?['lastName']  as String? ?? '');
    final initials =
        (first.isNotEmpty ? first[0].toUpperCase() : '') +
        (last.isNotEmpty  ? last[0].toUpperCase()  : '');
    return initials.isEmpty ? '?' : initials;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = timestamp.toDate() as DateTime;
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('Owner not found.'))
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final firstName   = _userData?['firstName'] as String? ?? '';
    final lastName    = _userData?['lastName']  as String? ?? '';
    final fullName    = '$firstName $lastName'.trim();
    final phone       = _userData?['phoneNumber'] as String? ?? '';
    final address     = _userData?['address']     as String? ?? '';
    final locationType = _userData?['locationType'] as String? ?? '';
    final lat         = _userData?['latitude']    as num?;
    final lng         = _userData?['longitude']   as num?;
    final farmAddress = _userData?['farmAddress'] as String?;
    final farmLat     = _userData?['farmLatitude']  as num?;
    final farmLng     = _userData?['farmLongitude'] as num?;
    final createdAt   = _userData?['createdAt'];

    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          elevation: 0,
          backgroundColor: lightColorScheme.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [lightColorScheme.primary, lightColorScheme.secondary],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20, right: -30,
                    child: Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Text(
                            _getInitials(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fullName.isNotEmpty ? fullName : 'Unknown Owner',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Member since ${_formatDate(createdAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Content ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // ── Contact info card ──────────────────────────────────
                _buildCard(
                  title: 'Contact Information',
                  children: [
                    if (phone.isNotEmpty)
                      _buildRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: phone,
                      ),
                    if (address.isNotEmpty)
                      _buildRow(
                        icon: Icons.home_work_rounded,
                        label: 'Address',
                        value: address,
                      ),
                    if (locationType.isNotEmpty)
                      _buildRow(
                        icon: Icons.location_on_rounded,
                        label: 'Location Type',
                        value: locationType,
                      ),
                  ],
                ),

                // ── Farm info card ─────────────────────────────────────
                if (farmAddress != null && farmAddress.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    title: 'Farm Field',
                    children: [
                      _buildRow(
                        icon: Icons.grass_rounded,
                        label: 'Farm Address',
                        value: farmAddress,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    // Don't render the card if there's nothing to show
    final nonEmpty = children.where((w) => w is! SizedBox).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String   label,
    required String   value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
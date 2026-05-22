import 'package:bukidbayan_app/components/admin/admin_card.dart';
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatefulWidget {
  final FirebaseAuth? authOverride;
  final PreferredSizeWidget? appBarOverride;
  final Widget? drawerOverride;
  /// True when the logged-in user is the co-op account.
  /// Only co-ops should see this screen.
  final bool isCoop;

  const AdminScreen({
    super.key,
    this.authOverride,
    this.appBarOverride,
    this.drawerOverride,
    this.isCoop = false,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  FirebaseAuth? _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget.authOverride;
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (_) {
        _auth = null;
      }
    }
  }

  Future<void> logout() async {
    if (_auth == null) return;
    await _auth!.signOut();
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightColorScheme.primary.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: lightColorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      cardTheme: Theme.of(context).cardTheme.copyWith(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
    );

    if (!widget.isCoop) {
      // Non-co-ops should not see this screen
      return Theme(
        data: adminTheme,
        child: Scaffold(
          appBar: widget.appBarOverride ?? const CustomAppBar(),
          drawer: widget.drawerOverride ?? CustomDrawer(onLogout: logout),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Restricted Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ang admin page ay para lamang sa co-op accounts.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Theme(
      data: adminTheme,
      child: Scaffold(
        appBar: widget.appBarOverride ?? const CustomAppBar(),
        drawer: widget.drawerOverride ?? CustomDrawer(onLogout: logout),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: lightColorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pamahalaan ang iyong kooperatiba at campaigns',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Guide Card
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildGuideCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin Features',
                    description:
                        'Manage campaigns, monitor activity, and control platform settings from this dashboard.',
                  ),
                ),

                // Admin Menu Section
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Pangunahing Aksyon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                ),

                // admin cards
                AdminCard(
                  icon: Icons.campaign_outlined,
                  title: 'Campaign Management',
                  description: 'Manage, approve, and monitor campaigns',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming soon: Campaign Management'),
                      ),
                    );
                  },
                ),

                AdminCard(
                  icon: Icons.people_outline,
                  title: 'User Management',
                  description: 'View and manage user accounts',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming soon: User Management'),
                      ),
                    );
                  },
                ),

                AdminCard(
                  icon: Icons.analytics_outlined,
                  title: 'Analytics & Reports',
                  description: 'View detailed statistics and reports',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming soon: Analytics'),
                      ),
                    );
                  },
                ),

                AdminCard(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  description: 'Configure platform settings and preferences',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming soon: Settings'),
                      ),
                    );
                  },
                ),

                // Additional Section
                // Padding(
                //   padding: const EdgeInsets.only(top: 12, bottom: 12),
                //   child: Text(
                //     'Sistema',
                //     style: TextStyle(
                //       fontSize: 16,
                //       fontWeight: FontWeight.w700,
                //       color: Colors.grey[800],
                //     ),
                //   ),
                // ),

                // AdminCard(
                //   icon: Icons.notifications_outlined,
                //   title: 'Notifications',
                //   description: 'Manage system notifications and alerts',
                //   onTap: () {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text('Coming soon: Notifications'),
                //       ),
                //     );
                //   },
                // ),

                // AdminCard(
                //   icon: Icons.support_agent_outlined,
                //   title: 'Support & Help',
                //   description: 'Access support resources and documentation',
                //   onTap: () {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text('Coming soon: Support'),
                //       ),
                //     );
                //   },
                // ),

                // Bottom spacing
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
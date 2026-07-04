import 'package:bukidbayan_app/services/strike_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> {
  final _db      = FirebaseFirestore.instance;
  final _strike  = StrikeService();
  final _search  = TextEditingController();

  bool _flaggedOnly = false;
  String _query     = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isBlocked(Map<String, dynamic> d) {
    final until = (d['blockedUntil'] as Timestamp?)?.toDate();
    return until != null && DateTime.now().isBefore(until);
  }

  String _displayName(Map<String, dynamic> d) {
    final first = (d['firstName'] as String? ?? '').trim();
    final last  = (d['lastName']  as String? ?? '').trim();
    if (first.isEmpty && last.isEmpty) return 'Unknown';
    return '$first $last'.trim();
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  bool _matchesSearch(Map<String, dynamic> d) {
    if (_query.isEmpty) return true;
    final q    = _query.toLowerCase();
    final name = _displayName(d).toLowerCase();
    final phone = (d['phoneNumber'] as String? ?? '').toLowerCase();
    return name.contains(q) || phone.contains(q);
  }

  // ── Action dialogs ─────────────────────────────────────────────────────────

  Future<void> _showWarnDialog(String uid, String name) async {
    final controller = TextEditingController();
    final messenger  = ScaffoldMessenger.of(context);
    final confirmed  = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Warn $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will increment their warning count and mark them as delinquent.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Issue Warning'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final reason = controller.text.trim();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a reason.')),
      );
      return;
    }
    try {
      await _strike.issueAdminWarning(
        targetUid: uid,
        reason:    reason,
        adminUid:  FirebaseAuth.instance.currentUser?.uid,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Warning issued to $name.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showSuspendDialog(String uid, String name) async {
    final reasonCtrl = TextEditingController();
    final messenger  = ScaffoldMessenger.of(context);
    int   days       = 7;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Suspend $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The user will not be able to rent equipment until the suspension ends.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text('Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [7, 14, 30].map((d) {
                  return ChoiceChip(
                    label: Text('$d days'),
                    selected: days == d,
                    onSelected: (_) => setSt(() => days = d),
                    selectedColor: Colors.red.shade100,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Suspend'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a reason.')),
      );
      return;
    }
    try {
      await _strike.issueAdminSuspension(
        targetUid: uid,
        days:      days,
        reason:    reason,
        adminUid:  FirebaseAuth.instance.currentUser?.uid,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('$name suspended for $days days.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showClearDialog(String uid, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Record for $name'),
        content: const Text(
          'This will reset strikes, warnings, suspension, and the delinquent flag. This cannot be undone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Record'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _strike.clearDelinquency(targetUid: uid);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Record cleared for $name.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Detail bottom sheet ────────────────────────────────────────────────────

  void _showUserDetail(String uid, Map<String, dynamic> data) {
    final name        = _displayName(data);
    final blocked     = _isBlocked(data);
    final isDelinquent= (data['isDelinquent'] as bool?) ?? false;
    final strikes     = (data['strikeCount']  as int?)  ?? 0;
    final warnings    = (data['warningCount'] as int?)  ?? 0;
    final lastReason  = data['lastDelinquencyReason'] as String?;
    final blockedUntil= data['blockedUntil']  as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name + status chips
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (blocked)
                    _chip('Suspended', Colors.red),
                  if (!blocked && isDelinquent)
                    _chip('Delinquent', Colors.orange),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                data['phoneNumber'] as String? ?? '',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('Strikes', '$strikes', Colors.red),
                  _stat('Warnings', '$warnings', Colors.orange),
                  _stat('Joined', _formatDate(data['createdAt'] as Timestamp?),
                      Colors.blue),
                ],
              ),

              if (blocked) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Suspended until ${_formatDate(blockedUntil)}',
                    style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              if (lastReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last reason',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(lastReason,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],

              // Report history
              const SizedBox(height: 20),
              const Text('Report History',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('reports')
                    .where('renterId', isEqualTo: uid)
                    .orderBy('createdAt', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Text('No reports on record.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13));
                  }
                  return Column(
                    children: docs.map((doc) {
                      final r  = doc.data() as Map<String, dynamic>;
                      final ts = r['createdAt'] as Timestamp?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _reasonLabel(r['reason'] as String?),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  if ((r['details'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    Text(
                                      r['details'] as String,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              _formatDate(ts),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: const Text('Warn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade400),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showWarnDialog(uid, name);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Suspend'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade400),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSuspendDialog(uid, name);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade400),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showClearDialog(uid, name);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _chip(String label, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      );

  String _reasonLabel(String? reason) {
    switch (reason) {
      case 'damaged_equipment'    : return 'Damaged Equipment';
      case 'late_return'          : return 'Late Return';
      case 'missing_parts'        : return 'Missing Parts / Accessories';
      case 'misuse'               : return 'Misuse of Equipment';
      case 'cancel_after_approval': return 'Cancel After Approval';
      case 'admin_warning'        : return 'Admin Warning';
      case 'admin_suspension'     : return 'Admin Suspension';
      default                     : return reason ?? 'Other';
    }
  }

  // ── User list tile ─────────────────────────────────────────────────────────

  Widget _buildUserTile(String uid, Map<String, dynamic> data) {
    final name        = _displayName(data);
    final phone       = data['phoneNumber'] as String? ?? '—';
    final strikes     = (data['strikeCount']  as int?) ?? 0;
    final warnings    = (data['warningCount'] as int?) ?? 0;
    final isDelinquent= (data['isDelinquent'] as bool?) ?? false;
    final blocked     = _isBlocked(data);
    final blockedUntil= data['blockedUntil'] as Timestamp?;

    final hasFlag = blocked || isDelinquent || strikes > 0 || warnings > 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: blocked
              ? Colors.red.shade200
              : isDelinquent
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
          width: blocked || isDelinquent ? 1.5 : 1,
        ),
      ),
      color: blocked
          ? Colors.red.shade50
          : isDelinquent
              ? Colors.orange.shade50
              : Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: blocked
              ? Colors.red.shade100
              : isDelinquent
                  ? Colors.orange.shade100
                  : lightColorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: blocked
                  ? Colors.red.shade700
                  : isDelinquent
                      ? Colors.orange.shade700
                      : lightColorScheme.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (blocked)
              _chip('Suspended', Colors.red)
            else if (isDelinquent)
              _chip('Delinquent', Colors.orange),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(phone,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (hasFlag) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (strikes > 0)
                    _miniStat('${strikes}S', Colors.red),
                  if (warnings > 0) ...[
                    const SizedBox(width: 4),
                    _miniStat('${warnings}W', Colors.orange),
                  ],
                  if (blocked && blockedUntil != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      'Until ${_formatDate(blockedUntil)}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _showUserDetail(uid, data),
      ),
    );
  }

  Widget _miniStat(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('User Management'),
        titleTextStyle: TextStyle(
          color: lightColorScheme.onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        iconTheme: IconThemeData(color: lightColorScheme.onPrimary),
      ),
      body: Column(
        children: [
          // Search + filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Flagged only',
                          style: TextStyle(fontSize: 12)),
                      selected: _flaggedOnly,
                      onSelected: (v) =>
                          setState(() => _flaggedOnly = v),
                      selectedColor: Colors.orange.shade100,
                      checkmarkColor: Colors.orange.shade700,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data?.docs ?? [];

                final filtered = allDocs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;

                  // Hide co-op / admin accounts from the list
                  if (d['IAmACoop'] == true) return false;

                  if (_flaggedOnly) {
                    final hasStrikes  = ((d['strikeCount']  as int?) ?? 0) > 0;
                    final hasWarnings = ((d['warningCount'] as int?) ?? 0) > 0;
                    final isDelinquent= (d['isDelinquent'] as bool?) ?? false;
                    final blocked     = _isBlocked(d);
                    if (!hasStrikes && !hasWarnings &&
                        !isDelinquent && !blocked) {
                      return false;
                    }
                  }

                  return _matchesSearch(d);
                }).toList();

                // Sort: blocked first, then delinquent, then by name
                filtered.sort((a, b) {
                  final da = a.data() as Map<String, dynamic>;
                  final db = b.data() as Map<String, dynamic>;
                  final aBlocked = _isBlocked(da) ? 0 : 1;
                  final bBlocked = _isBlocked(db) ? 0 : 1;
                  if (aBlocked != bBlocked) return aBlocked - bBlocked;
                  final aDelinq = ((da['isDelinquent'] as bool?) ?? false) ? 0 : 1;
                  final bDelinq = ((db['isDelinquent'] as bool?) ?? false) ? 0 : 1;
                  if (aDelinq != bDelinq) return aDelinq - bDelinq;
                  return _displayName(da).compareTo(_displayName(db));
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _flaggedOnly
                          ? 'No flagged users found.'
                          : 'No users found.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final doc  = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildUserTile(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

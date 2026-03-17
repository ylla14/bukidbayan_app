import 'package:bukidbayan_app/screens/migration_page.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  CollectionReference? get _notifCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items');
  }

  Future<void> _markRead(String docId) async {
    await _notifCollection?.doc(docId).update({'read': true});
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final col = _notifCollection;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(color: lightColorScheme.onPrimary),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: col == null
          ? const Center(child: Text('Please sign in to view notifications.'))
          : StreamBuilder<QuerySnapshot>(
              stream: col.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications yet!',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final type = (data['type'] as String?) ?? '';
                    final isWeather = type == 'weather_alert';
                    final isShifted = type == 'booking_shifted';
                    final canCancel = (data['canCancel'] as bool?) ?? false;
                    final requestId = data['requestId'] as String?;
                    final isRead = (data['read'] as bool?) ?? false;
                    final title = (data['title'] as String?) ?? 'Notification';
                    final body = (data['body'] as String?) ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;

                    Future<void> handleCancel() async {
                      if (!isRead) _markRead(doc.id);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel Booking?'),
                          content: const Text(
                              'This will cancel your rescheduled booking. '
                              'No strike will be recorded. This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Keep It'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Yes, Cancel'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await FirebaseFirestore.instance
                            .collection('rentRequests')
                            .doc(requestId)
                            .update({
                          'status': 'canceled',
                          'cancelledDueToShift': true,
                          'declineReason':
                              'Cancelled by renter due to booking delay from a late return.',
                        });
                        await _notifCollection
                            ?.doc(doc.id)
                            .update({'canCancel': false});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Booking cancelled.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }

                    // ── Booking-shifted tile (has visible cancel button) ───
                    if (isShifted) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.orange.shade50
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded,
                                      color: Colors.orange.shade700, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(createdAt),
                                    style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(body,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade900)),
                              if (canCancel && requestId != null) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel_outlined,
                                        size: 16),
                                    label: const Text('Cancel Booking (No Penalty)'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(
                                          color: Colors.red.shade400),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                    onPressed: handleCancel,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    // ── Standard tile ──────────────────────────────────────
                    return ListTile(
                      tileColor: isRead
                          ? null
                          : lightColorScheme.primary.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      leading: CircleAvatar(
                        backgroundColor: isWeather
                            ? Colors.amber.shade100
                            : Colors.blue.shade50,
                        child: Icon(
                          isWeather
                              ? Icons.warning_amber_rounded
                              : Icons.notifications,
                          color: isWeather
                              ? Colors.amber.shade800
                              : Colors.blue,
                        ),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _timeAgo(createdAt),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () async {
                        if (!isRead) _markRead(doc.id);
                        await showDialog<void>(
                          context: context,
                          builder: (dlgCtx) => AlertDialog(
                            title: Text(title),
                            content: Text(body),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dlgCtx),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: lightColorScheme.primary,
        child: const Icon(Icons.settings, size: 18),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MigrationScreen()),
          );
        },
      ),
    );
  }
}

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
                    final isWeather = (data['type'] as String?) == 'weather_alert';
                    final isRead = (data['read'] as bool?) ?? false;
                    final title = (data['title'] as String?) ?? 'Notification';
                    final body = (data['body'] as String?) ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;

                    return ListTile(
                      tileColor: isRead ? null : lightColorScheme.primary.withValues(alpha: 0.05),
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
                          color: isWeather ? Colors.amber.shade800 : Colors.blue,
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
  final canCancel = (data['canCancel'] as bool?) ?? false;
  final requestId = data['requestId'] as String?;
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (canCancel && requestId != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Cancel Booking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cancel Booking?'),
                  content: const Text(
                    'This will cancel your rescheduled booking. This cannot be undone.'),
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
              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('rentRequests')
                    .doc(requestId)
                    .update({
                  'status': 'canceled',
                  'declineReason': 'Cancelled by renter after maintenance reschedule.',
                });
                // Mark notification as no longer cancellable
                await _notifCollection?.doc(doc.id).update({'canCancel': false});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Booking cancelled.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
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

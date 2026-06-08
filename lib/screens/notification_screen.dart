import 'package:bukidbayan_app/screens/migration_page.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
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
    return _firestore.collection('notifications').doc(uid).collection('items');
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
                    final isMaintReschedule = type == 'maintenance_reschedule';
                    final isMaintCancel = type == 'maintenance_cancel';
                    final isActionCard =
                        isShifted || isMaintReschedule || isMaintCancel;
                    final canCancel = (data['canCancel'] as bool?) ?? false;
                    final canAccept = (data['canAccept'] as bool?) ?? false;
                    final requestId = data['requestId'] as String?;
                    final ownerId = data['ownerId'] as String?;
                    final isRead = (data['read'] as bool?) ?? false;
                    final title = (data['title'] as String?) ?? 'Notification';
                    final body = (data['body'] as String?) ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final newStart = (data['newStart'] as Timestamp?)?.toDate();
                    final newEnd   = (data['newEnd']   as Timestamp?)?.toDate();

                    Future<void> notifyOwner(
                      String ownerUid,
                      String ownerTitle,
                      String ownerBody,
                    ) async {
                      await _firestore
                          .collection('notifications')
                          .doc(ownerUid)
                          .collection('items')
                          .add({
                            'type': 'renter_response',
                            'title': ownerTitle,
                            'body': ownerBody,
                            'read': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                    }

                    Future<void> handleAccept() async {
                      if (!isRead) _markRead(doc.id);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Tanggapin ang Bagong Schedule?'),
                          content: const Text(
                            'Makukumpirma nito ang na-reschedule na mga petsa ng booking. '
                            'Mananatiling approved ang iyong booking.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Hindi pa'), // BLT123: TL ENG
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Oo, Tanggapin'), // BLT123: TL ENG
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        DateTime? originalStart;
                        DateTime? originalEnd;
                        if (requestId != null) {
                          final reqSnap = await FirebaseFirestore.instance
                              .collection('rentRequests')
                              .doc(requestId)
                              .get();
                          final rd = reqSnap.data();
                          originalStart = (rd?['originalStart'] as Timestamp?)?.toDate();
                          originalEnd   = (rd?['originalEnd']   as Timestamp?)?.toDate();
                        }
                        await FirebaseFirestore.instance
                            .collection('rentRequests')
                            .doc(requestId)
                            .update({'maintenanceRescheduleAccepted': true});
                        await _notifCollection?.doc(doc.id).update({
                          'canCancel': false,
                          'canAccept': false,
                        });
                        if (ownerId != null) {
                          final renterName =
                              _auth.currentUser?.displayName ?? 'Ang renter';
                          String dateDetails = '';
                          if (originalStart != null && originalEnd != null &&
                              newStart != null && newEnd != null) {
                            String fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
                            dateDetails =
                                '\n\nOrihinal na petsa: ${fmt(originalStart)} – ${fmt(originalEnd)}'
                                '\nBagong petsa: ${fmt(newStart)} – ${fmt(newEnd)}';
                          }
                          await notifyOwner(
                            ownerId,
                            '✅ Tinanggap ng Renter ang Bagong Schedule',
                            'Tinanggap ni $renterName ang na-reschedule na mga petsa ng booking.$dateDetails',
                          );
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tinanggap ang bagong schedule.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    }

                    Future<void> handleCancel() async {
                      if (!isRead) _markRead(doc.id);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Kanselahin ang Booking?'),
                          content: const Text(
                            'Ito ay magkakansela ng iyong na-reschedule na booking. '
                            'Walang paglabag na itatala. Hindi ito maaaring bawiin.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Hindi pa'), // BLT123: TL ENG
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Oo, Kanselahin'), // BLT123: TL ENG
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        DateTime? originalStart;
                        DateTime? originalEnd;
                        if (requestId != null) {
                          final reqSnap = await FirebaseFirestore.instance
                              .collection('rentRequests')
                              .doc(requestId)
                              .get();
                          final rd = reqSnap.data();
                          originalStart = (rd?['originalStart'] as Timestamp?)?.toDate();
                          originalEnd   = (rd?['originalEnd']   as Timestamp?)?.toDate();
                        }
                        final declineReason = isMaintReschedule
                            ? 'Kinansela ng renter dahil sa pag-reschedule ng booking mula sa maintenance ng kagamitan.'
                            : 'Kinansela ng renter dahil sa pagkaantala ng booking mula sa mahuling pagbabalik.';
                        await FirebaseFirestore.instance
                            .collection('rentRequests')
                            .doc(requestId)
                            .update({
                              'status': 'canceled',
                              'cancelledDueToShift': true,
                              'declineReason': declineReason,
                            });
                        await _notifCollection?.doc(doc.id).update({
                          'canCancel': false,
                          'canAccept': false,
                        });
                        if (ownerId != null) {
                          final renterName =
                              _auth.currentUser?.displayName ?? 'Ang renter';
                          String dateDetails = '';
                          if (originalStart != null && originalEnd != null &&
                              newStart != null && newEnd != null) {
                            String fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
                            dateDetails =
                                '\n\nOrihinal na petsa: ${fmt(originalStart)} – ${fmt(originalEnd)}'
                                '\nNa-reschedule na petsa: ${fmt(newStart)} – ${fmt(newEnd)}';
                          }
                          await notifyOwner(
                            ownerId,
                            '❌ Kinansela ng Renter ang Na-reschedule na Booking',
                            'Kinansela ni $renterName ang kanilang booking pagkatapos itong ma-reschedule.$dateDetails',
                          );
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kinansela ang booking.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }

                    // ── Action cards (shifted / maintenance reschedule / cancel) ──
                    if (isActionCard) {
                      final icon = (isShifted || isMaintReschedule)
                          ? (isShifted
                                ? Icons.schedule_rounded
                                : Icons.build_rounded)
                          : Icons.build_rounded;

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
                                  Icon(
                                    icon,
                                    color: Colors.orange.shade700,
                                    size: 18,
                                  ),
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
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              if ((canCancel || canAccept) &&
                                  requestId != null) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (canAccept)
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 16,
                                          ),
                                          label: const Text('Tanggapin'), // BLT123: TL ENG
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.green.shade700,
                                            side: BorderSide(
                                              color: Colors.green.shade400,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: handleAccept,
                                        ),
                                      ),
                                    if (canAccept && canCancel)
                                      const SizedBox(width: 8),
                                    if (canCancel)
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('Kanselahin'), // BLT123: TL ENG
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade700,
                                            side: BorderSide(
                                              color: Colors.red.shade400,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: handleCancel,
                                        ),
                                      ),
                                  ],
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
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
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
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        if (!isRead) _markRead(doc.id);
                        // ── New-request notification → go straight to the request page ──
                        if (type == 'new_request' && requestId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RequestSentPage(requestId: requestId),
                            ),
                          );
                          return;
                        }

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

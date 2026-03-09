import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MigrationScreen extends StatefulWidget {
  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();
  bool _isProcessing = false;
  String _status = '';

  // Which of the next 7 days are toggled as "bad weather" for injection
  late final List<DateTime> _testDays = List.generate(7, (i) {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day).add(Duration(days: i));
  });
  final Set<int> _selectedDayIndices = {};

  // ── Equipment Date Migration ─────────────────────────────────────────────
  DateTime _availableFrom  = DateTime(2026, 3, 8);
  DateTime _availableUntil = DateTime(2026, 3, 31);
  String? _dateFilterOwnerId;   // null = all owners
  String? _dateFilterStatus;    // null = all statuses
  String _dateMigrationStatus = '';
  bool _isDateMigrating = false;

  static const List<String?> _statusOptions = [null, 'available', 'unavailable', 'under_maintenance'];
  static const List<String> _statusLabels  = ['All', 'Available', 'Unavailable', 'Under Maintenance'];

  Future<void> _runEquipmentDateMigration() async {
    if (_availableUntil.isBefore(_availableFrom)) {
      setState(() => _dateMigrationStatus = '❌ "Until" date must be after "From" date.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Date Update'),
        content: Text(
          'This will overwrite availableFrom and availableUntil on '
          '${_dateFilterStatus == null ? 'ALL' : '"$_dateFilterStatus"'} equipment'
          '${_dateFilterOwnerId != null ? ' for owner "$_dateFilterOwnerId"' : ''}.\n\n'
          'From:  ${_availableFrom.toLocal().toString().split(' ')[0]}\n'
          'Until: ${_availableUntil.toLocal().toString().split(' ')[0]}\n\n'
          'This cannot be automatically undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDateMigrating = true;
      _dateMigrationStatus = 'Fetching documents...';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      Query query = firestore.collection('equipment');
      if (_dateFilterOwnerId != null && _dateFilterOwnerId!.trim().isNotEmpty) {
        query = query.where('ownerId', isEqualTo: _dateFilterOwnerId!.trim());
      }
      if (_dateFilterStatus != null) {
        query = query.where('status', isEqualTo: _dateFilterStatus);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      setState(() => _dateMigrationStatus = 'Found ${docs.length} doc(s). Updating...');

      if (docs.isEmpty) {
        setState(() => _dateMigrationStatus = '⚠️ No documents matched the filter. Nothing updated.');
        return;
      }

      const batchSize = 400;
      int updated = 0;

      for (int i = 0; i < docs.length; i += batchSize) {
        final chunk = docs.sublist(i, (i + batchSize).clamp(0, docs.length));
        final batch = firestore.batch();
        for (final doc in chunk) {
          batch.update(doc.reference, {
            'availableFrom':  Timestamp.fromDate(_availableFrom),
            'availableUntil': Timestamp.fromDate(_availableUntil),
            'updatedAt':      FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        updated += chunk.length;
        setState(() => _dateMigrationStatus = 'Updated $updated / ${docs.length}...');
      }

      setState(() {
        _dateMigrationStatus =
            '✅ Done! $updated equipment doc(s) updated.\n'
            'availableFrom  → ${_availableFrom.toLocal().toString().split(' ')[0]}\n'
            'availableUntil → ${_availableUntil.toLocal().toString().split(' ')[0]}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$updated equipment doc(s) updated successfully.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _dateMigrationStatus = '❌ Failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Date migration failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isDateMigrating = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _availableFrom : _availableUntil,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _availableFrom = picked;
      } else {
        _availableUntil = picked;
      }
    });
  }

  // ── Existing migration helpers ────────────────────────────────────────────

  Future<void> _runMigration() async {
    setState(() {
      _isProcessing = true;
      _status = 'Starting migration...';
    });

    try {
      await _firestoreService.migrateEquipmentToMultiPeriods();
      setState(() {
        _status = '✅ Migration completed successfully!\n\nOld fields preserved for rollback.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Migration completed! Old data preserved for rollback.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _status = '❌ Migration failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Migration failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _runRollback() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Rollback'),
        content: const Text(
          'This will restore the old single-date format and remove the new multi-period format. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ROLLBACK'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _status = 'Rolling back migration...';
    });

    try {
      await _firestoreService.rollbackEquipmentMigration();
      setState(() {
        _status = '✅ Rollback completed successfully!\n\nOld format restored.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rollback completed! Old format restored.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _status = '❌ Rollback failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rollback failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool anyProcessing = _isProcessing || _isDateMigrating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Migration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Section 1: Multi-period migration ─────────────────────────
            const Text(
              'Equipment Availability Migration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will convert equipment from single-date to multi-period availability.',
            ),
            const SizedBox(height: 8),
            const Text(
              '✅ Safe: Old data is preserved\n'
              '✅ Reversible: Can rollback anytime\n'
              '⚠️ One-time: Already migrated items skipped',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: anyProcessing ? null : _runMigration,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Processing...'),
                      ],
                    )
                  : const Text('RUN MIGRATION', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: anyProcessing ? null : _runRollback,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text(
                'ROLLBACK MIGRATION',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),

            const SizedBox(height: 24),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(_status, style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // ── Section 2: Weather test tools ─────────────────────────────
            const Text(
              'Weather System — Test Tools',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inject a mock forecast so you can test flagging and notifications '
              'without waiting for real severe weather.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),

            const Text(
              'Select days to mark as severe weather:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_testDays.length, (i) {
                final d = _testDays[i];
                final label = i == 0
                    ? 'Today'
                    : i == 1
                        ? 'Tomorrow'
                        : '${d.month}/${d.day}';
                final selected = _selectedDayIndices.contains(i);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  selectedColor: Colors.amber.shade200,
                  checkmarkColor: Colors.amber.shade900,
                  onSelected: anyProcessing
                      ? null
                      : (val) => setState(() {
                            if (val) _selectedDayIndices.add(i);
                            else _selectedDayIndices.remove(i);
                          }),
                );
              }),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: anyProcessing || _selectedDayIndices.isEmpty
                  ? null
                  : () async {
                      setState(() {
                        _isProcessing = true;
                        _status = 'Injecting mock bad weather...';
                      });
                      try {
                        final dates = _selectedDayIndices.map((i) => _testDays[i]).toList();
                        await _weatherService.injectTestBadWeather(dates);
                        setState(() {
                          _status =
                              '✅ Mock weather injected for ${dates.length} day(s).\n'
                              'Affected bookings have been flagged and notifications written.\n'
                              'Restart the app or navigate to Notifications to see results.';
                        });
                      } catch (e) {
                        setState(() => _status = '❌ Inject failed: $e');
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
              icon: const Icon(Icons.thunderstorm, color: Colors.white),
              label: const Text('INJECT BAD WEATHER', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: anyProcessing
                  ? null
                  : () async {
                      setState(() {
                        _isProcessing = true;
                        _status = 'Clearing weather test data...';
                      });
                      try {
                        await _weatherService.clearTestWeather();
                        setState(() {
                          _selectedDayIndices.clear();
                          _status =
                              '✅ Test data cleared.\n'
                              'Cache deleted — next app open will fetch real weather.\n'
                              'All weather flags on active bookings removed.';
                        });
                      } catch (e) {
                        setState(() => _status = '❌ Clear failed: $e');
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
              icon: const Icon(Icons.clear_all, color: Colors.teal),
              label: const Text('CLEAR WEATHER TEST DATA', style: TextStyle(color: Colors.teal)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.teal),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // ── Section 3: Equipment date update ──────────────────────────
            const Text(
              'Equipment Date Update',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bulk-set availableFrom and availableUntil on equipment documents. '
              'Optionally filter by status or owner.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Date pickers
            Row(
              children: [
                Expanded(
                  child: _DatePickerTile(
                    label: 'Available From',
                    date: _availableFrom,
                    onTap: anyProcessing ? null : () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerTile(
                    label: 'Available Until',
                    date: _availableUntil,
                    onTap: anyProcessing ? null : () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status filter
            const Text('Filter by Status', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_statusOptions.length, (i) {
                final val = _statusOptions[i];
                final selected = _dateFilterStatus == val;
                return ChoiceChip(
                  label: Text(_statusLabels[i]),
                  selected: selected,
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green.shade800,
                  onSelected: anyProcessing
                      ? null
                      : (_) => setState(() => _dateFilterStatus = val),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Owner ID filter (optional)
            TextField(
              enabled: !anyProcessing,
              decoration: const InputDecoration(
                labelText: 'Filter by Owner ID (optional)',
                hintText: 'Leave blank to update all owners',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (v) => _dateFilterOwnerId = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: anyProcessing ? null : _runEquipmentDateMigration,
              icon: _isDateMigrating
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.calendar_today, color: Colors.white),
              label: Text(
                _isDateMigrating ? 'Updating...' : 'UPDATE EQUIPMENT DATES',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 16),
            if (_dateMigrationStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _dateMigrationStatus,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  const _DatePickerTile({
    required this.label,
    required this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 6),
                Text(formatted, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
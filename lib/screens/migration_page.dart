import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
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
      setState(() {
        _status = '❌ Migration failed: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _runRollback() async {
    // Confirm with user
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Rollback'),
        content: const Text(
          'This will restore the old single-date format and remove the new multi-period format. Are you sure?'
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
      setState(() {
        _status = '❌ Rollback failed: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rollback failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Migration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Equipment Availability Migration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            // MIGRATE BUTTON
            ElevatedButton(
              onPressed: _isProcessing ? null : _runMigration,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Processing...'),
                      ],
                    )
                  : const Text(
                      'RUN MIGRATION',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
            
            const SizedBox(height: 12),
            
            // ROLLBACK BUTTON
            OutlinedButton(
              onPressed: _isProcessing ? null : _runRollback,
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
                  child: Text(
                    _status,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // ── Weather Test Section ─────────────────────────────────────
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

            // Day toggles
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
                  onSelected: _isProcessing
                      ? null
                      : (val) => setState(() {
                            if (val) {
                              _selectedDayIndices.add(i);
                            } else {
                              _selectedDayIndices.remove(i);
                            }
                          }),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Inject button
            ElevatedButton.icon(
              onPressed: _isProcessing || _selectedDayIndices.isEmpty
                  ? null
                  : () async {
                      setState(() {
                        _isProcessing = true;
                        _status = 'Injecting mock bad weather...';
                      });
                      try {
                        final dates = _selectedDayIndices
                            .map((i) => _testDays[i])
                            .toList();
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
              label: const Text(
                'INJECT BAD WEATHER',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Clear button
            OutlinedButton.icon(
              onPressed: _isProcessing
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
              label: const Text(
                'CLEAR WEATHER TEST DATA',
                style: TextStyle(color: Colors.teal),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
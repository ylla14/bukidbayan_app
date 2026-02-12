import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:flutter/material.dart';

class MigrationScreen extends StatefulWidget {
  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isProcessing = false;
  String _status = '';

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
          ],
        ),
      ),
    );
  }
}
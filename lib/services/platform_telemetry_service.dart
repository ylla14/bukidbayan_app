import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PlatformTelemetryService {
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  PlatformTelemetryService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('app_events');

  DocumentReference<Map<String, dynamic>> get _systemHealthCurrent =>
      _firestore.collection('system_health').doc('current');

  Future<void> logAppOpen({
    String source = 'app_startup',
    String? actorId,
  }) async {
    await logEvent(
      eventType: 'app_open',
      status: 'success',
      scope: 'app',
      source: source,
      actorId: actorId,
    );

    await _safeWrite(() async {
      await _systemHealthCurrent.set({
        'lastAppOpenAt': FieldValue.serverTimestamp(),
        'lastAppOpenClientAt': Timestamp.fromDate(DateTime.now()),
        'lastAppOpenSource': source,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> logLoginSuccess({
    required String? userId,
    required String identifierType,
  }) async {
    await logEvent(
      eventType: 'login',
      status: 'success',
      scope: 'auth',
      source: 'signin',
      actorId: userId,
      actorRole: 'user',
      metadata: {'identifierType': identifierType},
    );
  }

  Future<void> logLoginFailure({
    required String identifierType,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    await logEvent(
      eventType: 'login',
      status: 'failure',
      scope: 'auth',
      severity: 'warning',
      source: 'signin',
      metadata: {
        'identifierType': identifierType,
        'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      },
    );
  }

  Future<void> logBackgroundTaskResult({
    required String taskName,
    required bool success,
    String? message,
    Map<String, dynamic> metadata = const {},
  }) async {
    await logEvent(
      eventType: 'background_task',
      status: success ? 'success' : 'failure',
      scope: 'system',
      severity: success ? 'info' : 'warning',
      source: taskName,
      metadata: {
        'taskName': taskName,
        if (message != null && message.isNotEmpty) 'message': message,
        ...metadata,
      },
    );

    await _safeWrite(() async {
      await _systemHealthCurrent.set({
        'lastBackgroundTaskName': taskName,
        'lastBackgroundTaskStatus': success ? 'success' : 'failure',
        'lastBackgroundTaskAt': FieldValue.serverTimestamp(),
        'lastBackgroundTaskClientAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> recordHeartbeat({
    String source = 'app_startup',
    String status = 'healthy',
  }) async {
    await _safeWrite(() async {
      final heartbeatRef = _systemHealthCurrent
          .collection('heartbeats')
          .doc(DateTime.now().millisecondsSinceEpoch.toString());

      await _systemHealthCurrent.set({
        'status': status,
        'lastHeartbeatAt': FieldValue.serverTimestamp(),
        'lastHeartbeatClientAt': Timestamp.fromDate(DateTime.now()),
        'lastHeartbeatSource': source,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await heartbeatRef.set({
        'status': status,
        'source': source,
        'createdAt': FieldValue.serverTimestamp(),
        'capturedAt': Timestamp.fromDate(DateTime.now()),
        'platform': _platformLabel,
      });
    });
  }

  Future<void> logEvent({
    required String eventType,
    required String status,
    required String scope,
    String severity = 'info',
    String source = 'app',
    String? actorId,
    String actorRole = 'system',
    Map<String, dynamic> metadata = const {},
  }) async {
    await _safeWrite(() async {
      await _events.add({
        'eventType': eventType,
        'status': status,
        'scope': scope,
        'severity': severity,
        'source': source,
        'actorId': actorId,
        'actorRole': actorRole,
        'platform': _platformLabel,
        'metadata': metadata,
        'capturedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String get _platformLabel {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> _safeWrite(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Platform telemetry write skipped: $error');
    }
  }
}

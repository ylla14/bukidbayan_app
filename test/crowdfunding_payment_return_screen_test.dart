import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:bukidbayan_app/screens/crowdfunding_payment_return_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_payment_service.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

PaymentAttempt _attempt({
  required String status,
  String id = 'pa_test_1',
  String campaignId = 'campaign_test_1',
}) {
  final now = DateTime(2026, 6, 16, 12);
  return PaymentAttempt(
    id: id,
    campaignId: campaignId,
    createdByUid: 'backer-uid',
    createdByEmail: 'backer@example.com',
    donorName: 'Juan Dela Cruz',
    amount: 1200,
    provider: PaymentProvider.payMongoCheckout,
    paymentMethodTypes: const ['qrph'],
    status: status,
    createdAt: now,
    updatedAt: now,
    providerCheckoutId: 'cs_test_123',
    providerPaymentId: status == PaymentAttemptStatus.paid
        ? 'pay_test_123'
        : null,
  );
}

Future<void> _seedAttempt(
  FakeFirebaseFirestore firestore,
  PaymentAttempt attempt,
) async {
  await firestore
      .collection('campaigns')
      .doc(attempt.campaignId)
      .collection('payment_attempts')
      .doc(attempt.id)
      .set(attempt.toFirestore());
}

void main() {
  group('CrowdfundingPaymentReturnScreen', () {
    testWidgets('shows pending verification after a success redirect hint', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final attempt = _attempt(status: PaymentAttemptStatus.pendingCheckout);
      await _seedAttempt(firestore, attempt);

      await tester.pumpWidget(
        MaterialApp(
          home: CrowdfundingPaymentReturnScreen(
            campaignId: attempt.campaignId,
            attemptId: attempt.id,
            paymentStatusHint: 'success',
            paymentService: CrowdfundingPaymentService(firestore: firestore),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hinihintay ang kumpirmasyon ng bayad'), findsOneWidget);
      expect(
        find.textContaining('backend pa rin ang magpapasya'),
        findsOneWidget,
      );
      expect(find.textContaining('Attempt ID: ${attempt.id}'), findsOneWidget);
    });

    testWidgets('shows confirmed payment after backend marks attempt paid', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final attempt = _attempt(status: PaymentAttemptStatus.paid);
      await _seedAttempt(firestore, attempt);

      await tester.pumpWidget(
        MaterialApp(
          home: CrowdfundingPaymentReturnScreen(
            campaignId: attempt.campaignId,
            attemptId: attempt.id,
            paymentStatusHint: 'success',
            paymentService: CrowdfundingPaymentService(firestore: firestore),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nakumpirma na ang bayad'), findsOneWidget);
      expect(
        find.textContaining('Kasama na ito sa campaign totals'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Halaga: ${formatPeso(attempt.amount)}'),
        findsOneWidget,
      );
    });

    testWidgets('marks a cancelled redirect as a terminal cancelled attempt', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final attempt = _attempt(status: PaymentAttemptStatus.pendingCheckout);
      await _seedAttempt(firestore, attempt);

      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: attempt.createdByUid,
          email: attempt.createdByEmail,
          displayName: attempt.donorName,
        ),
      );

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('cancelCrowdfundingPaymentAttempt'));
        expect(request.headers['Authorization'], startsWith('Bearer '));

        await firestore
            .collection('campaigns')
            .doc(attempt.campaignId)
            .collection('payment_attempts')
            .doc(attempt.id)
            .update({
              'status': PaymentAttemptStatus.cancelled,
              'cancelledAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });

        return http.Response(
          '{"status":"cancelled"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CrowdfundingPaymentService(
        firestore: firestore,
        auth: auth,
        httpClient: client,
        functionUriBuilder: (_) =>
            Uri.parse('https://example.com/cancelCrowdfundingPaymentAttempt'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CrowdfundingPaymentReturnScreen(
            campaignId: attempt.campaignId,
            attemptId: attempt.id,
            paymentStatusHint: 'cancelled',
            paymentService: service,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Kinansela ang checkout'), findsOneWidget);
      expect(find.textContaining('walang nalikhang pledge'), findsOneWidget);
    });
  });
}

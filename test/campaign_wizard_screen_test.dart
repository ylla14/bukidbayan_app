import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_wizard_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCrowdfundingService extends CrowdfundingService {
  int saveDraftCalls = 0;
  Campaign? lastSavedDraft;

  @override
  Future<void> saveDraft(Campaign draft) async {
    saveDraftCalls += 1;
    lastSavedDraft = draft;
  }
}

class WizardRouteHost extends StatefulWidget {
  final CrowdfundingService service;
  final Campaign draft;

  const WizardRouteHost({
    super.key,
    required this.service,
    required this.draft,
  });

  @override
  State<WizardRouteHost> createState() => _WizardRouteHostState();
}

class _WizardRouteHostState extends State<WizardRouteHost> {
  Object? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Navigator.of(context).push(
        MaterialPageRoute<Object?>(
          builder: (_) => CampaignWizardScreen(
            existingDraft: widget.draft,
            serviceOverride: widget.service,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(_result == null ? 'launcher' : 'result:$_result'),
      ),
    );
  }
}

Campaign _draft() {
  return Campaign(
    id: 'draft_1',
    title: 'Solar Pump for Shared Use',
    creatorName: 'Tester',
    creatorEmail: 'tester@example.com',
    shortBlurb: 'Help fund a shared solar pump for irrigation.',
    description:
        'This campaign purchases a shared solar pump that co-op members can rent for irrigation support.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: 'Solar/Power',
    goalAmount: 50000,
    pledgedAmount: 0,
    backersCount: 0,
    endDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    rewards: const [],
    status: 'draft',
  );
}

void main() {
  testWidgets('app bar back saves draft and exits the wizard', (tester) async {
    final service = FakeCrowdfundingService();

    await tester.pumpWidget(
      MaterialApp(
        home: WizardRouteHost(service: service, draft: _draft()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Panimula'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    expect(service.saveDraftCalls, 1);
    expect(service.lastSavedDraft, isNotNull);
    expect(find.text('result:true'), findsOneWidget);
  });

  testWidgets('device back moves one step back instead of exiting', (
    tester,
  ) async {
    final service = FakeCrowdfundingService();

    await tester.pumpWidget(
      MaterialApp(
        home: CampaignWizardScreen(
          existingDraft: _draft(),
          serviceOverride: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pamagat ng Kampanya*'), findsOneWidget);

    await tester.tap(find.text('Susunod'));
    await tester.pumpAndSettle();

    expect(find.text('Maikling Buod*'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Pamagat ng Kampanya*'), findsOneWidget);
    expect(find.text('Maikling Buod*'), findsNothing);
  });
}

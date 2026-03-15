import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_wizard_form_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Campaign _baseDraft() {
  return Campaign(
    id: 'draft_1',
    title: 'Initial Draft Title',
    creatorName: 'Tester',
    creatorEmail: 'tester@example.com',
    shortBlurb: 'A short blurb that is valid',
    description:
        'A long description that should be longer than fifty chars for tests.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: 'Irrigation',
    goalAmount: 5000,
    pledgedAmount: 0,
    backersCount: 0,
    endDate: DateTime.now().add(const Duration(days: 20)),
    createdAt: DateTime.now(),
    rewards: const [],
    status: 'draft',
  );
}

CampaignWizardFormState _validState() {
  return CampaignWizardFormState(
    title: 'Solar Pump for Co-op',
    category: 'Solar/Power',
    isAssetImage: true,
    imagePath: 'assets/images/bg1.png',
    shortBlurb: 'Help us buy a shared solar pump for irrigation.',
    fullStory:
        'This campaign funds a shared solar-powered pump that farmers can rent through the co-op.',
    equipmentType: 'Pump',
    specs: const [
      MapEntry('Power', '2HP'),
      MapEntry('Flow rate', '50 L/min'),
      MapEntry('Voltage', '220V'),
    ],
    includedItemsRaw: 'Pump unit\nController\nMounting kit',
    hasVariants: true,
    variant: '2HP',
    variantNotes: 'Depends on supplier stock.',
    fundingGoalRaw: '50000',
    selectedEndDate: DateTime.now().add(const Duration(days: 30)),
    productionTimeline: 'Week 1 procurement, Week 2 delivery, Week 3 setup.',
    rewards: const [
      RewardTier(
        id: 'r1',
        title: 'Thank you',
        minPledge: 500,
        discountType: 'percent',
        discountValue: 5,
        usageLimit: 1,
        validityDays: 90,
      ),
    ],
    shippingCoverage: 'Local delivery',
    shippingCostHandling: 'included',
    shippingNotes: 'Delivered to co-op office.',
    warranty: 'Manufacturer warranty for one year.',
    spareParts: 'Replacement parts stocked locally.',
    risks: 'Supplier delays may happen.',
    safetyNotes: 'PPE required for operation.',
  );
}

void main() {
  group('CampaignWizardFormLogic.applyStepToDraft', () {
    test('updates basic info fields on step 0', () {
      final logic = CampaignWizardFormLogic();
      final updated = logic.applyStepToDraft(
        draft: _baseDraft(),
        step: 0,
        state: _validState(),
      );

      expect(updated.title, 'Solar Pump for Co-op');
      expect(updated.category, 'Solar/Power');
      expect(updated.image, 'assets/images/bg1.png');
      expect(updated.isAssetImage, isTrue);
      expect(updated.shortBlurb, _baseDraft().shortBlurb);
    });

    test(
      'parses included items and clears variants when disabled on step 3',
      () {
        final logic = CampaignWizardFormLogic();
        final state = _validState();
        final noVariantState = CampaignWizardFormState(
          title: state.title,
          category: state.category,
          isAssetImage: state.isAssetImage,
          imagePath: state.imagePath,
          shortBlurb: state.shortBlurb,
          fullStory: state.fullStory,
          equipmentType: state.equipmentType,
          specs: state.specs,
          includedItemsRaw: 'Item A\nItem B\n',
          hasVariants: false,
          variant: state.variant,
          variantNotes: state.variantNotes,
          fundingGoalRaw: state.fundingGoalRaw,
          selectedEndDate: state.selectedEndDate,
          productionTimeline: state.productionTimeline,
          rewards: state.rewards,
          shippingCoverage: state.shippingCoverage,
          shippingCostHandling: state.shippingCostHandling,
          shippingNotes: state.shippingNotes,
          warranty: state.warranty,
          spareParts: state.spareParts,
          risks: state.risks,
          safetyNotes: state.safetyNotes,
        );

        final updated = logic.applyStepToDraft(
          draft: _baseDraft(),
          step: 3,
          state: noVariantState,
        );

        expect(updated.includedItems, ['Item A', 'Item B']);
        expect(updated.chosenVariant, isNull);
        expect(updated.variantNotes, isNull);
      },
    );
  });

  group('CampaignWizardFormLogic.validateStep', () {
    test('returns error for invalid title on step 0', () {
      final logic = CampaignWizardFormLogic();
      final state = _validState();
      final invalidState = CampaignWizardFormState(
        title: 'Short',
        category: state.category,
        isAssetImage: state.isAssetImage,
        imagePath: state.imagePath,
        shortBlurb: state.shortBlurb,
        fullStory: state.fullStory,
        equipmentType: state.equipmentType,
        specs: state.specs,
        includedItemsRaw: state.includedItemsRaw,
        hasVariants: state.hasVariants,
        variant: state.variant,
        variantNotes: state.variantNotes,
        fundingGoalRaw: state.fundingGoalRaw,
        selectedEndDate: state.selectedEndDate,
        productionTimeline: state.productionTimeline,
        rewards: state.rewards,
        shippingCoverage: state.shippingCoverage,
        shippingCostHandling: state.shippingCostHandling,
        shippingNotes: state.shippingNotes,
        warranty: state.warranty,
        spareParts: state.spareParts,
        risks: state.risks,
        safetyNotes: state.safetyNotes,
      );

      final error = logic.validateStep(step: 0, state: invalidState);
      expect(error, isNotNull);
      expect(error, contains('pamagat'));
    });

    test('returns error when rewards are empty on step 5', () {
      final logic = CampaignWizardFormLogic();
      final state = _validState();
      final invalidState = CampaignWizardFormState(
        title: state.title,
        category: state.category,
        isAssetImage: state.isAssetImage,
        imagePath: state.imagePath,
        shortBlurb: state.shortBlurb,
        fullStory: state.fullStory,
        equipmentType: state.equipmentType,
        specs: state.specs,
        includedItemsRaw: state.includedItemsRaw,
        hasVariants: state.hasVariants,
        variant: state.variant,
        variantNotes: state.variantNotes,
        fundingGoalRaw: state.fundingGoalRaw,
        selectedEndDate: state.selectedEndDate,
        productionTimeline: state.productionTimeline,
        rewards: const [],
        shippingCoverage: state.shippingCoverage,
        shippingCostHandling: state.shippingCostHandling,
        shippingNotes: state.shippingNotes,
        warranty: state.warranty,
        spareParts: state.spareParts,
        risks: state.risks,
        safetyNotes: state.safetyNotes,
      );

      final error = logic.validateStep(step: 5, state: invalidState);
      expect(error, isNotNull);
      expect(error, contains('benepisyo'));
    });

    test('returns null for valid funding step', () {
      final logic = CampaignWizardFormLogic();
      final error = logic.validateStep(step: 4, state: _validState());
      expect(error, isNull);
    });
  });
}

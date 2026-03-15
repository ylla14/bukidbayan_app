import 'package:bukidbayan_app/models/campaign.dart';

class CampaignWizardFormState {
  final String title;
  final String category;
  final bool isAssetImage;
  final String imagePath;
  final String shortBlurb;
  final String fullStory;
  final String? equipmentType;
  final List<MapEntry<String, String>> specs;
  final String includedItemsRaw;
  final bool hasVariants;
  final String variant;
  final String variantNotes;
  final String fundingGoalRaw;
  final DateTime? selectedEndDate;
  final String productionTimeline;
  final List<RewardTier> rewards;
  final String? shippingCoverage;
  final String? shippingCostHandling;
  final String shippingNotes;
  final String warranty;
  final String spareParts;
  final String risks;
  final String safetyNotes;

  const CampaignWizardFormState({
    required this.title,
    required this.category,
    required this.isAssetImage,
    required this.imagePath,
    required this.shortBlurb,
    required this.fullStory,
    required this.equipmentType,
    required this.specs,
    required this.includedItemsRaw,
    required this.hasVariants,
    required this.variant,
    required this.variantNotes,
    required this.fundingGoalRaw,
    required this.selectedEndDate,
    required this.productionTimeline,
    required this.rewards,
    required this.shippingCoverage,
    required this.shippingCostHandling,
    required this.shippingNotes,
    required this.warranty,
    required this.spareParts,
    required this.risks,
    required this.safetyNotes,
  });

  int get goalAmount => int.tryParse(fundingGoalRaw) ?? 0;

  List<String> get includedItems => includedItemsRaw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String get includedItemsForValidation => includedItems.join(' ');
}

class CampaignWizardFormLogic {
  Campaign applyStepToDraft({
    required Campaign draft,
    required int step,
    required CampaignWizardFormState state,
  }) {
    switch (step) {
      case 0:
        return draft.copyWith(
          title: state.title.trim(),
          category: state.category,
          isAssetImage: state.isAssetImage,
          image: state.imagePath.trim(),
        );
      case 1:
        return draft.copyWith(
          shortBlurb: state.shortBlurb.trim(),
          description: state.fullStory.trim(),
        );
      case 2:
        return draft.copyWith(
          equipmentType: state.equipmentType,
          specs: Map.fromEntries(state.specs),
        );
      case 3:
        return draft.copyWith(
          includedItems: state.includedItems,
          chosenVariant: state.hasVariants ? state.variant.trim() : null,
          variantNotes: state.hasVariants ? state.variantNotes.trim() : null,
        );
      case 4:
        return draft.copyWith(
          goalAmount: state.goalAmount,
          endDate:
              state.selectedEndDate ??
              DateTime.now().add(const Duration(days: 30)),
          productionTimeline: state.productionTimeline.trim(),
        );
      case 5:
        return draft.copyWith(
          rewards: state.rewards,
          shippingCoverage: state.shippingCoverage,
          shippingCostHandling: state.shippingCostHandling,
          shippingNotes: state.shippingNotes.trim(),
        );
      case 6:
        return draft.copyWith(
          warranty: state.warranty.trim(),
          spareParts: state.spareParts.trim(),
        );
      case 7:
        return draft.copyWith(
          risks: state.risks.trim(),
          safetyNotes: state.safetyNotes.trim(),
        );
      default:
        return draft;
    }
  }

  String? validateStep({
    required int step,
    required CampaignWizardFormState state,
  }) {
    switch (step) {
      case 0:
        if (state.title.trim().length < 8) {
          return 'Ang pamagat ay dapat hindi bababa sa 8 character.';
        }
        if (state.imagePath.trim().isEmpty) {
          return 'Kailangan ang cover photo.';
        }
        return null;
      case 1:
        if (state.shortBlurb.trim().length < 10) {
          return 'Ang maikling buod ay dapat hindi bababa sa 10 character.';
        }
        if (state.fullStory.trim().length < 50) {
          return 'Ang buong paglalarawan ay dapat hindi bababa sa 50 character.';
        }
        return null;
      case 2:
        if (state.specs.length < 3) {
          return 'Maglagay ng hindi bababa sa 3 mahalagang detalye.';
        }
        return null;
      case 3:
        if (state.includedItemsForValidation.length < 10) {
          return 'Ang saklaw ng bibilhin ay dapat hindi bababa sa 10 character.';
        }
        return null;
      case 4:
        if (state.goalAmount < 1000) {
          return 'Ang target na pondo ay dapat hindi bababa sa 1,000.';
        }
        if (state.selectedEndDate == null ||
            state.selectedEndDate!.isBefore(DateTime.now())) {
          return 'Pumili ng petsa ng pagtatapos sa hinaharap.';
        }
        if (state.productionTimeline.trim().length < 10) {
          return 'Ang timeline ng pagpapatupad ay dapat hindi bababa sa 10 character.';
        }
        return null;
      case 5:
        if (state.rewards.isEmpty) {
          return 'Magdagdag ng hindi bababa sa isang antas ng benepisyo.';
        }
        if (state.shippingCoverage == null ||
            state.shippingCoverage!.trim().isEmpty) {
          return 'Kailangan ang saklaw ng delivery.';
        }
        if (state.shippingCostHandling == null ||
            state.shippingCostHandling!.trim().isEmpty) {
          return 'Kailangan kung paano isasama ang gastos sa delivery.';
        }
        return null;
      case 6:
        if (state.warranty.trim().length < 10) {
          return 'Ang warranty at suporta ay dapat hindi bababa sa 10 character.';
        }
        if (state.spareParts.trim().length < 10) {
          return 'Ang plano sa spare parts ay dapat hindi bababa sa 10 character.';
        }
        return null;
      default:
        return null;
    }
  }
}

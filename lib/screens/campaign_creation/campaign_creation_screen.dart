import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_wizard_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'steps/basic_info_step.dart';
import 'steps/description_step.dart';
import 'steps/funding_step.dart';
import 'steps/rewards_step.dart';
import 'steps/additional_info_step.dart';
import 'steps/review_step.dart';

class CampaignCreationScreen extends StatefulWidget {
  final Campaign? existingDraft;

  const CampaignCreationScreen({
    super.key,
    this.existingDraft,
  });

  @override
  State<CampaignCreationScreen> createState() => _CampaignCreationScreenState();
}

class _CampaignCreationScreenState extends State<CampaignCreationScreen> {
  late Widget _screenToShow;

  @override
  void initState() {
    super.initState();
    // Use the new wizard screen for draft-based flow
    _screenToShow = CampaignWizardScreen(existingDraft: widget.existingDraft);
  }

  @override
  Widget build(BuildContext context) {
    return _screenToShow;
  }
}

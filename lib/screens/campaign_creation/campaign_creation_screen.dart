import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_wizard_screen.dart';
import 'package:flutter/material.dart';

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

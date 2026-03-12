import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/widgets/reward_tier_form.dart';
import 'package:bukidbayan_app/widgets/step_progress_indicator.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_wizard_form_logic.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CampaignWizardScreen extends StatefulWidget {
  final Campaign? existingDraft;

  const CampaignWizardScreen({
    super.key,
    this.existingDraft,
  });

  @override
  State<CampaignWizardScreen> createState() => _CampaignWizardScreenState();
}

class _CampaignWizardScreenState extends State<CampaignWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  late Campaign _draft;
  final CampaignWizardFormLogic _formLogic = CampaignWizardFormLogic();

  // Form controllers - Step 1
  late TextEditingController _titleController;
  late TextEditingController _imagePathController;
  late bool _isAssetImage;
  String? _selectedCategory;

  // Form controllers - Step 2
  late TextEditingController _shortBlurbController;
  late TextEditingController _fullStoryController;

  // Form controllers - Step 3
  String? _selectedEquipmentType;
  List<MapEntry<String, String>> _specs = [];
  late TextEditingController _specKeyController;
  late TextEditingController _specValueController;

  // Form controllers - Step 4
  late TextEditingController _includedItemsController;
  bool _hasVariants = false;
  late TextEditingController _variantController;
  late TextEditingController _variantNotesController;

  // Form controllers - Step 5
  late TextEditingController _fundingGoalController;
  late TextEditingController _productionTimelineController;
  DateTime? _selectedEndDate;

  // Form controllers - Step 6
  List<RewardTier> _rewards = [];
  String? _selectedShippingCoverage;
  String? _selectedShippingCostHandling;
  late TextEditingController _shippingNotesController;

  // Form controllers - Step 7
  late TextEditingController _warrantyController;
  late TextEditingController _sparePartsController;

  // Form controllers - Step 8
  late TextEditingController _risksController;
  late TextEditingController _safetyNotesController;

  final List<String> _categoryOptions = [
    'Irrigation',
    'Crop Care',
    'Post-harvest',
    'Mechanized Tools',
    'Livestock',
    'Solar/Power',
    'Hand Tools',
    'Other',
  ];

  final List<String> _assetImageOptions = const [
    'assets/images/farmBg.jpg',
    'assets/images/bg1.png',
    'assets/images/loopyBg.jpg',
  ];

  final List<String> _equipmentTypes = [
    'Pump',
    'Sprayer',
    'Thresher/Sheller',
    'Solar equipment',
    'Hand tool',
    'Other',
  ];

  final List<String> _shippingCoverageOptions = [
    'Pickup',
    'Local delivery',
    'Nationwide delivery',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeDraft();
    _initializeControllers();
  }

  void _initializeDraft() {
    if (widget.existingDraft != null) {
      _draft = widget.existingDraft!;
    } else {
      _draft = Campaign(
        id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
        title: '',
        creatorName:
            FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous',
        creatorEmail: FirebaseAuth.instance.currentUser?.email,
        shortBlurb: '',
        description: '',
        isAssetImage: true,
        image: 'assets/images/farmBg.jpg',
        category: 'Irrigation',
        goalAmount: 0,
        pledgedAmount: 0,
        backersCount: 0,
        endDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        rewards: [],
        status: 'draft',
      );
    }
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: _draft.title);
    _imagePathController = TextEditingController(text: _draft.image);
    _isAssetImage = _draft.isAssetImage;
    // Validate category exists in options, default to first option if not
    _selectedCategory = _categoryOptions.contains(_draft.category)
        ? _draft.category
        : _categoryOptions.first;
    _shortBlurbController = TextEditingController(text: _draft.shortBlurb);
    _fullStoryController = TextEditingController(text: _draft.description);
    // Validate equipment type exists in options, default to first option if not
    _selectedEquipmentType = _equipmentTypes.contains(_draft.equipmentType)
        ? _draft.equipmentType
        : _equipmentTypes.first;
    _specs = _draft.specs.entries.toList();
    _specKeyController = TextEditingController();
    _specValueController = TextEditingController();
    _includedItemsController =
        TextEditingController(text: _draft.includedItems.join('\n'));
    _hasVariants = _draft.chosenVariant != null;
    _variantController = TextEditingController(text: _draft.chosenVariant ?? '');
    _variantNotesController =
        TextEditingController(text: _draft.variantNotes ?? '');
    _fundingGoalController =
        TextEditingController(text: _draft.goalAmount.toString());
    _productionTimelineController =
        TextEditingController(text: _draft.productionTimeline ?? '');
    _selectedEndDate = _draft.endDate;
    _rewards = _draft.rewards;
    // Validate shipping coverage exists in options, default to first option if not
    _selectedShippingCoverage = _shippingCoverageOptions.contains(_draft.shippingCoverage)
        ? _draft.shippingCoverage
        : _shippingCoverageOptions.first;
    // Validate shipping cost handling is valid, default if not
    _selectedShippingCostHandling = (_draft.shippingCostHandling == 'included' || _draft.shippingCostHandling == 'separate')
        ? _draft.shippingCostHandling
        : 'included';
    _shippingNotesController =
        TextEditingController(text: _draft.shippingNotes ?? '');
    _warrantyController = TextEditingController(text: _draft.warranty ?? '');
    _sparePartsController =
        TextEditingController(text: _draft.spareParts ?? '');
    _risksController = TextEditingController(text: _draft.risks ?? '');
    _safetyNotesController = TextEditingController(text: _draft.safetyNotes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imagePathController.dispose();
    _shortBlurbController.dispose();
    _fullStoryController.dispose();
    _specKeyController.dispose();
    _specValueController.dispose();
    _includedItemsController.dispose();
    _variantController.dispose();
    _variantNotesController.dispose();
    _fundingGoalController.dispose();
    _productionTimelineController.dispose();
    _shippingNotesController.dispose();
    _warrantyController.dispose();
    _sparePartsController.dispose();
    _risksController.dispose();
    _safetyNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    _updateDraftFromCurrentStep();
    try {
      await CrowdfundingService().saveDraft(_draft);
      if (mounted) {
        showConfirmSnackbar(
          context: context,
          title: 'Draft Saved',
          message: 'Your campaign draft has been saved.',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(
          context: context,
          title: 'Error',
          message: 'Failed to save draft: $e',
        );
      }
    }
  }

  Future<void> _publishCampaign() async {
    _updateDraftFromCurrentStep();

    setState(() => _isLoading = true);

    try {
      final service = CrowdfundingService();
      final errors = service.validateForPublish(_draft);
      
      if (errors.isNotEmpty) {
        if (mounted) {
          showErrorSnackbar(
            context: context,
            title: 'Cannot Publish',
            message: 'Please complete all required fields:\n${errors.join('\n')}',
          );
        }
        return;
      }

      await service.publishCampaign(_draft);
      if (mounted) {
        showConfirmSnackbar(
          context: context,
          title: 'Campaign Published!',
          message: 'Supporters can now pledge to help fund this tool.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(
          context: context,
          title: 'Error',
          message: 'Failed to publish: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateDraftFromCurrentStep() {
    _draft = _formLogic.applyStepToDraft(
      draft: _draft,
      step: _currentStep,
      state: _buildFormState(),
    );
  }

  CampaignWizardFormState _buildFormState() {
    return CampaignWizardFormState(
      title: _titleController.text,
      category: _selectedCategory ?? 'Irrigation',
      isAssetImage: _isAssetImage,
      imagePath: _imagePathController.text,
      shortBlurb: _shortBlurbController.text,
      fullStory: _fullStoryController.text,
      equipmentType: _selectedEquipmentType,
      specs: _specs,
      includedItemsRaw: _includedItemsController.text,
      hasVariants: _hasVariants,
      variant: _variantController.text,
      variantNotes: _variantNotesController.text,
      fundingGoalRaw: _fundingGoalController.text,
      selectedEndDate: _selectedEndDate,
      productionTimeline: _productionTimelineController.text,
      rewards: _rewards,
      shippingCoverage: _selectedShippingCoverage,
      shippingCostHandling: _selectedShippingCostHandling,
      shippingNotes: _shippingNotesController.text,
      warranty: _warrantyController.text,
      spareParts: _sparePartsController.text,
      risks: _risksController.text,
      safetyNotes: _safetyNotesController.text,
    );
  }

  String? _validateCurrentStep() {
    return _formLogic.validateStep(
      step: _currentStep,
      state: _buildFormState(),
    );
  }

  void _nextStep() {
    final stepError = _validateCurrentStep();
    if (stepError != null) {
      showErrorSnackbar(
        context: context,
        title: 'Complete Required Fields',
        message: stepError,
      );
      return;
    }
    _updateDraftFromCurrentStep();
    if (_currentStep < 7) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Basics();
      case 1:
        return _buildStep2Story();
      case 2:
        return _buildStep3Specs();
      case 3:
        return _buildStep4Included();
      case 4:
        return _buildStep5Funding();
      case 5:
        return _buildStep6Rewards();
      case 6:
        return _buildStep7Support();
      case 7:
        return _buildStep8Preview();
      default:
        return const SizedBox();
    }
  }

  // STEP 1: BASICS
  Widget _buildStep1Basics() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Create Campaign',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This campaign raises funds for a tool the co-op will buy and add to its rental pool.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Campaign Title*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _titleController,
            hint: 'e.g., Solar Water Pump for Co-op Rental',
            maxLength: 70,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'Keep it specific: tool name + purpose. Avoid "best" or "guaranteed".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Category*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            items: _categoryOptions
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedCategory = value);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick the closest match so people can find it easily.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Cover Photo*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Asset'),
                icon: Icon(Icons.image),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('URL'),
                icon: Icon(Icons.link),
              ),
            ],
            selected: {_isAssetImage},
            onSelectionChanged: (selection) {
              setState(() => _isAssetImage = selection.first);
            },
          ),
          const SizedBox(height: 12),
          if (_isAssetImage) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assetImageOptions.map((assetPath) {
                final selected = _imagePathController.text.trim() == assetPath;
                return ChoiceChip(
                  label: Text(assetPath.split('/').last),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _imagePathController.text = assetPath);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          CustomTextFormField(
            controller: _imagePathController,
            hint: _isAssetImage
                ? 'assets/images/farmBg.jpg'
                : 'https://example.com/my-image.jpg',
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            _isAssetImage
                ? 'Choose an app asset or type an asset path.'
                : 'Paste a direct image URL. Use a real photo whenever possible.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 2: STORY
  Widget _buildStep2Story() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Tell Your Story',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Help supporters understand why this tool matters.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Short Blurb*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _shortBlurbController,
            hint:
                'e.g., Help us buy a shared thresher so small farmers can reduce post-harvest losses.',
            maxLines: 2,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            '1–2 lines. What is it, who benefits, and why it matters.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Full Story*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _fullStoryController,
            hint: 'Tell your campaign story here...',
            maxLines: 8,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'Prompt tips:\n• What problem are you solving?\n• Who will use the tool and how?\n• How will renting work after purchase?\n• What impact will this create?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 3: SPECS
  Widget _buildStep3Specs() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Tool Specifications',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Clear specs reduce confusion and build trust.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Equipment Type*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedEquipmentType,
            items: _equipmentTypes
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedEquipmentType = value);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Specifications* (at least 3)',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _specs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _specs[index].key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _specs[index].value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        setState(() => _specs.removeAt(index));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomTextFormField(
                  controller: _specKeyController,
                  hint: 'e.g., Flow rate',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomTextFormField(
                  controller: _specValueController,
                  hint: 'e.g., 50 L/min',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_specKeyController.text.isNotEmpty &&
                      _specValueController.text.isNotEmpty) {
                    setState(() {
                      _specs.add(
                        MapEntry(
                          _specKeyController.text,
                          _specValueController.text,
                        ),
                      );
                      _specKeyController.clear();
                      _specValueController.clear();
                    });
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 4: WHAT'S INCLUDED
  Widget _buildStep4Included() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'What Will the Co-op Buy?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Be specific about what\'s included in the purchase.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'What\'s Included*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _includedItemsController,
            hint: '• 1 unit (tool name/model)\n• Accessories: hose/nozzle\n• Manual/training',
            maxLines: 4,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'List everything the co-op expects to receive.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            title: const Text('This tool has variants/options'),
            value: _hasVariants,
            onChanged: (value) {
              setState(() => _hasVariants = value ?? false);
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_hasVariants) ...[
            const SizedBox(height: 16),
            Text(
              'Chosen Variant*',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            CustomTextFormField(
              controller: _variantController,
              hint: 'e.g., 2HP motor version',
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),
            Text(
              'Variant Notes',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            CustomTextFormField(
              controller: _variantNotesController,
              hint: 'If final choice depends on supplier availability...',
              maxLines: 2,
              onChanged: (_) {},
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 5: FUNDING
  Widget _buildStep5Funding() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Funding & Timeline',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Set a realistic goal and what happens after the campaign ends.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Funding Goal (₱)*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _fundingGoalController,
            hint: 'e.g., 50000',
            keyboardType: TextInputType.number,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'Include tool cost + delivery + setup + a small buffer.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Campaign End Date*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                _selectedEndDate != null
                    ? '${_selectedEndDate!.toLocal().toString().split(' ')[0]} (${_selectedEndDate!.difference(DateTime.now()).inDays} days)'
                    : 'Select date',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedEndDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedEndDate = picked);
                }
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommended: 7–60 days from publish.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Production Timeline*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _productionTimelineController,
            hint: '• Week 1: order the tool\n• Week 2-3: delivery\n• Week 4: testing',
            maxLines: 4,
            onChanged: (_) {},
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 6: REWARDS & SHIPPING
  Widget _buildStep6Rewards() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Rewards & Delivery',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Rewards are rental discounts. The tool is delivered to the co-op.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Reward Tiers* (at least 1)',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rewards.length,
            itemBuilder: (context, index) {
              final reward = _rewards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reward.title,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₱${reward.minPledge} minimum | ${reward.discountValue.toStringAsFixed(reward.discountType == 'percent' ? 0 : 2)}${reward.discountType == 'percent' ? '%' : '₱'} discount',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton(
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                child: const Text('Edit'),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => RewardTierForm(
                                      initialTier: reward,
                                      onSave: (updatedTier) {
                                        setState(() {
                                          _rewards[index] = updatedTier;
                                        });
                                        Navigator.pop(context);
                                      },
                                      onCancel: () => Navigator.pop(context),
                                    ),
                                  );
                                },
                              ),
                              PopupMenuItem(
                                child: const Text('Delete'),
                                onTap: () {
                                  setState(() => _rewards.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => RewardTierForm(
                  onSave: (newTier) {
                    setState(() => _rewards.add(newTier));
                    Navigator.pop(context);
                  },
                  onCancel: () => Navigator.pop(context),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Reward Tier'),
          ),
          const SizedBox(height: 24),
          Text(
            'Tool Delivery to the Co-op',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shipping Coverage*',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedShippingCoverage,
            items: _shippingCoverageOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedShippingCoverage = value);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Shipping Cost Handling*',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              RadioListTile<String>(
                title: const Text('Included in goal'),
                value: 'included',
                groupValue: _selectedShippingCostHandling,
                onChanged: (value) {
                  setState(() => _selectedShippingCostHandling = value);
                },
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text('Separate estimate'),
                value: 'separate',
                groupValue: _selectedShippingCostHandling,
                onChanged: (value) {
                  setState(() => _selectedShippingCostHandling = value);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Shipping Notes (optional)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _shippingNotesController,
            hint: 'e.g., Delivered to co-op office...',
            maxLines: 2,
            onChanged: (_) {},
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 7: SUPPORT
  Widget _buildStep7Support() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Support & Maintenance',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tell supporters how the tool will be supported after purchase.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Warranty / Support*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _warrantyController,
            hint:
                'e.g., Supplier warranty 3 months for defects. Co-op handles basic troubleshooting.',
            maxLines: 3,
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),
          Text(
            'Spare Parts Plan*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _sparePartsController,
            hint:
                'e.g., We will stock spare nozzles. Parts sourced from (supplier).',
            maxLines: 3,
            onChanged: (_) {},
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 8: RISKS & PREVIEW
  Widget _buildStep8Preview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Final Checks',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Honest risks and safety notes build trust.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Risks*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _risksController,
            hint:
                'Possible delays: supplier lead time, shipping delays... Our fallback plan is...',
            maxLines: 3,
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),
          Text(
            'Safety Notes*',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _safetyNotesController,
            hint: 'e.g., PPE required. Training required for first-time renters.',
            maxLines: 3,
            onChanged: (_) {},
          ),
          const SizedBox(height: 24),
          Text(
            'Campaign Preview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _draft.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _draft.shortBlurb,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Goal: ₱${_draft.goalAmount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Ends: ${_draft.endDate.toLocal().toString().split(' ')[0]}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _previousStep();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  lightColorScheme.primary,
                  lightColorScheme.secondary,
                ],
                stops: const [0.0, 0.9],
              ),
            ),
          ),
          title: Text('Step ${_currentStep + 1} of 8'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: StepProgressIndicator(
                currentStep: _currentStep + 1,
                totalSteps: 8,
                primaryColor: lightColorScheme.primary,
              ),
            ),
            Expanded(
              child: _buildStepContent(),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _currentStep > 0 ? _previousStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                ),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: _saveDraft,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade400,
                ),
                child: const Text('Save Draft'),
              ),
              if (_currentStep < 7)
                ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  child: const Text('Next'),
                )
              else
                ElevatedButton(
                  onPressed: _isLoading ? null : _publishCampaign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Publish'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

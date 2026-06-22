import 'dart:convert';

import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_wizard_form_logic.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/campaign_cover_image.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/widgets/reward_tier_form.dart';
import 'package:bukidbayan_app/widgets/step_progress_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CampaignWizardScreen extends StatefulWidget {
  final Campaign? existingDraft;
  final CrowdfundingService? serviceOverride;
  final FirebaseAuth? authOverride;
  final ImagePicker? imagePickerOverride;

  const CampaignWizardScreen({
    super.key,
    this.existingDraft,
    this.serviceOverride,
    this.authOverride,
    this.imagePickerOverride,
  });

  @override
  State<CampaignWizardScreen> createState() => _CampaignWizardScreenState();
}

class _CampaignWizardScreenState extends State<CampaignWizardScreen> {
  static const List<String> _stepTitles = [
    'Panimula',
    'Kwento ng Kampanya',
    'Detalye ng Kagamitan',
    'Saklaw ng Bibilhin',
    'Pondo at Iskedyul',
    'Benepisyo at Delivery',
    'Suporta at Maintenance',
    'Pagsusuri',
  ];

  static const List<String> _stepDescriptions = [
    'Ilagay ang malinaw na pamagat, kategorya, at cover photo na unang makikita ng mga susuporta.',
    'Ipaliwanag ang problema, sino ang makikinabang, at bakit mahalaga ang kagamitang ito.',
    'Ilagay ang mahahalagang detalye ng kagamitan para malinaw ang eksaktong bibilhin.',
    'Ilista ang kumpletong laman ng bibilhin at anumang mahalagang pagpipilian o variant.',
    'Itakda ang tamang target na pondo, petsa ng pagtatapos, at plano ng pagpapatupad.',
    'Ilatag ang benepisyo para sa supporters at kung paano hahawakan ang delivery o shipping.',
    'Ipaliwanag ang warranty, maintenance, at plano sa spare parts pagkatapos mabili ang kagamitan.',
    'Suriin ang draft, ilagay ang mga panganib at paalala sa kaligtasan, saka i-publish.',
  ];

  int _currentStep = 0;
  bool _isLoading = false;
  bool _allowImmediatePop = false;
  late Campaign _draft;
  final CampaignWizardFormLogic _formLogic = CampaignWizardFormLogic();
  late final CrowdfundingService _service;
  late final ImagePicker _imagePicker;
  FirebaseAuth? _auth;

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

  final Map<String, String> _assetImageLabels = const {
    'assets/images/farmBg.jpg': 'Bukirin',
    'assets/images/bg1.png': 'Patubig',
    'assets/images/loopyBg.jpg': 'Pamayanan',
  };

  final Map<String, String> _categoryLabels = const {
    'Irrigation': 'Patubig',
    'Crop Care': 'Pangangalaga ng Pananim',
    'Post-harvest': 'Pagkatapos ng Ani',
    'Mechanized Tools': 'Mekanikal na Kagamitan',
    'Livestock': 'Alagang Hayop',
    'Solar/Power': 'Solar/Kuryente',
    'Hand Tools': 'Kagamitang Kamay',
    'Other': 'Iba pa',
  };

  final List<String> _equipmentTypes = [
    'Pump',
    'Sprayer',
    'Thresher/Sheller',
    'Solar equipment',
    'Hand tool',
    'Other',
  ];

  final Map<String, String> _equipmentTypeLabels = const {
    'Pump': 'Bomba',
    'Sprayer': 'Sprayer',
    'Thresher/Sheller': 'Thresher/Sheller',
    'Solar equipment': 'Kagamitang Solar',
    'Hand tool': 'Kagamitang Kamay',
    'Other': 'Iba pa',
  };

  final List<String> _shippingCoverageOptions = [
    'Pickup',
    'Local delivery',
    'Nationwide delivery',
    'Other',
  ];

  final Map<String, String> _shippingCoverageLabels = const {
    'Pickup': 'Pickup',
    'Local delivery': 'Lokal na delivery',
    'Nationwide delivery': 'Nationwide na delivery',
    'Other': 'Iba pa',
  };

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
    _imagePicker = widget.imagePickerOverride ?? ImagePicker();
    _auth = widget.authOverride;
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (_) {
        _auth = null;
      }
    }
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
        creatorName: _auth?.currentUser?.displayName ?? 'Anonymous',
        creatorEmail: _auth?.currentUser?.email,
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
    _includedItemsController = TextEditingController(
      text: _draft.includedItems.join('\n'),
    );
    _hasVariants = _draft.chosenVariant != null;
    _variantController = TextEditingController(
      text: _draft.chosenVariant ?? '',
    );
    _variantNotesController = TextEditingController(
      text: _draft.variantNotes ?? '',
    );
    _fundingGoalController = TextEditingController(
      text: _draft.goalAmount.toString(),
    );
    _productionTimelineController = TextEditingController(
      text: _draft.productionTimeline ?? '',
    );
    _selectedEndDate = _draft.endDate;
    _rewards = _draft.rewards;
    // Validate shipping coverage exists in options, default to first option if not
    _selectedShippingCoverage =
        _shippingCoverageOptions.contains(_draft.shippingCoverage)
        ? _draft.shippingCoverage
        : _shippingCoverageOptions.first;
    // Validate shipping cost handling is valid, default if not
    _selectedShippingCostHandling =
        (_draft.shippingCostHandling == 'included' ||
            _draft.shippingCostHandling == 'separate')
        ? _draft.shippingCostHandling
        : 'included';
    _shippingNotesController = TextEditingController(
      text: _draft.shippingNotes ?? '',
    );
    _warrantyController = TextEditingController(text: _draft.warranty ?? '');
    _sparePartsController = TextEditingController(
      text: _draft.spareParts ?? '',
    );
    _risksController = TextEditingController(text: _draft.risks ?? '');
    _safetyNotesController = TextEditingController(
      text: _draft.safetyNotes ?? '',
    );
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

  Future<bool> _saveDraft({bool showFeedback = true}) async {
    _updateDraftFromCurrentStep();
    try {
      await _service.saveDraft(_draft);
      if (mounted && showFeedback) {
        showConfirmSnackbar(
          context: context,
          title: 'Na-save ang draft',
          message: 'Na-save ang draft ng kampanya mo.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(
          context: context,
          title: 'May problema',
          message: 'Hindi na-save ang draft: $e',
        );
      }
      return false;
    }
  }

  Future<void> _publishCampaign() async {
    _updateDraftFromCurrentStep();

    setState(() => _isLoading = true);

    try {
      final errors = _service.validateForPublish(_draft);

      if (errors.isNotEmpty) {
        if (mounted) {
          showErrorSnackbar(
            context: context,
            title: 'Hindi ma-publish',
            message:
                'Pakikumpleto ang mga kailangang detalye:\n${errors.join('\n')}',
          );
        }
        return;
      }

      await _service.publishCampaign(_draft);
      if (mounted) {
        showConfirmSnackbar(
          context: context,
          title: 'Na-publish na ang kampanya',
          message:
              'Maaari nang mag-pledge ang supporters para pondohan ang kagamitang ito.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(
          context: context,
          title: 'May problema',
          message: 'Hindi na-publish ang kampanya: $e',
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
        title: 'Kumpletuhin ang mga detalye',
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

  bool _isRemoteImagePath(String path) {
    final uri = Uri.tryParse(path.trim());
    return uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
  }

  bool get _hasSelectedCustomPhoto {
    final imagePath = _imagePathController.text.trim();
    return !_isAssetImage &&
        imagePath.isNotEmpty &&
        !_isRemoteImagePath(imagePath);
  }

  String _resolveMimeType(XFile pickedFile) {
    final normalized = pickedFile.name.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    if (normalized.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }

  Future<String> _encodePickedImage(XFile pickedFile) async {
    final bytes = await pickedFile.readAsBytes();
    final encoded = base64Encode(bytes);
    final mimeType = _resolveMimeType(pickedFile);
    return 'data:$mimeType;base64,$encoded';
  }

  String _displayLabel(Map<String, String> labels, String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return labels[value] ?? value;
  }

  Widget _buildTipCard({
    required String title,
    required String message,
    IconData icon = Icons.tips_and_updates_outlined,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightColorScheme.primary.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: lightColorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomPhoto(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
      );
      if (pickedFile == null) {
        return;
      }

      final savedPath = await _encodePickedImage(pickedFile);
      if (!mounted) {
        return;
      }

      setState(() {
        _isAssetImage = false;
        _imagePathController.text = savedPath;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      showErrorSnackbar(
        context: context,
        title: 'Hindi naidagdag ang larawan',
        message: 'Nagkaroon ng problema sa pagdagdag ng larawan: $e',
      );
    }
  }

  Future<void> _saveDraftAndExit() async {
    if (_isLoading) {
      return;
    }

    final saved = await _saveDraft(showFeedback: false);
    if (!saved || !mounted) {
      return;
    }

    _allowImmediatePop = true;
    await Navigator.of(context).maybePop(true);
    _allowImmediatePop = false;
  }

  Campaign get _previewDraft {
    return _formLogic.applyStepToDraft(
      draft: _draft,
      step: _currentStep,
      state: _buildFormState(),
    );
  }

  String get _currentStepTitle => _stepTitles[_currentStep];

  String get _currentStepDescription => _stepDescriptions[_currentStep];

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
    final imagePath = _imagePathController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipCard(
            title: 'Hakbang 1 muna',
            message:
                'Kumpletuhin ang pamagat, kategorya, at larawan bago magpatuloy sa susunod na hakbang.',
          ),
          const SizedBox(height: 16),
          Text(
            'Pamagat ng Kampanya*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _titleController,
            hint: 'Hal. Solar Water Pump para sa Pahiram ng Kooperatiba',
            maxLength: 70,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'Gawing tiyak: pangalan ng kagamitan + gamit nito. Iwasan ang malabong pangakong tulad ng "pinakamaganda" o "garantisado".',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Kategorya*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            items: _categoryOptions
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(_displayLabel(_categoryLabels, c)),
                  ),
                )
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
            'Piliin ang pinakaakmang kategorya para madaling mahanap at maintindihan ng supporters.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Cover Photo*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Larawan ng App'),
                icon: Icon(Icons.image),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Sarili Mong Larawan'),
                icon: Icon(Icons.photo_camera_back_outlined),
              ),
            ],
            selected: {_isAssetImage},
            onSelectionChanged: (selection) {
              setState(() {
                _isAssetImage = selection.first;
                if (_isAssetImage && _imagePathController.text.trim().isEmpty) {
                  _imagePathController.text = _assetImageOptions.first;
                }
              });
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
                  label: Text(_assetImageLabels[assetPath] ?? assetPath),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _imagePathController.text = assetPath);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            CustomTextFormField(
              controller: _imagePathController,
              hint: 'assets/images/farmBg.jpg',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Text(
              'Pumili ng nakaabang na larawan ng app kung ayaw mo munang gumamit ng sariling photo.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ] else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickCustomPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pumili ng Larawan'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickCustomPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Kunan ng Larawan'),
                ),
              ],
            ),
            if (_hasSelectedCustomPhoto) ...[
              const SizedBox(height: 8),
              Text(
                'Ang napiling larawan ay mase-save kasama ng draft at gagana sa mobile at web.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'O maglagay ng image URL',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CustomTextFormField(
              controller: _imagePathController,
              hint: 'https://example.com/my-image.jpg',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Text(
              'Puwede kang gumamit ng sariling larawan o direktang link ng image.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CampaignCoverImage(
                imagePath: imagePath,
                isAssetImage: _isAssetImage,
              ),
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
            'Ipaliwanag ang Kampanya',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ipaliwanag kung bakit mahalaga ang kagamitang ito at paano ito makakatulong.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Maikling Buod*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _shortBlurbController,
            hint:
                'Hal. Tulungan kaming bumili ng shared thresher para mabawasan ang post-harvest losses ng maliliit na magsasaka.',
            maxLines: 2,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'Sa loob ng 1-2 pangungusap: ano ito, sino ang makikinabang, at bakit ito mahalaga.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Buong Paglalarawan*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _fullStoryController,
            hint:
                'Ilarawan dito ang pangangailangan, plano, at inaasahang epekto ng kampanya...',
            maxLines: 8,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'Mga gabay sa pagsulat:\n• Anong problema ang nilulutas?\n• Sino ang gagamit ng kagamitan at paano?\n• Paano ito papahiram kapag nabili na?\n• Anong konkretong epekto ang inaasahan?',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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
            'Detalye ng Kagamitan',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Mas malinaw na detalye, mas madaling pagkatiwalaan ng supporters.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Uri ng Kagamitan*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedEquipmentType,
            items: _equipmentTypes
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(_displayLabel(_equipmentTypeLabels, e)),
                  ),
                )
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
            'Mahahalagang Detalye* (hindi bababa sa 3)',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_specs.isEmpty)
            _buildTipCard(
              title: 'Wala pang detalye',
              message:
                  'Maglagay ng kahit 3 malinaw na detalye tulad ng kapasidad, sukat, at power rating.',
              icon: Icons.rule_folder_outlined,
            ),
          if (_specs.isNotEmpty)
            Text(
              '${_specs.length} detalye na ang nailagay',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          const SizedBox(height: 8),
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
                  hint: 'Hal. Kapasidad',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomTextFormField(
                  controller: _specValueController,
                  hint: 'Hal. 50 L/min',
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
                child: const Text('Idagdag'),
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
            'Ano ang Eksaktong Bibilhin?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ilagay nang malinaw ang eksaktong kasama sa bibilhin ng kooperatiba.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Saklaw ng Bibilhin*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _includedItemsController,
            hint:
                '• 1 unit ng kagamitan o model\n• Mga accessory o attachment\n• Manual, training, o installation',
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            maxLines: 4,
            onChanged: (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            'Ilista ang lahat ng inaasahang matatanggap kapag nabili ang kagamitan.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            title: const Text('May variant o pagpipilian ang kagamitang ito'),
            value: _hasVariants,
            onChanged: (value) {
              setState(() => _hasVariants = value ?? false);
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_hasVariants) ...[
            const SizedBox(height: 16),
            Text(
              'Piling Variant*',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CustomTextFormField(
              controller: _variantController,
              hint: 'Hal. 2HP na bersyon',
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),
            Text(
              'Paliwanag sa Variant',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CustomTextFormField(
              controller: _variantNotesController,
              hint:
                  'Kung nakadepende ang final choice sa available na supplier, ilahad dito.',
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
            'Pondo at Iskedyul',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Itakda ang makatotohanang target na pondo at malinaw na plano pagkatapos ng kampanya.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Target na Pondo (₱)*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
            'Isama ang halaga ng kagamitan, delivery, setup, at maliit na allowance para sa aberya.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Petsa ng Pagtatapos*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                _selectedEndDate != null
                    ? '${_selectedEndDate!.toLocal().toString().split(' ')[0]} (${_selectedEndDate!.difference(DateTime.now()).inDays} days)'
                    : 'Pumili ng petsa',
              ),
              trailing: const Icon(Icons.calendar_today),
              // onTap: () async {
              //   final picked = await showDatePicker(
              //     context: context,
              //     initialDate: _selectedEndDate ?? DateTime.now(),
              //     firstDate: DateTime.now(),
              //     lastDate: DateTime.now().add(const Duration(days: 365)),
              //   );
              //   if (picked != null) {
              //     setState(() => _selectedEndDate = picked);
              //   }
              // },
              onTap: () async {
                final now = DateTime.now();
                final safeInitial = (_selectedEndDate != null && _selectedEndDate!.isAfter(now))
                    ? _selectedEndDate!
                    : now;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: safeInitial,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedEndDate = picked);
                }
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rekomendado: 7 hanggang 60 araw mula sa pag-publish.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Timeline ng Pagpapatupad*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _productionTimelineController,
            hint:
                '• Linggo 1: pag-order ng kagamitan\n• Linggo 2-3: delivery at setup\n• Linggo 4: testing at turnover',
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
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
            'Benepisyo at Delivery',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ang benepisyo para sa supporters ay maaaring diskuwento o perk. Ilahad din kung paano darating ang kagamitan.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Mga Antas ng Benepisyo* (hindi bababa sa 1)',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_rewards.isEmpty)
            _buildTipCard(
              title: 'Wala pang benepisyo',
              message:
                  'Magdagdag ng kahit isang benepisyo para malinaw kung ano ang matatanggap ng supporters.',
              icon: Icons.card_giftcard_outlined,
            ),
          if (_rewards.isNotEmpty)
            Text(
              '${_rewards.length} benepisyo na ang nailagay',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          const SizedBox(height: 8),
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
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Minimum na pledge: ₱${reward.minPledge} | Diskuwento: ${reward.discountValue.toStringAsFixed(reward.discountType == 'percent' ? 0 : 2)}${reward.discountType == 'percent' ? '%' : '₱'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton(
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                child: const Text('I-edit'),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: Colors.white,
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
                                child: const Text('Tanggalin'),
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
                useSafeArea: true,
                backgroundColor: Colors.white,
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
            label: const Text('Magdagdag ng Benepisyo'),
          ),
          const SizedBox(height: 24),
          Text(
            'Delivery ng Kagamitan',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Saklaw ng Delivery*',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedShippingCoverage,
            items: _shippingCoverageOptions
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(_displayLabel(_shippingCoverageLabels, s)),
                  ),
                )
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
            'Paano Isasama ang Gastos sa Delivery*',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              RadioListTile<String>(
                title: const Text('Kasama na sa target na pondo'),
                value: 'included',
                groupValue: _selectedShippingCostHandling,
                onChanged: (value) {
                  setState(() => _selectedShippingCostHandling = value);
                },
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text('Hiwalay na tantiya'),
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
            'Dagdag na Tala sa Delivery (opsyonal)',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _shippingNotesController,
            hint:
                'Hal. Ihahatid sa opisina ng kooperatiba at iko-coordinate muna ang schedule.',
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
            'Suporta at Maintenance',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ipaliwanag kung paano aalagaan at susuportahan ang kagamitan matapos itong mabili.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Warranty at Suporta*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _warrantyController,
            hint:
                'Hal. May 3 buwang supplier warranty para sa defects at ang kooperatiba ang sasagot sa basic troubleshooting.',
            maxLines: 3,
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),
          Text(
            'Plano sa Spare Parts*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _sparePartsController,
            hint:
                'Hal. Magtatabi ng spare nozzles at ibang piyesa mula sa napiling supplier.',
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
    final previewDraft = _previewDraft;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipCard(
            title: 'Final check bago i-publish',
            message:
                'Siguraduhin na malinaw ang panganib at safety notes para mapagkatiwalaan ang kampanya.',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            'Mga Panganib*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _risksController,
            hint:
                'Hal. Posibleng maantala ang supplier o shipping. Ilagay rin ang backup plan kung mangyari ito.',
            maxLines: 3,
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),
          Text(
            'Paalala sa Kaligtasan*',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: _safetyNotesController,
            hint:
                'Hal. Kailangan ang PPE at orientation bago gamitin ng unang beses.',
            maxLines: 3,
            onChanged: (_) {},
          ),
          const SizedBox(height: 24),
          Text(
            'Preview ng Kampanya',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CampaignCoverImage(
                        imagePath: previewDraft.image,
                        isAssetImage: previewDraft.isAssetImage,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    previewDraft.title.isEmpty
                        ? '(Wala pang pamagat)'
                        : previewDraft.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    previewDraft.shortBlurb.isEmpty
                        ? 'Maglagay ng maikling buod para agad maintindihan ng supporters ang kampanya.'
                        : previewDraft.shortBlurb,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target: ₱${previewDraft.goalAmount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Hanggang: ${previewDraft.endDate.toLocal().toString().split(' ')[0]}',
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
    final campaignTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      cardTheme: Theme.of(context).cardTheme.copyWith(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return Theme(
      data: campaignTheme,
      child: WillPopScope(
        onWillPop: () async {
        if (_allowImmediatePop) {
          return true;
        }
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
                colors: [lightColorScheme.primary, lightColorScheme.secondary],
                stops: const [0.0, 0.9],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'I-save ang draft at lumabas',
            onPressed: _saveDraftAndExit,
          ),
          title: Text(_currentStepTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Hakbang ${_currentStep + 1} ng 8',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          centerTitle: true,
          elevation: 0,
        ),
          body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  StepProgressIndicator(
                    currentStep: _currentStep + 1,
                    totalSteps: 8,
                    primaryColor: lightColorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStepTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currentStepDescription,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ang back sa itaas ay magse-save at lalabas. Ang device back o ang button sa ibaba ay babalik ng isang hakbang.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
          bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentStep > 0 ? _previousStep : null,
                        child: const Text('Bumalik'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _currentStep < 7
                          ? ElevatedButton(
                              onPressed: _isLoading ? null : _nextStep,
                              child: const Text('Susunod'),
                            )
                          : ElevatedButton(
                              onPressed: _isLoading ? null : _publishCampaign,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lightColorScheme.primary,
                                foregroundColor: lightColorScheme.onPrimary,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('I-publish'),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _saveDraft(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                    ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('I-save ang Draft'),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

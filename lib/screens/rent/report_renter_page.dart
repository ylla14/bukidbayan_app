import 'dart:io';
import 'dart:typed_data';
import 'package:bukidbayan_app/services/cloudinary_service.dart';
import 'package:bukidbayan_app/services/maintenance_service.dart';
import 'package:bukidbayan_app/services/strike_service.dart';
import 'package:intl/intl.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────
//  ReportRenterPage
//  Owner-only UI — called after a completed rent
//  request when the renter mishandled equipment.
// ─────────────────────────────────────────────
class ReportRenterPage extends StatefulWidget {
  final String requestId;
  final String renterId;
  final String renterName;
  final String itemName;
  final String equipmentId;

  const ReportRenterPage({
    super.key,
    required this.requestId,
    required this.renterId,
    required this.renterName,
    required this.itemName,
    required this.equipmentId,
  });

  @override
  State<ReportRenterPage> createState() => _ReportRenterPageState();
}

class _ReportRenterPageState extends State<ReportRenterPage> {
  // ── form state ──────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();

  String? _selectedReason;
  final List<XFile> _evidenceImages = [];
  bool _isSubmitting = false;

  // ── reason options ──────────────────────────
  static const List<Map<String, dynamic>> _reasons = [
    {
      'value': 'damaged_equipment',
      'label': 'Nasirang Kagamitan',
      'icon': Icons.build_circle_outlined,
    },
    {
      'value': 'late_return',
      'label': 'Nahuling Ibalik',
      'icon': Icons.schedule_outlined,
    },
    {
      'value': 'missing_parts',
      'label': 'Nawawalang Parte / Accessories',
      'icon': Icons.inventory_2_outlined,
    },
    {
      'value': 'misuse',
      'label': 'Maling Paggamit ng Kagamitan',
      'icon': Icons.warning_amber_outlined,
    },
    {
      'value': 'other',
      'label': 'Iba pa',
      'icon': Icons.more_horiz_outlined,
    },
  ];

  // ── image picker ────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (_evidenceImages.length >= 5) {
      _showSnack('Maximum 5 na larawan lang ang pinapayagan.');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked != null) {
      setState(() => _evidenceImages.add(picked));
    }
  }

  void _removeImage(int index) {
    setState(() => _evidenceImages.removeAt(index));
  }

  void _showImageSourceSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Magdagdag ng Larawan bilang Katibayan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.surface,
                child: Icon(Icons.camera_alt_outlined, color: cs.primary),
              ),
              title: const Text('Kumuha ng Larawan'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.surface,
                child: Icon(Icons.photo_library_outlined, color: cs.primary),
              ),
              title: const Text('Pumili mula sa Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── submit ──────────────────────────────────
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      _showSnack('Pumili ng dahilan para sa reklamo.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload evidence images to Cloudinary
      List<String> evidenceUrls = [];
      if (_evidenceImages.isNotEmpty) {
        final cloudinary = CloudinaryService();
        for (final xfile in _evidenceImages) {
          final url = await cloudinary.uploadImage(xfile);
          evidenceUrls.add(url);
        }
      }

      // 2. Issue immediate 2-week ban (no strike count) via StrikeService
      final ownerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await StrikeService().issueMisuseBan(
        requestId: widget.requestId,
        renterId: widget.renterId,
        ownerId: ownerId,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
        equipmentId: widget.equipmentId,
        evidenceUrls: evidenceUrls,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Hindi naisumite ang reklamo. Subukan muli.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    final cs = Theme.of(context).colorScheme;
    final isDamageReport = StrikeService.kDamageReasons.contains(_selectedReason);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.shield_outlined, color: cs.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Naisumite ang Reklamo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ang iyong reklamo laban kay ${widget.renterName} ay naisumite na. '
              'Susuriin ito ng aming koponan at magsasagawa ng naaangkop na aksyon. '
              'Maaaring pansamantalang suspindihin ang nangupahan habang isinasagawa ang imbestigasyon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            if (isDamageReport) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.build_outlined,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gusto mo bang i-schedule ang kagamitan para sa maintenance?',
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (isDamageReport)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.build_rounded, size: 16),
                  label: const Text(
                    'I-schedule ang Maintenance',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.pop(context);
                    _showMaintenancePrompt(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            if (isDamageReport) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDamageReport ? Colors.grey.shade200 : cs.primary,
                  foregroundColor:
                      isDamageReport ? cs.onSurface : cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Tapos Na',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMaintenancePrompt(BuildContext ctx) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: today.add(const Duration(days: 1)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Piliin ang Katapusan ng Maintenance',
    );
    if (picked == null || !ctx.mounted) return;

    final maintenanceEnd =
        DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    final durationDays = maintenanceEnd.difference(today).inDays + 1;
    final isUnforeseen = durationDays > 7;

    final svc = MaintenanceService();
    final affected = await svc.fetchAffectedBookings(
      equipmentId: widget.equipmentId,
      today: today,
      maintenanceEnd: maintenanceEnd,
      isUnforeseen: isUnforeseen,
    );
    if (!ctx.mounted) return;

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isUnforeseen ? Icons.warning_amber_rounded : Icons.build_outlined,
              color: isUnforeseen ? Colors.red : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(isUnforeseen
                  ? 'Hindi Inaasahang Maintenance'
                  : 'I-schedule ang Maintenance'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panahon ng Maintenance: ${DateFormat('MMM d').format(today)} – ${DateFormat('MMM d, yyyy').format(maintenanceEnd)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$durationDays na araw',
                  style: TextStyle(
                    color: isUnforeseen ? Colors.red : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUnforeseen
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUnforeseen
                          ? Colors.red.shade200
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Text(
                    isUnforeseen
                        ? 'Ang maintenance ay higit sa 7 araw. Lahat ng booking sa panahong ito ay IKAKANSELA.'
                        : 'Ang mga booking sa panahong ito ay ire-reschedule pagkatapos ng maintenance.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isUnforeseen
                          ? Colors.red.shade700
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
                if (affected.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Mga Apektadong Booking (${affected.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ...affected.map((b) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: b.willBeCancelled
                              ? Colors.red.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: b.willBeCancelled
                                ? Colors.red.shade200
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              b.willBeCancelled
                                  ? Icons.cancel_outlined
                                  : Icons.event_repeat,
                              size: 16,
                              color: b.willBeCancelled
                                  ? Colors.red.shade700
                                  : Colors.orange.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.renterName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(
                                    '${DateFormat('MMM d').format(b.start)} – ${DateFormat('MMM d, yyyy').format(b.end)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700),
                                  ),
                                  if (!b.willBeCancelled &&
                                      b.newStart != null &&
                                      b.newEnd != null) ...[
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Icon(Icons.arrow_forward,
                                          size: 12,
                                          color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${DateFormat('MMM d').format(b.newStart!)} – ${DateFormat('MMM d, yyyy').format(b.newEnd!)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade800,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ]),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    b.willBeCancelled
                                        ? 'Ikakansela'
                                        : 'Ire-reschedule',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: b.willBeCancelled
                                          ? Colors.red.shade700
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text('Walang booking ang maaapektuhan.',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Kanselahin'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isUnforeseen ? Colors.red : Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Kumpirmahin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await svc.scheduleMaintenanceForEquipment(
        equipmentId: widget.equipmentId,
        equipmentName: widget.itemName,
        today: today,
        maintenanceEnd: maintenanceEnd,
      );
      if (ctx.mounted) Navigator.pop(ctx);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(isUnforeseen
              ? '⚠️ Maintenance na-set. Ang mga apektadong booking ay kinansela.'
              : '✅ Maintenance na-schedule. Ang mga booking ay na-reschedule.'),
          backgroundColor: isUnforeseen ? Colors.red : Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (ctx.mounted) Navigator.pop(ctx);
      if (ctx.mounted) _showSnack('Hindi na-schedule ang maintenance. Subukan muli.');
    }
  }

  void _showSnack(String msg) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  // ── build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        title: Text('Ireklamo and Nangupahan', style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 17)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            const SizedBox(height: 20),
            _buildWarningBanner(cs),
            const SizedBox(height: 24),
            _buildRenterInfoCard(cs),
            const SizedBox(height: 24),
            _buildSectionLabel('Dahilan ng Reklamo', cs, required: true),
            const SizedBox(height: 12),
            _buildReasonSelector(cs),
            const SizedBox(height: 24),
            _buildSectionLabel('Paglalarawan', cs, required: true),
            const SizedBox(height: 12),
            _buildDetailsField(cs),
            const SizedBox(height: 24),
            _buildSectionLabel(
              'Mga Larawan bilang Katibayan',
              cs,
              subtitle: 'Mag-attach ng hanggang 5 larawan na nagpapakita ng pinsala o maling paggamit.',
            ),
            const SizedBox(height: 12),
            _buildEvidenceGrid(cs),
            const SizedBox(height: 24),
            _buildDisclaimerCard(cs),
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitBar(cs),
    );
  }


  // ── warning banner ───────────────────────────
  Widget _buildWarningBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ang pagsumite ng maling reklamo ay maaaring magresulta sa parusa sa iyong account. '
              'Mag-ulat lamang ng tunay na mga kaso ng maling paggamit o pagpabaya.',
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSecondary.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── renter info card ─────────────────────────
  Widget _buildRenterInfoCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.surface,
            child: Text(
              widget.renterName.isNotEmpty
                  ? widget.renterName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.renterName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kagamitan: ${widget.itemName}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Inireklamo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── section label ────────────────────────────
  Widget _buildSectionLabel(String label, ColorScheme cs,
      {bool required = false, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.error,
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ],
    );
  }

  // ── reason selector ──────────────────────────
  Widget _buildReasonSelector(ColorScheme cs) {
    return Column(
      children: _reasons.map((reason) {
        final isSelected = _selectedReason == reason['value'];
        return GestureDetector(
          onTap: () => setState(() => _selectedReason = reason['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? cs.surface.withOpacity(0.5) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outlineVariant.withOpacity(0.5),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Icon(
                  reason['icon'] as IconData,
                  size: 20,
                  color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 12),
                Text(
                  reason['label'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? cs.primary : cs.onSecondary,
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? cs.primary : cs.outlineVariant,
                      width: isSelected ? 6 : 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── details text field ───────────────────────
  Widget _buildDetailsField(ColorScheme cs) {
    return TextFormField(
      controller: _detailsController,
      maxLines: 5,
      maxLength: 500,
      validator: (v) {
        if (v == null || v.trim().length < 20) {
          return 'Mangyaring magbigay ng hindi bababa sa 20 karakter ng paglalarawan.';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText:
            'Ilarawan nang detalyado ang nangyari. Isama kung kailan napansin ang pinsala, ang kondisyon ng kagamitan, at anumang komunikasyon sa nangupahan…',
        hintStyle: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withOpacity(0.35),
          height: 1.5,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
      ),
    );
  }

  // ── evidence photo grid ──────────────────────
  Widget _buildEvidenceGrid(ColorScheme cs) {
    final canAdd = _evidenceImages.length < 5;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _evidenceImages.length + (canAdd ? 1 : 0),
      itemBuilder: (_, index) {
        // "Add" tile
        if (index == _evidenceImages.length) {
          return GestureDetector(
            onTap: _showImageSourceSheet,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: cs.secondary, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    '${_evidenceImages.length}/5',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurface.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
          );
        }

        // Image tile
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: kIsWeb
                  ? FutureBuilder<Uint8List>(
                      future: _evidenceImages[index].readAsBytes(),
                      builder: (_, snap) => snap.hasData
                          ? Image.memory(snap.data!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover)
                          : const Center(child: CircularProgressIndicator()),
                    )
                  : Image.file(
                      File(_evidenceImages[index].path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── disclaimer ───────────────────────────────
  Widget _buildDisclaimerCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 15, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Ano ang mangyayari pagkatapos mag-ulat?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            '• Susuriin ng aming koponan ang iyong reklamo sa loob ng 24–48 na oras.',
            '• Ang account ng nangupahan ay maaaring pansamantalang i-restrict habang isinasagawa ang pagsusuri.',
            '• Kung mapatunayang totoo ang reklamo, ang nangupahan ay sususpindihin sa ilang araw at kailangang ayusin ang anumang natitirang bayad sa labas ng app.',
            '• Ipapaalam sa iyo ang resulta sa pamamagitan ng in-app na abiso.',
          ].map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurface.withOpacity(0.55),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── submit bar ───────────────────────────────
  Widget _buildSubmitBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitReport,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.flag_rounded, size: 20),
          label: Text(
            _isSubmitting ? 'Isinusumite…' : 'Isumite ang Reklamo',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            disabledBackgroundColor: cs.error.withOpacity(0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
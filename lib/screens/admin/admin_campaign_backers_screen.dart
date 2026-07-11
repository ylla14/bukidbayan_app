import 'package:bukidbayan_app/components/rent/proof_page_viewer.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';

/// A single campaign's backer list with each pledge's proof-of-payment
/// status — image thumbnail, reference number, or pending. Deliberately
/// lighter than [CampaignReportScreen], which stays the creator-side full
/// report (funnel, timeline, reward breakdown).
class AdminCampaignBackersScreen extends StatefulWidget {
  final String campaignId;
  final String campaignTitle;
  final CrowdfundingService? serviceOverride;

  const AdminCampaignBackersScreen({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
    this.serviceOverride,
  });

  @override
  State<AdminCampaignBackersScreen> createState() =>
      _AdminCampaignBackersScreenState();
}

class _AdminCampaignBackersScreenState
    extends State<AdminCampaignBackersScreen> {
  late final CrowdfundingService _service;
  late Future<List<Pledge>> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
    _future = _service.getPledgesForCampaign(widget.campaignId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.getPledgesForCampaign(widget.campaignId);
    });
    await _future;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _supporterLabel(Pledge pledge) {
    if (pledge.backerName != null && pledge.backerName!.trim().isNotEmpty) {
      return pledge.backerName!.trim();
    }
    if (pledge.backerEmail != null && pledge.backerEmail!.trim().isNotEmpty) {
      return pledge.backerEmail!.trim();
    }
    return 'Anonymous supporter';
  }

  Widget _buildProofIndicator(Pledge pledge) {
    final imageUrl = pledge.proofImageUrl?.trim();
    final referenceNumber = pledge.proofReferenceNumber?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProofViewerPage(urls: [imageUrl], initialIndex: 0),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }

    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      return Chip(
        label: Text('Ref: $referenceNumber', style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
      );
    }

    return Chip(
      label: const Text('Naghihintay', style: TextStyle(fontSize: 11)),
      backgroundColor: Colors.grey.shade200,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.campaignTitle.isEmpty
              ? 'Mga Backer'
              : widget.campaignTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Pledge>>(
          future: _future,
          builder: (context, snapshot) {
            final pledges = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting &&
                pledges.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (pledges.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  Center(child: Text('Wala pang backer para sa campaign na ito.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pledges.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pledge = pledges[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    title: Text(
                      _supporterLabel(pledge),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${formatPeso(pledge.amount)} • ${_formatDate(pledge.createdAt)}',
                      ),
                    ),
                    trailing: _buildProofIndicator(pledge),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';

class ReviewStep extends StatelessWidget {
  final String title;
  final String category;
  final String image;
  final bool isAssetImage;
  final String shortBlurb;
  final String description;
  final int goalAmount;
  final DateTime endDate;
  final String productionTimeline;
  final List<RewardTier> rewards;
  final String warranty;
  final String spareParts;
  final String risks;
  final String safetyNotes;

  const ReviewStep({
    super.key,
    required this.title,
    required this.category,
    required this.image,
    required this.isAssetImage,
    required this.shortBlurb,
    required this.description,
    required this.goalAmount,
    required this.endDate,
    required this.productionTimeline,
    required this.rewards,
    required this.warranty,
    required this.spareParts,
    required this.risks,
    required this.safetyNotes,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = endDate.difference(DateTime.now()).inDays;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Campaign Review',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 16),
          if (image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: isAssetImage
                    ? Image.asset(image, fit: BoxFit.cover)
                    : Image.network(image, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$category • ${formatPeso(goalAmount)} goal • $daysLeft days',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _buildSection('Short Blurb', shortBlurb),
          _buildSection('Full Description', description),
          _buildSection('Production Timeline', productionTimeline),
          _buildSection('Warranty', warranty.isEmpty ? 'Not specified' : warranty),
          _buildSection('Spare Parts', spareParts.isEmpty ? 'Not specified' : spareParts),
          _buildSection('Risks', risks.isEmpty ? 'Not specified' : risks),
          _buildSection('Safety Notes', safetyNotes.isEmpty ? 'Not specified' : safetyNotes),
          const SizedBox(height: 20),
          const Text(
            'Reward Tiers',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              final discountDisplay = reward.discountType == 'percent'
                  ? '${reward.discountValue.toStringAsFixed(0)}% off'
                  : '${formatPeso(reward.discountValue.toInt())} off';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${reward.title} (${formatPeso(reward.minPledge)})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discount: $discountDisplay',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Usage Limit: ${reward.usageLimit} times • Valid for ${reward.validityDays} days',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (reward.notes != null && reward.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Notes: ${reward.notes}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '✓ Click "Continue" to submit your campaign',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(color: Colors.black87),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

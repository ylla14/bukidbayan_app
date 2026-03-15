import 'package:flutter/material.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/campaign_cover_image.dart';

String formatPeso(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buf.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return 'PHP ${buf.toString()}';
}

class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;

  const CampaignCard({super.key, required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = campaign.progress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();
    final safeDaysLeft = campaign.daysLeft < 0 ? 0 : campaign.daysLeft;

    return Card(
      color: lightColorScheme.onPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CampaignCoverImage(
                  imagePath: campaign.image,
                  isAssetImage: campaign.isAssetImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          campaign.category,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          '$progressPercent% kumpleto',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: lightColorScheme.secondary.withOpacity(
                          0.24,
                        ),
                        side: BorderSide(
                          color: lightColorScheme.secondary.withOpacity(0.5),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    campaign.title.isEmpty
                        ? 'Kampanyang walang pamagat'
                        : campaign.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    campaign.shortBlurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    color: lightColorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${formatPeso(campaign.pledgedAmount)} naipon',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$safeDaysLeft araw na lang',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${formatPeso(campaign.goalAmount)} | ${campaign.backersCount} supporters',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: lightColorScheme.secondary.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pindutin para buksan ang detalye at pagsuporta',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

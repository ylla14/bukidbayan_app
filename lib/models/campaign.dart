import 'dart:convert';

class RewardTier {
  final String id;
  final String title;
  final String description;
  final int minPledge; // pesos
  final String estimatedDelivery; // e.g. "Mar 2026"
  final String shipping; // e.g. "PH only"

  const RewardTier({
    required this.id,
    required this.title,
    required this.description,
    required this.minPledge,
    required this.estimatedDelivery,
    required this.shipping,
  });

  factory RewardTier.fromJson(Map<String, dynamic> json) {
    return RewardTier(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      minPledge: (json['minPledge'] as num).toInt(),
      estimatedDelivery: json['estimatedDelivery'] as String,
      shipping: json['shipping'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'minPledge': minPledge,
        'estimatedDelivery': estimatedDelivery,
        'shipping': shipping,
      };
}

class Campaign {
  final String id;
  final String title;
  final String creatorName;
  final String shortBlurb;
  final String description;

  /// If true, use Image.asset(image)
  /// If false, use Image.network(image)
  final bool isAssetImage;
  final String image;

  final String category;

  final int goalAmount; // pesos
  final int pledgedAmount; // pesos
  final int backersCount;

  final DateTime endDate;
  final DateTime createdAt;

  final List<RewardTier> rewards;

  const Campaign({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.shortBlurb,
    required this.description,
    required this.isAssetImage,
    required this.image,
    required this.category,
    required this.goalAmount,
    required this.pledgedAmount,
    required this.backersCount,
    required this.endDate,
    required this.createdAt,
    required this.rewards,
  });

  double get progress => goalAmount <= 0 ? 0 : (pledgedAmount / goalAmount);

  int get daysLeft {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Campaign copyWith({
    int? pledgedAmount,
    int? backersCount,
  }) {
    return Campaign(
      id: id,
      title: title,
      creatorName: creatorName,
      shortBlurb: shortBlurb,
      description: description,
      isAssetImage: isAssetImage,
      image: image,
      category: category,
      goalAmount: goalAmount,
      pledgedAmount: pledgedAmount ?? this.pledgedAmount,
      backersCount: backersCount ?? this.backersCount,
      endDate: endDate,
      createdAt: createdAt,
      rewards: rewards,
    );
  }

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String,
      title: json['title'] as String,
      creatorName: json['creatorName'] as String,
      shortBlurb: json['shortBlurb'] as String,
      description: json['description'] as String,
      isAssetImage: json['isAssetImage'] as bool,
      image: json['image'] as String,
      category: json['category'] as String,
      goalAmount: (json['goalAmount'] as num).toInt(),
      pledgedAmount: (json['pledgedAmount'] as num).toInt(),
      backersCount: (json['backersCount'] as num).toInt(),
      endDate: DateTime.parse(json['endDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      rewards: (json['rewards'] as List<dynamic>)
          .map((e) => RewardTier.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'creatorName': creatorName,
        'shortBlurb': shortBlurb,
        'description': description,
        'isAssetImage': isAssetImage,
        'image': image,
        'category': category,
        'goalAmount': goalAmount,
        'pledgedAmount': pledgedAmount,
        'backersCount': backersCount,
        'endDate': endDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'rewards': rewards.map((r) => r.toJson()).toList(),
      };
}

class Pledge {
  final String id;
  final String campaignId;
  final String? backerEmail;
  final int amount;
  final String? rewardId;
  final DateTime createdAt;

  const Pledge({
    required this.id,
    required this.campaignId,
    required this.backerEmail,
    required this.amount,
    required this.rewardId,
    required this.createdAt,
  });

  factory Pledge.fromJson(Map<String, dynamic> json) => Pledge(
        id: json['id'] as String,
        campaignId: json['campaignId'] as String,
        backerEmail: json['backerEmail'] as String?,
        amount: (json['amount'] as num).toInt(),
        rewardId: json['rewardId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'campaignId': campaignId,
        'backerEmail': backerEmail,
        'amount': amount,
        'rewardId': rewardId,
        'createdAt': createdAt.toIso8601String(),
      };
}

// Simple helper so you can quickly serialize lists if needed.
String encodeCampaigns(List<Campaign> campaigns) =>
    jsonEncode(campaigns.map((c) => c.toJson()).toList());

List<Campaign> decodeCampaigns(String jsonStr) {
  final raw = jsonDecode(jsonStr) as List<dynamic>;
  return raw.map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList();
}

String encodePledges(List<Pledge> pledges) =>
    jsonEncode(pledges.map((p) => p.toJson()).toList());

List<Pledge> decodePledges(String jsonStr) {
  final raw = jsonDecode(jsonStr) as List<dynamic>;
  return raw.map((e) => Pledge.fromJson(e as Map<String, dynamic>)).toList();
}

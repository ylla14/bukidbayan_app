import 'dart:convert';

class RewardTier {
  final String id;
  final String title;
  final int minPledge; // pesos
  final String discountType; // "percent" or "fixed"
  final double discountValue;
  final int usageLimit;
  final int validityDays;
  final String? notes;

  const RewardTier({
    required this.id,
    required this.title,
    required this.minPledge,
    required this.discountType,
    required this.discountValue,
    required this.usageLimit,
    required this.validityDays,
    this.notes,
  });

  factory RewardTier.fromJson(Map<String, dynamic> json) {
    return RewardTier(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      minPledge: json['minPledge'] != null
          ? (json['minPledge'] as num).toInt()
          : 0,
      discountType: json['discountType'] as String? ?? 'percent',
      discountValue: json['discountValue'] != null
          ? (json['discountValue'] as num).toDouble()
          : 0.0,
      usageLimit: json['usageLimit'] != null
          ? (json['usageLimit'] as num).toInt()
          : 1,
      validityDays: json['validityDays'] != null
          ? (json['validityDays'] as num).toInt()
          : 30,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'minPledge': minPledge,
    'discountType': discountType,
    'discountValue': discountValue,
    'usageLimit': usageLimit,
    'validityDays': validityDays,
    'notes': notes,
  };
}

class Campaign {
  final String id;
  final String title;
  final String creatorName;
  final String? creatorEmail;
  final String shortBlurb;
  final String description;

  /// If true, use an app asset.
  /// If false, `image` may be a remote URL or a stored data URI.
  final bool isAssetImage;
  final String image;

  final String category;

  final int goalAmount; // pesos
  final int pledgedAmount; // pesos
  final int backersCount;

  final DateTime endDate;
  final DateTime createdAt;

  final List<RewardTier> rewards;

  // WIZARD FIELDS - Step 1: Basics
  final List<String> coverImages; // Multiple images/videos

  // WIZARD FIELDS - Step 3: Specs
  final String? equipmentType; // Pump, Sprayer, Thresher, etc
  final Map<String, String> specs; // Dynamic specs (key-value pairs)

  // WIZARD FIELDS - Step 4: What's Included
  final List<String> includedItems;
  final String? chosenVariant;
  final String? variantNotes;

  // WIZARD FIELDS - Step 5: Funding
  final String? productionTimeline;

  // WIZARD FIELDS - Step 6: Shipping
  final String? shippingCoverage; // Pickup, Local delivery, Nationwide, Other
  final String? shippingCostHandling; // Included in goal / Separate estimate
  final String? shippingNotes;

  // WIZARD FIELDS - Step 7: Support
  final String? warranty;
  final String? spareParts;

  // WIZARD FIELDS - Step 8: Risks & Safety
  final String? risks;
  final String? safetyNotes;

  // Status and Timestamps
  final String
  status; // draft, live, ended_success, ended_fail, purchased, cancelled
  final DateTime? publishedAt;
  final DateTime? lastEditedAt;

  const Campaign({
    required this.id,
    required this.title,
    required this.creatorName,
    this.creatorEmail,
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
    this.coverImages = const [],
    this.equipmentType,
    this.specs = const {},
    this.includedItems = const [],
    this.chosenVariant,
    this.variantNotes,
    this.productionTimeline,
    this.shippingCoverage,
    this.shippingCostHandling,
    this.shippingNotes,
    this.warranty,
    this.spareParts,
    this.risks,
    this.safetyNotes,
    this.status = 'draft',
    this.publishedAt,
    this.lastEditedAt,
  });

  double get progress => goalAmount <= 0 ? 0 : (pledgedAmount / goalAmount);

  int get daysLeft {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Campaign copyWith({
    String? id,
    String? title,
    String? creatorName,
    String? creatorEmail,
    String? shortBlurb,
    String? description,
    bool? isAssetImage,
    String? image,
    String? category,
    int? goalAmount,
    DateTime? endDate,
    DateTime? createdAt,
    List<RewardTier>? rewards,
    int? pledgedAmount,
    int? backersCount,
    String? productionTimeline,
    String? warranty,
    String? spareParts,
    String? risks,
    String? safetyNotes,
    String? status,
    DateTime? publishedAt,
    DateTime? lastEditedAt,
    List<String>? coverImages,
    String? equipmentType,
    Map<String, String>? specs,
    List<String>? includedItems,
    String? chosenVariant,
    String? variantNotes,
    String? shippingCoverage,
    String? shippingCostHandling,
    String? shippingNotes,
    bool clearPublishedAt = false,
    bool clearLastEditedAt = false,
  }) {
    return Campaign(
      id: id ?? this.id,
      title: title ?? this.title,
      creatorName: creatorName ?? this.creatorName,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      shortBlurb: shortBlurb ?? this.shortBlurb,
      description: description ?? this.description,
      isAssetImage: isAssetImage ?? this.isAssetImage,
      image: image ?? this.image,
      category: category ?? this.category,
      goalAmount: goalAmount ?? this.goalAmount,
      pledgedAmount: pledgedAmount ?? this.pledgedAmount,
      backersCount: backersCount ?? this.backersCount,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      rewards: rewards ?? this.rewards,
      productionTimeline: productionTimeline ?? this.productionTimeline,
      warranty: warranty ?? this.warranty,
      spareParts: spareParts ?? this.spareParts,
      risks: risks ?? this.risks,
      safetyNotes: safetyNotes ?? this.safetyNotes,
      status: status ?? this.status,
      publishedAt: clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      lastEditedAt: clearLastEditedAt
          ? null
          : (lastEditedAt ?? this.lastEditedAt),
      coverImages: coverImages ?? this.coverImages,
      equipmentType: equipmentType ?? this.equipmentType,
      specs: specs ?? this.specs,
      includedItems: includedItems ?? this.includedItems,
      chosenVariant: chosenVariant ?? this.chosenVariant,
      variantNotes: variantNotes ?? this.variantNotes,
      shippingCoverage: shippingCoverage ?? this.shippingCoverage,
      shippingCostHandling: shippingCostHandling ?? this.shippingCostHandling,
      shippingNotes: shippingNotes ?? this.shippingNotes,
    );
  }

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String,
      title: json['title'] as String,
      creatorName: json['creatorName'] as String,
      creatorEmail: json['creatorEmail'] as String?,
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
      coverImages: json['coverImages'] != null
          ? List<String>.from(json['coverImages'] as List<dynamic>)
          : [],
      equipmentType: json['equipmentType'] as String?,
      specs: json['specs'] != null
          ? Map<String, String>.from(json['specs'] as Map<dynamic, dynamic>)
          : {},
      includedItems: json['includedItems'] != null
          ? List<String>.from(json['includedItems'] as List<dynamic>)
          : [],
      chosenVariant: json['chosenVariant'] as String?,
      variantNotes: json['variantNotes'] as String?,
      productionTimeline: json['productionTimeline'] as String?,
      shippingCoverage: json['shippingCoverage'] as String?,
      shippingCostHandling: json['shippingCostHandling'] as String?,
      shippingNotes: json['shippingNotes'] as String?,
      warranty: json['warranty'] as String?,
      spareParts: json['spareParts'] as String?,
      risks: json['risks'] as String?,
      safetyNotes: json['safetyNotes'] as String?,
      status: json['status'] as String? ?? 'live',
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      lastEditedAt: json['lastEditedAt'] != null
          ? DateTime.parse(json['lastEditedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'creatorName': creatorName,
    'creatorEmail': creatorEmail,
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
    'coverImages': coverImages,
    'equipmentType': equipmentType,
    'specs': specs,
    'includedItems': includedItems,
    'chosenVariant': chosenVariant,
    'variantNotes': variantNotes,
    'productionTimeline': productionTimeline,
    'shippingCoverage': shippingCoverage,
    'shippingCostHandling': shippingCostHandling,
    'shippingNotes': shippingNotes,
    'warranty': warranty,
    'spareParts': spareParts,
    'risks': risks,
    'safetyNotes': safetyNotes,
    'status': status,
    'publishedAt': publishedAt?.toIso8601String(),
    'lastEditedAt': lastEditedAt?.toIso8601String(),
  };
}

class Pledge {
  final String id;
  final String campaignId;
  final String? backerEmail;
  final String? backerName;
  final String? backerPhone;
  final String? backerNote;
  final int amount;
  final String? rewardId;
  final DateTime createdAt;

  const Pledge({
    required this.id,
    required this.campaignId,
    required this.backerEmail,
    this.backerName,
    this.backerPhone,
    this.backerNote,
    required this.amount,
    required this.rewardId,
    required this.createdAt,
  });

  factory Pledge.fromJson(Map<String, dynamic> json) => Pledge(
    id: json['id'] as String,
    campaignId: json['campaignId'] as String,
    backerEmail: json['backerEmail'] as String?,
    backerName: json['backerName'] as String?,
    backerPhone: json['backerPhone'] as String?,
    backerNote: json['backerNote'] as String?,
    amount: (json['amount'] as num).toInt(),
    rewardId: json['rewardId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'campaignId': campaignId,
    'backerEmail': backerEmail,
    'backerName': backerName,
    'backerPhone': backerPhone,
    'backerNote': backerNote,
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

class PaymentAttemptStatus {
  static const String created = 'created';
  static const String pendingCheckout = 'pending_checkout';
  static const String processing = 'processing';
  static const String paid = 'paid';
  static const String failed = 'failed';
  static const String cancelled = 'cancelled';
  static const String expired = 'expired';
  static const String refunded = 'refunded';

  static const Set<String> terminalStatuses = {
    paid,
    failed,
    cancelled,
    expired,
    refunded,
  };

  static const Set<String> activeStatuses = {
    created,
    pendingCheckout,
    processing,
  };

  static bool isTerminal(String status) => terminalStatuses.contains(status);

  static bool isActive(String status) => activeStatuses.contains(status);
}

class PaymentProvider {
  static const String payMongoCheckout = 'paymongo_checkout';
}

class PaymentAttempt {
  final String id;
  final String campaignId;
  final String createdByUid;
  final String? createdByEmail;
  final String donorName;
  final String? donorPhone;
  final String? donorNote;
  final String? rewardId;
  final int amount;
  final String currency;
  final String provider;
  final List<String> paymentMethodTypes;
  final String status;
  final String? providerCheckoutUrl;
  final String? providerCheckoutId;
  final String? providerPaymentId;
  final String? providerPaymentIntentId;
  final String? referenceNumber;
  final String? failureReason;
  final bool livemode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? expiredAt;
  final Map<String, String> metadata;

  const PaymentAttempt({
    required this.id,
    required this.campaignId,
    required this.createdByUid,
    this.createdByEmail,
    required this.donorName,
    this.donorPhone,
    this.donorNote,
    this.rewardId,
    required this.amount,
    this.currency = 'PHP',
    required this.provider,
    this.paymentMethodTypes = const [],
    required this.status,
    this.providerCheckoutUrl,
    this.providerCheckoutId,
    this.providerPaymentId,
    this.providerPaymentIntentId,
    this.referenceNumber,
    this.failureReason,
    this.livemode = false,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.cancelledAt,
    this.expiredAt,
    this.metadata = const {},
  });

  bool get isTerminal => PaymentAttemptStatus.isTerminal(status);

  bool get isActive => PaymentAttemptStatus.isActive(status);

  PaymentAttempt copyWith({
    String? id,
    String? campaignId,
    String? createdByUid,
    String? createdByEmail,
    String? donorName,
    String? donorPhone,
    String? donorNote,
    String? rewardId,
    int? amount,
    String? currency,
    String? provider,
    List<String>? paymentMethodTypes,
    String? status,
    String? providerCheckoutUrl,
    String? providerCheckoutId,
    String? providerPaymentId,
    String? providerPaymentIntentId,
    String? referenceNumber,
    String? failureReason,
    bool? livemode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? expiredAt,
    Map<String, String>? metadata,
  }) {
    return PaymentAttempt(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      donorName: donorName ?? this.donorName,
      donorPhone: donorPhone ?? this.donorPhone,
      donorNote: donorNote ?? this.donorNote,
      rewardId: rewardId ?? this.rewardId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      provider: provider ?? this.provider,
      paymentMethodTypes: paymentMethodTypes ?? this.paymentMethodTypes,
      status: status ?? this.status,
      providerCheckoutUrl: providerCheckoutUrl ?? this.providerCheckoutUrl,
      providerCheckoutId: providerCheckoutId ?? this.providerCheckoutId,
      providerPaymentId: providerPaymentId ?? this.providerPaymentId,
      providerPaymentIntentId:
          providerPaymentIntentId ?? this.providerPaymentIntentId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      failureReason: failureReason ?? this.failureReason,
      livemode: livemode ?? this.livemode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      expiredAt: expiredAt ?? this.expiredAt,
      metadata: metadata ?? this.metadata,
    );
  }

  factory PaymentAttempt.fromJson(Map<String, dynamic> json) {
    return PaymentAttempt(
      id: json['id'] as String,
      campaignId: json['campaignId'] as String,
      createdByUid: json['createdByUid'] as String,
      createdByEmail: json['createdByEmail'] as String?,
      donorName: json['donorName'] as String? ?? '',
      donorPhone: json['donorPhone'] as String?,
      donorNote: json['donorNote'] as String?,
      rewardId: json['rewardId'] as String?,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String? ?? 'PHP',
      provider: json['provider'] as String? ?? PaymentProvider.payMongoCheckout,
      paymentMethodTypes: json['paymentMethodTypes'] != null
          ? List<String>.from(json['paymentMethodTypes'] as List<dynamic>)
          : const [],
      status: json['status'] as String? ?? PaymentAttemptStatus.created,
      providerCheckoutUrl: json['providerCheckoutUrl'] as String?,
      providerCheckoutId: json['providerCheckoutId'] as String?,
      providerPaymentId: json['providerPaymentId'] as String?,
      providerPaymentIntentId: json['providerPaymentIntentId'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      failureReason: json['failureReason'] as String?,
      livemode: json['livemode'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'] as String)
          : null,
      expiredAt: json['expiredAt'] != null
          ? DateTime.parse(json['expiredAt'] as String)
          : null,
      metadata: json['metadata'] != null
          ? Map<String, String>.from(json['metadata'] as Map<dynamic, dynamic>)
          : const {},
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = toJson()
      ..remove('id')
      ..remove('campaignId');
    return map;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'campaignId': campaignId,
    'createdByUid': createdByUid,
    'createdByEmail': createdByEmail,
    'donorName': donorName,
    'donorPhone': donorPhone,
    'donorNote': donorNote,
    'rewardId': rewardId,
    'amount': amount,
    'currency': currency,
    'provider': provider,
    'paymentMethodTypes': paymentMethodTypes,
    'status': status,
    'providerCheckoutUrl': providerCheckoutUrl,
    'providerCheckoutId': providerCheckoutId,
    'providerPaymentId': providerPaymentId,
    'providerPaymentIntentId': providerPaymentIntentId,
    'referenceNumber': referenceNumber,
    'failureReason': failureReason,
    'livemode': livemode,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
    'expiredAt': expiredAt?.toIso8601String(),
    'metadata': metadata,
  };
}

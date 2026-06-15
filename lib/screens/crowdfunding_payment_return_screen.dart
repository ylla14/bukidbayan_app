import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:bukidbayan_app/screens/campaign_detail_screen.dart';
import 'package:bukidbayan_app/screens/welcome_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_payment_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';

class CrowdfundingPaymentReturnScreen extends StatelessWidget {
  static const routePath = '/crowdfunding/payment-return';

  const CrowdfundingPaymentReturnScreen({
    super.key,
    required this.campaignId,
    required this.attemptId,
    this.paymentStatusHint,
    CrowdfundingPaymentService? paymentService,
  }) : _paymentService = paymentService;

  final String? campaignId;
  final String? attemptId;
  final String? paymentStatusHint;
  final CrowdfundingPaymentService? _paymentService;

  CrowdfundingPaymentService get _service =>
      _paymentService ?? CrowdfundingPaymentService();

  bool get _hasRequiredIds =>
      campaignId != null &&
      campaignId!.trim().isNotEmpty &&
      attemptId != null &&
      attemptId!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalagayan ng Bayad'),
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _hasRequiredIds
              ? StreamBuilder<PaymentAttempt?>(
                  stream: _service.watchPaymentAttempt(
                    campaignId: campaignId!,
                    attemptId: attemptId!,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final rawError = snapshot.error.toString();
                      final isPermissionIssue = rawError.contains(
                        'permission-denied',
                      );
                      return _PaymentReturnCard(
                        icon: Icons.lock_outline,
                        iconColor: Colors.orange.shade700,
                        title: isPermissionIssue
                            ? 'Hindi ma-verify ang bayad'
                            : 'May problema sa pag-check ng status',
                        message: isPermissionIssue
                            ? 'Mag-sign in gamit ang account na ginamit sa checkout para makita ang tunay na kalagayan ng bayad.'
                            : 'Hindi mabasa ang payment attempt sa ngayon. Subukan ulit pagkalipas ng ilang sandali.',
                        attemptId: attemptId!,
                        trailingText:
                            'Ang pledge ay hindi bibilangin hangga\'t walang backend confirmation.',
                        actions: [
                          _PaymentAction(
                            label: 'Bumalik sa Welcome',
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const WelcomeScreen(),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                        ],
                      );
                    }

                    if (!snapshot.hasData) {
                      return _PaymentReturnCard(
                        icon: Icons.hourglass_top_rounded,
                        iconColor: lightColorScheme.primary,
                        title: 'Tinitingnan ang payment attempt',
                        message:
                            'Sandaling hinihintay ang pinakabagong status mula sa backend.',
                        attemptId: attemptId!,
                        trailingText:
                            'Kapag na-verify ang bayad, dito lalabas ang kumpirmadong resulta.',
                      );
                    }

                    final attempt = snapshot.data;
                    if (attempt == null) {
                      return _PaymentReturnCard(
                        icon: Icons.search_off_outlined,
                        iconColor: Colors.orange.shade700,
                        title: 'Hindi nakita ang payment attempt',
                        message:
                            'Walang tumugmang crowdfunding payment attempt para sa ibinigay na detalye.',
                        attemptId: attemptId!,
                        actions: [
                          _PaymentAction(
                            label: 'Buksan ang campaign',
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => CampaignDetailScreen(
                                    campaignId: campaignId!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    }

                    final statusView = _resolveStatusView(attempt);
                    return _PaymentReturnCard(
                      icon: statusView.icon,
                      iconColor: statusView.iconColor,
                      title: statusView.title,
                      message: statusView.message,
                      amountText: formatPeso(attempt.amount),
                      attemptId: attempt.id,
                      trailingText: statusView.trailingText,
                      actions: [
                        _PaymentAction(
                          label: 'Buksan ang campaign',
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => CampaignDetailScreen(
                                  campaignId: attempt.campaignId,
                                ),
                              ),
                            );
                          },
                        ),
                        _PaymentAction(
                          label: 'Bumalik sa Welcome',
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    );
                  },
                )
              : _PaymentReturnCard(
                  icon: Icons.link_off_outlined,
                  iconColor: Colors.orange.shade700,
                  title: 'Kulang ang return details',
                  message:
                      'Hindi sapat ang datos ng redirect para mahanap ang payment attempt.',
                  trailingText:
                      'Gamitin ang campaign page para tingnan muli ang status ng suporta mo.',
                  actions: [
                    _PaymentAction(
                      label: 'Bumalik sa Welcome',
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const WelcomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  _PaymentStatusView _resolveStatusView(PaymentAttempt attempt) {
    switch (attempt.status) {
      case PaymentAttemptStatus.paid:
        return _PaymentStatusView(
          icon: Icons.verified_rounded,
          iconColor: Colors.green.shade700,
          title: 'Nakumpirma na ang bayad',
          message:
              'Na-verify na ng backend ang bayad mo. Kasama na ito sa campaign totals at pledge records.',
          trailingText:
              'Reference: ${attempt.providerPaymentId ?? attempt.providerCheckoutId ?? attempt.id}',
        );
      case PaymentAttemptStatus.failed:
        return _PaymentStatusView(
          icon: Icons.error_outline,
          iconColor: Colors.red.shade700,
          title: 'Hindi natuloy ang bayad',
          message: attempt.failureReason?.trim().isNotEmpty == true
              ? attempt.failureReason!
              : 'Nabigo ang secure checkout at walang nalikhang pledge.',
          trailingText:
              'Maaari kang bumalik sa campaign at subukang muli kapag handa ka na.',
        );
      case PaymentAttemptStatus.cancelled:
        return _PaymentStatusView(
          icon: Icons.cancel_outlined,
          iconColor: Colors.orange.shade700,
          title: 'Kinansela ang checkout',
          message:
              'Hindi natuloy ang bayad at walang nalikhang pledge para sa campaign na ito.',
          trailingText:
              'Maaari kang bumalik sa campaign kung gusto mong subukan muli.',
        );
      case PaymentAttemptStatus.expired:
        return _PaymentStatusView(
          icon: Icons.timer_off_outlined,
          iconColor: Colors.orange.shade700,
          title: 'Nag-expire ang checkout',
          message:
              'Lumampas na sa oras ang checkout session kaya walang nalikhang pledge.',
          trailingText:
              'Kailangan gumawa ng panibagong checkout attempt para magpatuloy.',
        );
      default:
        if ((paymentStatusHint ?? '').toLowerCase() == 'cancelled') {
          return _PaymentStatusView(
            icon: Icons.cancel_outlined,
            iconColor: Colors.orange.shade700,
            title: 'Kinansela mo ang checkout',
            message:
                'Walang naitalang bayad mula sa redirect na ito. Hindi ito bibilang bilang pledge maliban kung may hiwalay na backend confirmation.',
            trailingText:
                'Kung gusto mong tumuloy, bumalik sa campaign at gumawa ng panibagong checkout.',
          );
        }

        return _PaymentStatusView(
          icon: Icons.hourglass_top_rounded,
          iconColor: lightColorScheme.primary,
          title: 'Hinihintay ang kumpirmasyon ng bayad',
          message:
              'Natanggap ang pagbabalik mula sa checkout, pero backend pa rin ang magpapasya kung matagumpay ang bayad.',
          trailingText:
              'Hindi pa mababago ang pledge records at campaign totals hangga\'t hindi nagiging `paid` ang payment attempt.',
        );
    }
  }
}

class _PaymentStatusView {
  const _PaymentStatusView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.trailingText,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? trailingText;
}

class _PaymentAction {
  const _PaymentAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _PaymentReturnCard extends StatelessWidget {
  const _PaymentReturnCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.amountText,
    this.attemptId,
    this.trailingText,
    this.actions = const [],
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? amountText;
  final String? attemptId;
  final String? trailingText;
  final List<_PaymentAction> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: iconColor.withValues(alpha: 0.22)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: lightColorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                  if (amountText != null || attemptId != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (amountText != null)
                            Text(
                              'Halaga: $amountText',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (attemptId != null) ...[
                            if (amountText != null) const SizedBox(height: 6),
                            SelectableText(
                              'Attempt ID: $attemptId',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (trailingText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      trailingText!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: actions
                          .map(
                            (action) => OutlinedButton(
                              onPressed: action.onPressed,
                              child: Text(action.label),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:bukidbayan_app/screens/campaign_detail_screen.dart';
import 'package:bukidbayan_app/screens/welcome_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_payment_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';

class CrowdfundingPaymentReturnScreen extends StatefulWidget {
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

  @override
  State<CrowdfundingPaymentReturnScreen> createState() =>
      _CrowdfundingPaymentReturnScreenState();
}

class _CrowdfundingPaymentReturnScreenState
    extends State<CrowdfundingPaymentReturnScreen> {
  bool _finalizing = false;
  String? _finalizationError;

  CrowdfundingPaymentService get _service =>
      widget._paymentService ?? CrowdfundingPaymentService();

  bool get _hasRequiredIds =>
      widget.campaignId != null &&
      widget.campaignId!.trim().isNotEmpty &&
      widget.attemptId != null &&
      widget.attemptId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _attemptFinalize();
  }

  Future<void> _attemptFinalize() async {
    if (!_hasRequiredIds) return;
    if ((widget.paymentStatusHint ?? '').toLowerCase() == 'cancelled') return;

    setState(() {
      _finalizing = true;
      _finalizationError = null;
    });
    try {
      await _service.finalizePaymentFromRedirect(
        campaignId: widget.campaignId!,
        attemptId: widget.attemptId!,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _finalizationError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

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
              ? _finalizing
                  ? _buildFinalizing()
                  : _finalizationError != null
                  ? _buildFinalizationError()
                  : StreamBuilder<PaymentAttempt?>(
                      stream: _service.watchPaymentAttempt(
                        campaignId: widget.campaignId!,
                        attemptId: widget.attemptId!,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _PaymentReturnCard(
                            icon: Icons.lock_outline,
                            iconColor: Colors.orange.shade700,
                            title: 'Hindi ma-verify ang bayad',
                            message:
                                'May problema sa pagbabasa ng payment status. Subukan ulit pagkalipas ng ilang sandali.',
                            attemptId: widget.attemptId!,
                            actions: [_backToWelcomeAction(context)],
                          );
                        }

                        if (!snapshot.hasData) {
                          return _PaymentReturnCard(
                            icon: Icons.hourglass_top_rounded,
                            iconColor: lightColorScheme.primary,
                            title: 'Tinitingnan ang payment status',
                            message: 'Sandaling hinihintay ang resulta...',
                            attemptId: widget.attemptId!,
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
                            attemptId: widget.attemptId!,
                            actions: [
                              _openCampaignAction(context, widget.campaignId!),
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
                            _openCampaignAction(context, attempt.campaignId),
                            _backToWelcomeAction(context),
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
                  actions: [_backToWelcomeAction(context)],
                ),
        ),
      ),
    );
  }

  Widget _buildFinalizing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: lightColorScheme.primary),
          const SizedBox(height: 20),
          const Text(
            'Kine-confirm ang iyong bayad...',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Huwag isara ang screen na ito.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalizationError() {
    return _PaymentReturnCard(
      icon: Icons.wifi_off_outlined,
      iconColor: Colors.orange.shade700,
      title: 'Hindi ma-kumpirma ang bayad',
      message: _finalizationError ??
          'May problema sa pag-verify ng bayad sa PayMongo.',
      trailingText:
          'Kung natuloy ang bayad sa PayMongo, maaaring delayed lang ang kumpirmasyon. Subukan ulit.',
      attemptId: widget.attemptId,
      actions: [
        _PaymentAction(label: 'Subukan Ulit', onPressed: _attemptFinalize),
        if (widget.campaignId != null)
          _openCampaignAction(context, widget.campaignId!),
      ],
    );
  }

  _PaymentAction _backToWelcomeAction(BuildContext context) {
    return _PaymentAction(
      label: 'Bumalik sa Welcome',
      onPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      },
    );
  }

  _PaymentAction _openCampaignAction(BuildContext context, String campaignId) {
    return _PaymentAction(
      label: 'Buksan ang campaign',
      onPressed: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CampaignDetailScreen(campaignId: campaignId),
          ),
        );
      },
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
              'Na-verify ang iyong bayad sa PayMongo. Kasama na ito sa campaign totals at pledge records.',
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
        if ((widget.paymentStatusHint ?? '').toLowerCase() == 'cancelled') {
          return _PaymentStatusView(
            icon: Icons.cancel_outlined,
            iconColor: Colors.orange.shade700,
            title: 'Kinansela mo ang checkout',
            message:
                'Walang naitalang bayad mula sa redirect na ito. Hindi ito bibilang bilang pledge.',
            trailingText:
                'Kung gusto mong tumuloy, bumalik sa campaign at gumawa ng panibagong checkout.',
          );
        }
        return _PaymentStatusView(
          icon: Icons.hourglass_top_rounded,
          iconColor: lightColorScheme.primary,
          title: 'Hinihintay ang kumpirmasyon',
          message:
              'Natanggap ang pagbabalik mula sa checkout. Tinitingnan ang status ng bayad...',
          trailingText: null,
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

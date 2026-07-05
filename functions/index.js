const crypto = require('crypto');

const admin = require('firebase-admin');
const { logger } = require('firebase-functions');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');

admin.initializeApp();

const db = admin.firestore();

const REGION = 'asia-southeast1';
const PAYMONGO_API_BASE = 'https://api.paymongo.com';
const DEFAULT_PAYMENT_METHOD_TYPES = ['qrph'];
const ACTIVE_PAYMENT_ATTEMPT_STATUSES = new Set([
  'created',
  'pending_checkout',
  'processing',
]);
const CANCELLABLE_PAYMENT_ATTEMPT_STATUSES = new Set([
  'created',
  'pending_checkout',
]);

function nowIso() {
  return new Date().toISOString();
}

function parseBoolean(value, fallback = false) {
  if (value == null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function parseCsv(value, fallback = []) {
  if (!value) return fallback;
  return String(value)
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
}

function getPaymongoConfig() {
  return {
    secretKey: process.env.PAYMONGO_SECRET_KEY || '',
    webhookSecret: process.env.PAYMONGO_WEBHOOK_SECRET || '',
    successUrl: process.env.PAYMONGO_SUCCESS_URL || '',
    cancelUrl: process.env.PAYMONGO_CANCEL_URL || '',
    paymentMethodTypes: parseCsv(
        process.env.PAYMONGO_PAYMENT_METHOD_TYPES,
        DEFAULT_PAYMENT_METHOD_TYPES,
    ),
    passOnFees: parseBoolean(process.env.PAYMONGO_PASS_ON_FEES, false),
  };
}

function buildRedirectUrl(baseUrl, params) {
  const url = new URL(baseUrl);
  Object.entries(params).forEach(([key, value]) => {
    if (value != null && value !== '') {
      url.searchParams.set(key, String(value));
    }
  });
  return url.toString();
}

function buildBasicAuthHeader(secretKey) {
  return `Basic ${Buffer.from(`${secretKey}:`).toString('base64')}`;
}

function summarizePaymongoError(json) {
  const errors = Array.isArray(json?.errors) ? json.errors : [];
  if (!errors.length) {
    return 'PayMongo checkout session creation failed.';
  }

  return errors
      .map((error) => error?.detail || error?.code || 'Unknown PayMongo error')
      .join(' ');
}

function extractCheckoutData(json) {
  const data = json?.data;
  if (!data?.id || !data?.attributes?.checkout_url) {
    throw new Error('PayMongo response did not include a checkout URL.');
  }
  return data;
}

function compareAttemptsByCreatedAt(left, right) {
  const leftCreatedAt = String(left?.createdAt || '');
  const rightCreatedAt = String(right?.createdAt || '');
  if (leftCreatedAt !== rightCreatedAt) {
    return leftCreatedAt.localeCompare(rightCreatedAt);
  }
  return String(left?.id || '').localeCompare(String(right?.id || ''));
}

function isCampaignEnded(campaign) {
  const status = String(campaign?.status || '');
  if (status.startsWith('ended')) {
    return true;
  }

  const endTime = Date.parse(String(campaign?.endDate || ''));
  return Number.isFinite(endTime) && Date.now() > endTime;
}

function findSelectedReward(campaign, rewardId) {
  if (!rewardId || !Array.isArray(campaign?.rewards)) {
    return null;
  }

  return campaign.rewards.find((item) => item?.id === rewardId) || null;
}

function validateAttemptAgainstCampaign({attempt, campaign}) {
  const amount = Number(attempt?.amount || 0);
  if (!attempt?.createdByUid) {
    return 'You must be signed in before creating a checkout.';
  }
  if (!attempt?.donorName || !String(attempt.donorName).trim()) {
    return 'Supporter name is required.';
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    return 'Amount must be greater than zero.';
  }
  if (
    (attempt.createdByUid && campaign?.creatorUid &&
      attempt.createdByUid === campaign.creatorUid) ||
    (attempt.createdByEmail && campaign?.creatorEmail &&
      attempt.createdByEmail === campaign.creatorEmail)
  ) {
    return 'You cannot support your own campaign.';
  }
  if (isCampaignEnded(campaign)) {
    return 'This campaign has already ended.';
  }

  if (attempt.rewardId) {
    const reward = findSelectedReward(campaign, attempt.rewardId);
    if (!reward) {
      return 'Selected reward tier is no longer available.';
    }

    const minPledge = Number(reward.minPledge || 0);
    if (amount < minPledge) {
      return `Amount is below the minimum pledge for this reward tier (${minPledge}).`;
    }
  }

  return null;
}

async function findPaymentAttemptConflict({campaignId, attempt}) {
  const createdByUid = attempt?.createdByUid;
  if (!createdByUid) {
    return null;
  }

  const [pledgeSnap, attemptsSnap] = await Promise.all([
    db.collection(`campaigns/${campaignId}/pledges`)
        .where('backerUid', '==', createdByUid)
        .limit(1)
        .get(),
    db.collection(`campaigns/${campaignId}/payment_attempts`)
        .where('createdByUid', '==', createdByUid)
        .get(),
  ]);

  if (!pledgeSnap.empty) {
    return {type: 'paid_pledge'};
  }

  const activeAttempts = attemptsSnap.docs
      .map((doc) => ({id: doc.id, ...doc.data()}))
      .filter((item) => ACTIVE_PAYMENT_ATTEMPT_STATUSES.has(item.status))
      .sort(compareAttemptsByCreatedAt);

  if (!activeAttempts.length) {
    return null;
  }

  const canonicalAttempt = activeAttempts[0];
  if (canonicalAttempt.id !== attempt.id) {
    return {type: 'active_attempt', attempt: canonicalAttempt};
  }

  return null;
}

async function markAttemptFailed(attemptRef, reason, extra = {}) {
  await attemptRef.set(
      {
        status: 'failed',
        failureReason: reason,
        updatedAt: nowIso(),
        ...extra,
      },
      {merge: true},
  );
}

function getValidPaymongoImageUrls(campaign) {
  const image = typeof campaign.image === 'string' ? campaign.image.trim() : '';
  if (!image || campaign.isAssetImage) {
    return [];
  }

  try {
    const url = new URL(image);
    if (url.protocol === 'http:' || url.protocol === 'https:') {
      return [url.toString()];
    }
  } catch (_) {
    return [];
  }

  return [];
}

function buildCheckoutPayload({attempt, campaign, config}) {
  const reward =
      Array.isArray(campaign.rewards) &&
      attempt.rewardId
          ? campaign.rewards.find((item) => item.id === attempt.rewardId)
          : null;

  const successUrl = buildRedirectUrl(config.successUrl, {
    paymentStatus: 'success',
    campaignId: campaign.id,
    attemptId: attempt.id,
  });
  const cancelUrl = buildRedirectUrl(config.cancelUrl, {
    paymentStatus: 'cancelled',
    campaignId: campaign.id,
    attemptId: attempt.id,
  });

  return {
    data: {
      attributes: {
        billing: {
          email: attempt.createdByEmail || undefined,
          name: attempt.donorName,
          phone: attempt.donorPhone || undefined,
        },
        cancel_url: cancelUrl,
        success_url: successUrl,
        description: campaign.shortBlurb || campaign.title,
        line_items: [
          {
            amount: attempt.amount * 100,
            currency: attempt.currency,
            description: reward?.title || campaign.shortBlurb || campaign.title,
            images: getValidPaymongoImageUrls(campaign),
            name: campaign.title,
            quantity: 1,
          },
        ],
        metadata: {
          amount_pesos: String(attempt.amount),
          campaign_id: campaign.id,
          creator_name: campaign.creatorName || '',
          payment_attempt_id: attempt.id,
          reward_id: attempt.rewardId || '',
          supporter_uid: attempt.createdByUid,
        },
        pass_on_fees: config.passOnFees,
        payment_method_types:
          attempt.paymentMethodTypes?.length
              ? attempt.paymentMethodTypes
              : config.paymentMethodTypes,
        reference_number: attempt.id,
        send_email_receipt: false,
        show_description: true,
        show_line_items: true,
      },
    },
  };
}

async function createPaymongoCheckoutSession(attemptId, payload, secretKey) {
  const response = await fetch(`${PAYMONGO_API_BASE}/v2/checkout_sessions`, {
    method: 'POST',
    headers: {
      Authorization: buildBasicAuthHeader(secretKey),
      'Content-Type': 'application/json',
      'Idempotency-Key': attemptId,
    },
    body: JSON.stringify(payload),
  });
  const json = await response.json();
  if (!response.ok) {
    throw new Error(summarizePaymongoError(json));
  }
  return extractCheckoutData(json);
}

function parseWebhookPayload(rawPayload) {
  if (!rawPayload || typeof rawPayload !== 'object') {
    return null;
  }

  if (rawPayload.event_type === 'send.webhook' && rawPayload.data) {
    return {
      eventId: rawPayload.data.id || '',
      type: rawPayload.data.type || '',
      livemode: Boolean(rawPayload.data.livemode),
      resource: rawPayload.data.data || null,
      rawPayload,
    };
  }

  const eventData = rawPayload.data;
  const attributes = eventData?.attributes;
  if (!eventData?.id || !attributes?.type) {
    return null;
  }

  return {
    eventId: eventData.id,
    type: attributes.type,
    livemode: Boolean(attributes.livemode),
    resource: attributes.data || null,
    rawPayload,
  };
}

function safeTimingEqual(left, right) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function verifyWebhookSignature(rawBody, signatureHeader, webhookSecret) {
  if (!signatureHeader || !webhookSecret) {
    return false;
  }

  const digestHex = crypto
      .createHmac('sha256', webhookSecret)
      .update(rawBody)
      .digest('hex');
  const digestBase64 = crypto
      .createHmac('sha256', webhookSecret)
      .update(rawBody)
      .digest('base64');

  const headerValue = String(signatureHeader).trim();
  if (safeTimingEqual(headerValue, digestHex) ||
      safeTimingEqual(headerValue, digestBase64)) {
    return true;
  }

  const candidates = headerValue
      .split(',')
      .map((part) => part.trim())
      .map((part) => part.includes('=') ? part.split('=').slice(1).join('=') : part)
      .filter(Boolean);

  return candidates.some((candidate) =>
    safeTimingEqual(candidate, digestHex) ||
    safeTimingEqual(candidate, digestBase64),
  );
}

function applyClientCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Max-Age', '3600');
}

function extractBearerToken(req) {
  const header = String(req.get('Authorization') || '').trim();
  if (!header.toLowerCase().startsWith('bearer ')) {
    return '';
  }

  return header.slice(7).trim();
}

async function authenticateClientRequest(req) {
  const idToken = extractBearerToken(req);
  if (!idToken) {
    return null;
  }

  try {
    return await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    logger.warn('Unable to verify Firebase ID token for client request.', {
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

async function finalizePaidAttempt({
  campaignId,
  attemptId,
  checkoutSessionId,
  paymentId,
  paymentIntentId,
  eventId,
  livemode,
  checkoutSession,
}) {
  const attemptRef = db.doc(`campaigns/${campaignId}/payment_attempts/${attemptId}`);
  const campaignRef = db.doc(`campaigns/${campaignId}`);
  const pledgeRef = db.doc(`campaigns/${campaignId}/pledges/${attemptId}`);
  const eventRef = db.doc(`payment_webhook_events/${eventId}`);
  const processedAt = nowIso();

  const attemptSnap = await attemptRef.get();
  if (!attemptSnap.exists) {
    logger.warn('Webhook references unknown payment attempt.', {
      attemptId,
      campaignId,
      eventId,
    });
    await eventRef.set(
        {
          attemptId,
          campaignId,
          eventId,
          livemode,
          processedAt,
          skipped: true,
          skipReason: 'attempt_not_found',
        },
        {merge: true},
    );
    return;
  }

  const attempt = {id: attemptSnap.id, ...attemptSnap.data()};
  const existingBackerPledgeQuery = attempt.createdByUid
      ? db
          .collection(`campaigns/${campaignId}/pledges`)
          .where('backerUid', '==', attempt.createdByUid)
          .limit(1)
      : null;

  await db.runTransaction(async (transaction) => {
    const [
      eventDoc,
      campaignDoc,
      attemptDoc,
      pledgeDoc,
    ] = await Promise.all([
      transaction.get(eventRef),
      transaction.get(campaignRef),
      transaction.get(attemptRef),
      transaction.get(pledgeRef),
    ]);
    const existingBackerPledgeDoc = existingBackerPledgeQuery
        ? await transaction.get(existingBackerPledgeQuery)
        : null;

    if (eventDoc.exists) {
      return;
    }

    if (!campaignDoc.exists || !attemptDoc.exists) {
      transaction.set(eventRef, {
        attemptId,
        campaignId,
        eventId,
        livemode,
        processedAt,
        skipped: true,
        skipReason: 'campaign_or_attempt_missing',
      });
      return;
    }

    if (pledgeDoc.exists || attemptDoc.data()?.status === 'paid') {
      transaction.set(eventRef, {
        attemptId,
        campaignId,
        eventId,
        livemode,
        processedAt,
        skipped: true,
        skipReason: 'already_finalized',
      });
      return;
    }

    const campaign = campaignDoc.data();
    const paidAt = processedAt;
    const isNewBacker =
        !existingBackerPledgeDoc || existingBackerPledgeDoc.empty;
    const nextPledgedAmount = Number(campaign?.pledgedAmount || 0) + Number(attempt.amount || 0);
    const nextBackersCount = Number(campaign?.backersCount || 0) + (isNewBacker ? 1 : 0);

    transaction.set(pledgeRef, {
      amount: attempt.amount,
      backerEmail: attempt.createdByEmail || null,
      backerName: attempt.donorName || null,
      backerNote: attempt.donorNote || null,
      backerPhone: attempt.donorPhone || null,
      backerUid: attempt.createdByUid || null,
      createdAt: paidAt,
      paidAt,
      paymentAttemptId: attemptId,
      provider: attempt.provider || 'paymongo_checkout',
      providerPaymentId: paymentId || null,
      rewardId: attempt.rewardId || null,
    });

    transaction.update(campaignRef, {
      backersCount: nextBackersCount,
      pledgedAmount: nextPledgedAmount,
    });

    transaction.update(attemptRef, {
      completedAt: paidAt,
      failureReason: null,
      livemode,
      providerCheckoutId: checkoutSessionId || null,
      providerPaymentId: paymentId || null,
      providerPaymentIntentId: paymentIntentId || null,
      status: 'paid',
      updatedAt: paidAt,
    });

    transaction.set(eventRef, {
      attemptId,
      campaignId,
      checkoutSessionId: checkoutSessionId || null,
      eventId,
      eventType: 'checkout_session.payment.paid',
      livemode,
      paymentId: paymentId || null,
      processedAt,
      rawCheckoutSessionId: checkoutSession?.id || null,
    });
  });
}

exports.onCrowdfundingPaymentAttemptCreated = onDocumentCreated(
    {
      document: 'campaigns/{campaignId}/payment_attempts/{attemptId}',
      region: REGION,
    },
    async (event) => {
      const snap = event.data;
      if (!snap?.exists) {
        return;
      }

      const attempt = {id: snap.id, ...snap.data()};
      const campaignId = event.params.campaignId;
      const attemptRef = snap.ref;
      if (attempt.provider !== 'paymongo_checkout' || attempt.status !== 'created') {
        return;
      }

      const config = getPaymongoConfig();
      if (!config.secretKey || !config.successUrl || !config.cancelUrl) {
        await markAttemptFailed(
            attemptRef,
            'PayMongo checkout is not configured yet. Add PAYMONGO_SECRET_KEY, PAYMONGO_SUCCESS_URL, and PAYMONGO_CANCEL_URL.',
        );
        return;
      }

      const campaignSnap = await db.doc(`campaigns/${campaignId}`).get();
      if (!campaignSnap.exists) {
        await markAttemptFailed(attemptRef, 'Campaign not found for this payment attempt.');
        return;
      }

      const campaign = {id: campaignSnap.id, ...campaignSnap.data()};
      const validationError = validateAttemptAgainstCampaign({
        attempt,
        campaign,
      });
      if (validationError) {
        await markAttemptFailed(attemptRef, validationError);
        return;
      }

      const conflict = await findPaymentAttemptConflict({
        campaignId,
        attempt,
      });
      if (conflict?.type === 'paid_pledge') {
        await markAttemptFailed(
            attemptRef,
            'You already have a confirmed pledge for this campaign.',
        );
        return;
      }
      if (conflict?.type === 'active_attempt') {
        const hasCheckoutUrl =
          conflict.attempt?.providerCheckoutUrl &&
          String(conflict.attempt.providerCheckoutUrl).trim();
        await markAttemptFailed(
            attemptRef,
            hasCheckoutUrl
                ? 'You already have a checkout in progress for this campaign. Please continue that checkout instead of creating a new pledge.'
                : 'You already have a pledge attempt being prepared for this campaign. Please wait a moment before trying again.',
            {
              duplicateOfAttemptId: conflict.attempt.id,
              duplicateOfStatus: conflict.attempt.status,
            },
        );
        return;
      }

      try {
        const payload = buildCheckoutPayload({attempt, campaign, config});
        const checkoutData = await createPaymongoCheckoutSession(
            attempt.id,
            payload,
            config.secretKey,
        );

        await attemptRef.set(
            {
              providerCheckoutId: checkoutData.id,
              providerCheckoutUrl: checkoutData.attributes.checkout_url,
              referenceNumber: attempt.id,
              status: 'pending_checkout',
              updatedAt: nowIso(),
              livemode: Boolean(checkoutData.attributes.livemode),
            },
            {merge: true},
        );
      } catch (error) {
        logger.error('Failed to create PayMongo checkout session.', {
          attemptId: attempt.id,
          campaignId,
          error: error instanceof Error ? error.message : String(error),
        });
        await markAttemptFailed(
            attemptRef,
            error instanceof Error ? error.message : 'Unable to create PayMongo checkout session.',
        );
      }
    },
);

exports.cancelCrowdfundingPaymentAttempt = onRequest(
    {region: REGION},
    async (req, res) => {
      applyClientCors(res);
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).json({error: 'Method not allowed'});
        return;
      }

      const decodedToken = await authenticateClientRequest(req);
      if (!decodedToken?.uid) {
        res.status(401).json({
          error: 'You must be signed in to cancel this checkout.',
        });
        return;
      }

      const campaignId = String(req.body?.campaignId || '').trim();
      const attemptId = String(req.body?.attemptId || '').trim();
      if (!campaignId || !attemptId) {
        res.status(400).json({
          error: 'campaignId and attemptId are required.',
        });
        return;
      }

      const attemptRef =
        db.doc(`campaigns/${campaignId}/payment_attempts/${attemptId}`);

      try {
        const result = await db.runTransaction(async (transaction) => {
          const attemptDoc = await transaction.get(attemptRef);
          if (!attemptDoc.exists) {
            return {
              error: 'Payment attempt not found.',
              httpStatus: 404,
            };
          }

          const attempt = {id: attemptDoc.id, ...attemptDoc.data()};
          if (attempt.createdByUid !== decodedToken.uid) {
            return {
              error: 'You can only cancel your own checkout attempt.',
              httpStatus: 403,
            };
          }

          const attemptStatus = String(attempt.status || '');
          if (attemptStatus === 'paid') {
            return {
              attemptId,
              campaignId,
              ignored: true,
              message:
                'This pledge has already been confirmed and can no longer be cancelled.',
              status: attemptStatus,
            };
          }

          if (attemptStatus === 'processing') {
            return {
              attemptId,
              campaignId,
              ignored: true,
              message:
                'This payment is already being processed and can no longer be cancelled from the return page.',
              status: attemptStatus,
            };
          }

          if (!CANCELLABLE_PAYMENT_ATTEMPT_STATUSES.has(attemptStatus)) {
            return {
              attemptId,
              campaignId,
              ignored: true,
              status: attemptStatus || 'unknown',
            };
          }

          const cancelledAt = nowIso();
          transaction.update(attemptRef, {
            cancelledAt,
            failureReason:
              attempt.failureReason ||
              'Checkout was cancelled by the supporter before payment confirmation.',
            status: 'cancelled',
            updatedAt: cancelledAt,
          });

          return {
            attemptId,
            campaignId,
            cancelledAt,
            status: 'cancelled',
          };
        });

        if (result.error) {
          res.status(result.httpStatus || 400).json({error: result.error});
          return;
        }

        res.status(200).json(result);
      } catch (error) {
        logger.error('Failed to cancel crowdfunding payment attempt.', {
          attemptId,
          campaignId,
          error: error instanceof Error ? error.message : String(error),
          uid: decodedToken.uid,
        });
        res.status(500).json({
          error: 'Unable to cancel the checkout attempt right now.',
        });
      }
    },
);

exports.paymongoCrowdfundingWebhook = onRequest(
    {region: REGION},
    async (req, res) => {
      if (req.method !== 'POST') {
        res.status(405).json({error: 'Method not allowed'});
        return;
      }

      const config = getPaymongoConfig();
      if (!config.webhookSecret) {
        logger.error('PAYMONGO_WEBHOOK_SECRET is not configured.');
        res.status(500).json({error: 'Webhook secret not configured'});
        return;
      }

      const signatureHeader =
        req.get('Paymongo-Signature') || req.get('paymongo-signature');
      const rawBody = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));
      if (!verifyWebhookSignature(rawBody, signatureHeader, config.webhookSecret)) {
        res.status(400).json({error: 'Invalid webhook signature'});
        return;
      }

      const parsedPayload = parseWebhookPayload(req.body);
      if (!parsedPayload) {
        res.status(200).json({received: true, ignored: true, reason: 'unsupported_payload'});
        return;
      }

      if (parsedPayload.type !== 'checkout_session.payment.paid') {
        res.status(200).json({received: true, ignored: true, type: parsedPayload.type});
        return;
      }

      const checkoutSession = parsedPayload.resource;
      const metadata = checkoutSession?.attributes?.metadata || {};
      const attemptId =
        metadata.payment_attempt_id ||
        checkoutSession?.attributes?.reference_number ||
        '';
      const campaignId = metadata.campaign_id || '';
      const payment = Array.isArray(checkoutSession?.attributes?.payments) &&
          checkoutSession.attributes.payments.length
          ? checkoutSession.attributes.payments[0]
          : null;

      if (!attemptId || !campaignId) {
        logger.error('Webhook payload missing campaign or attempt identifiers.', {
          eventId: parsedPayload.eventId,
          type: parsedPayload.type,
        });
        res.status(400).json({error: 'Missing campaign or payment attempt identifier'});
        return;
      }

      try {
        await finalizePaidAttempt({
          attemptId,
          campaignId,
          checkoutSession,
          checkoutSessionId: checkoutSession?.id || '',
          eventId: parsedPayload.eventId,
          livemode: parsedPayload.livemode,
          paymentId: payment?.id || '',
          paymentIntentId: checkoutSession?.attributes?.payment_intent?.id || '',
        });
        res.status(200).json({received: true});
      } catch (error) {
        logger.error('Failed to finalize crowdfunding payment attempt.', {
          attemptId,
          campaignId,
          eventId: parsedPayload.eventId,
          error: error instanceof Error ? error.message : String(error),
        });
        res.status(500).json({error: 'Webhook processing failed'});
      }
    },
);

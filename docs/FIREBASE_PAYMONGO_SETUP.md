# Firebase Owner Handoff For Crowdfunding PayMongo Sandbox

Last updated: 2026-06-16
Branch: `feature/payments-api-sandbox`
Scope: Crowdfunding payments only
Firebase project in repo config: `bukidbayan-capstoners`

## Who This Is For

This note is for the person who has Firebase project access.

The app-side crowdfunding payment scaffold is already in the repo, but the current developer does **not** have Firebase deploy/config access. The remaining work on your side is deployment and environment setup.

## What Has Already Been Implemented

The repo already contains the crowdfunding-only PayMongo sandbox scaffold:

- Flutter client creates `payment_attempts`, not final pledges
- backend is responsible for creating PayMongo checkout sessions
- backend webhook is responsible for finalizing successful payments
- client cannot directly create successful `pledges`
- campaign counters are only meant to change after backend-confirmed payment success

Relevant files already present:

- `functions/index.js`
- `functions/package.json`
- `firebase.json`
- `firestore.rules`
- `lib/services/crowdfunding_payment_service.dart`
- `lib/screens/crowdfunding_payment_return_screen.dart`
- `lib/main.dart`
- `web/paymongo-return.html`

## Important Current Behavior

- Provider target is PayMongo Hosted Checkout
- initial payment method default is `qrph` only
- this is intentional because the current PayMongo account only has `QR Ph` active
- donors may still pay through GCash/Maya apps by scanning the QRPH code if their wallet supports it
- redirect success on the client is **not** trusted as final payment success
- final `Pledge` creation happens only after backend-confirmed webhook processing

## What You Need To Configure

Please configure the Firebase project and deployment for this branch with these requirements:

### 1. Functions Environment Variables

The Functions runtime needs:

```env
PAYMONGO_SECRET_KEY=sk_test_REPLACE_ME
PAYMONGO_SUCCESS_URL=https://<hosting-domain>/paymongo-return.html
PAYMONGO_CANCEL_URL=https://<hosting-domain>/paymongo-return.html
PAYMONGO_PAYMENT_METHOD_TYPES=qrph
PAYMONGO_PASS_ON_FEES=false
PAYMONGO_WEBHOOK_SECRET=whsec_REPLACE_ME
```

Notes:

- keep `PAYMONGO_PAYMENT_METHOD_TYPES=qrph` for the first sandbox pass
- `PAYMONGO_SUCCESS_URL` and `PAYMONGO_CANCEL_URL` should point to the static page `paymongo-return.html`
- do **not** point PayMongo directly to a Flutter hash route

### 2. Firebase Hosting

This repo now includes:

- `web/paymongo-return.html`

That page exists specifically to translate a normal PayMongo redirect URL into the Flutter web route:

- `/crowdfunding/payment-return`

If Hosting is used for this app, please make sure:

- the built Flutter web app is deployed
- `paymongo-return.html` is publicly reachable
- normal SPA routing still works for the main Flutter app

Expected hosted return URL shape:

- `https://<hosting-domain>/paymongo-return.html`

### 3. Firestore Rules

Please deploy the latest `firestore.rules`.

The current rules are already written to support the crowdfunding payment model:

- authenticated user can create own `payment_attempt`
- client cannot create/update/delete final `pledges`
- client cannot directly mutate campaign counters

### 4. Cloud Functions

Please deploy the current Functions code in `functions/index.js`.

It contains:

- Firestore trigger: creates PayMongo checkout sessions for new crowdfunding `payment_attempts`
- HTTP webhook: finalizes confirmed PayMongo payments into final `pledges`

### 5. PayMongo Webhook

Please create/register a PayMongo webhook that points to the deployed Firebase Function:

- `paymongoCrowdfundingWebhook`

Subscribe to:

- `checkout_session.payment.paid`

Then place the webhook secret into the Functions environment as:

- `PAYMONGO_WEBHOOK_SECRET`

## Deployment Sequence Requested

Please use this order:

1. Ensure the Functions environment contains the PayMongo values above.
2. Deploy Firebase Hosting for the Flutter web app.
3. Confirm `https://<hosting-domain>/paymongo-return.html` is reachable.
4. Set:
   - `PAYMONGO_SUCCESS_URL=https://<hosting-domain>/paymongo-return.html`
   - `PAYMONGO_CANCEL_URL=https://<hosting-domain>/paymongo-return.html`
5. Deploy Firestore rules.
6. Deploy the crowdfunding payments Functions code.
7. Copy the exact deployed URL for `paymongoCrowdfundingWebhook`.
8. Register that URL in PayMongo webhook settings.
9. Add the resulting `PAYMONGO_WEBHOOK_SECRET` to Functions env.
10. Redeploy Functions.

## Expected End-To-End Result

After deployment, this should happen:

1. User opens a live campaign and taps support.
2. App creates:
   - `campaigns/{campaignId}/payment_attempts/{attemptId}`
3. Backend trigger adds:
   - `providerCheckoutId`
   - `providerCheckoutUrl`
   - `status: pending_checkout`
4. User completes PayMongo QRPH sandbox payment.
5. PayMongo redirects through:
   - `/paymongo-return.html`
   - then into Flutter route `/crowdfunding/payment-return`
6. PayMongo webhook sends `checkout_session.payment.paid`.
7. Backend webhook finalizes:
   - `payment_attempt.status = paid`
   - `campaigns/{campaignId}/pledges/{attemptId}`
   - campaign `pledgedAmount`
   - campaign `backersCount`

## What To Verify After Deployment

Please verify all of the following:

- `payment_attempt` document is created successfully
- checkout URL is attached by the backend
- redirect page works
- webhook is received and accepted
- final pledge is created only after webhook confirmation
- campaign totals increase only after finalization

## If Something Fails

### `payment_attempt` exists but has no checkout URL

Check:

- Functions deployed correctly
- `PAYMONGO_SECRET_KEY` is present
- `PAYMONGO_SUCCESS_URL` is set
- `PAYMONGO_CANCEL_URL` is set
- function logs for the checkout-creation trigger

### Redirect works but payment never becomes `paid`

Check:

- PayMongo webhook URL is correct
- `PAYMONGO_WEBHOOK_SECRET` matches PayMongo
- subscribed event is `checkout_session.payment.paid`
- webhook function logs

### App returns to status page but stays pending

That usually means:

- redirect worked
- webhook finalization did not

This is expected behavior for the current architecture because the client does not self-finalize success.

## Important Constraints

- keep this scoped to crowdfunding only
- do not expand the same payment flow into rent/equipment
- do not reintroduce client-side pledge finalization
- keep `qrph` as the initial active payment method unless PayMongo capabilities change intentionally

## Security Notes

- the previously pasted `sk_test_...` key should be rotated if it has not been rotated yet
- do not commit secrets into the repo
- do not move PayMongo secret-key logic into the Flutter client

## Files To Review Before Deploying

- `firebase.json`
- `firestore.rules`
- `functions/index.js`
- `functions/package.json`
- `lib/main.dart`
- `lib/screens/crowdfunding_payment_return_screen.dart`
- `web/paymongo-return.html`

# Teammate Testing Guide

Last updated: 2026-07-05
Branch: `feature/payments-api-sandbox`

## Purpose

This guide lets a groupmate test the crowdfunding payment flow on their own Windows computer without needing Firebase deploy access.

This setup is for:

- local Firestore emulator
- local Firebase Functions emulator
- Flutter web app running locally
- local seeded crowdfunding campaigns for pledge testing

## What This Local Setup Can Test

This teammate setup can verify:

- app loads correctly
- sign in works
- crowdfunding campaigns appear locally
- pledge flow opens PayMongo checkout
- duplicate active checkout attempts are blocked
- cancelled checkout returns are marked terminal instead of staying resumable

## What This Local Setup Cannot Fully Test

This setup does not fully verify the final paid webhook flow unless you also expose your local webhook publicly.

That means these items still need a public endpoint or deployed backend:

- PayMongo webhook delivery to `paymongoCrowdfundingWebhook`
- automatic transition from `pending_checkout` to `paid`
- final `pledges` creation after confirmed payment
- campaign `pledgedAmount` and `backersCount` increasing after webhook confirmation

## Important Auth Note

By default, this local setup uses:

- local Firestore emulator
- local Functions emulator
- real Firebase Auth project

So sign-in still uses the actual Firebase Auth project configured in the repo.

Use one of these:

- a real shared test account provided by the project owner
- your own disposable test account created in the app

If you create a new account during this test, it is created in the real Firebase Auth project, not a local auth emulator.

## One-Time Setup

From the repo root:

1. Pull the latest branch.
2. Run:

```powershell
flutter pub get
```

3. Install Functions dependencies:

```powershell
cd functions
npm install
cd ..
```

4. Make sure Firebase CLI is installed and logged in:

```powershell
firebase --version
firebase login
```

5. Create `functions/.env` from the example:

```powershell
Copy-Item functions\.env.example functions\.env
```

6. Open `functions/.env` and set your sandbox key values.

Recommended local values:

```env
PAYMONGO_SECRET_KEY=sk_test_REPLACE_ME
PAYMONGO_SUCCESS_URL=http://127.0.0.1:7357/paymongo-return.html
PAYMONGO_CANCEL_URL=http://127.0.0.1:7357/paymongo-return.html
PAYMONGO_PAYMENT_METHOD_TYPES=qrph
PAYMONGO_PASS_ON_FEES=false
PAYMONGO_WEBHOOK_SECRET=whsec_REPLACE_ME
```

Notes:

- `PAYMONGO_SECRET_KEY` should be a PayMongo sandbox secret key
- `PAYMONGO_WEBHOOK_SECRET` is only needed if you are also testing a real public webhook
- keep both return URLs on the local `paymongo-return.html` page for local web testing

## Fastest Startup

From the repo root, run:

```powershell
.\start_teammate_test.ps1
```

This script will:

- open Firebase emulators in a new PowerShell window
- wait for Firestore and Functions emulators
- seed local crowdfunding campaigns into Firestore emulator
- open Flutter web in a second PowerShell window

Expected local app URL:

- `http://127.0.0.1:7357`

## Manual Startup

If you prefer not to use the helper script:

1. Start the emulators:

```powershell
firebase emulators:start --only firestore,functions
```

2. In a new terminal, seed the local campaigns:

```powershell
cd functions
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:GCLOUD_PROJECT='bukidbayan-capstoners'
npm run seed:local:crowdfunding
cd ..
```

3. In another terminal, launch Flutter web with emulator flags:

```powershell
flutter run -d chrome --web-port 7357 --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

## Test Flow

1. Open the local app.
2. Sign in using a valid test account.
3. Open the crowdfunding screen.
4. Pick one of the seeded campaigns.
5. Create a pledge and continue to checkout.
6. Try going back and clicking pledge again.
7. Confirm the app resumes or blocks the existing active checkout instead of creating unlimited new ones.
8. Try cancelling the checkout and returning to the app.
9. Confirm the attempt is shown as cancelled instead of staying resumable.

## Troubleshooting

### No campaigns appear

Run the seed command again:

```powershell
cd functions
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:GCLOUD_PROJECT='bukidbayan-capstoners'
npm run seed:local:crowdfunding
cd ..
```

### `functions/.env` is missing

Create it from the example:

```powershell
Copy-Item functions\.env.example functions\.env
```

### Firebase emulators do not start

Check:

- `firebase login` has already been done
- Firebase CLI is installed
- ports `8080`, `5001`, and `4000` are not already taken

### Checkout opens but never becomes paid

That is expected for purely local testing unless you also expose your webhook publicly.

Without a public webhook:

- checkout can open
- cancel handling can be tested
- duplicate protection can be tested
- final payment confirmation cannot complete end-to-end

## Related Files

- [start_teammate_test.ps1](<C:\Users\Iccoh\Documents\school\Coding\bukidbayan_app\start_teammate_test.ps1>)
- [functions/.env.example](<C:\Users\Iccoh\Documents\school\Coding\bukidbayan_app\functions\.env.example>)
- [functions/scripts/seed_local_crowdfunding_campaigns.js](<C:\Users\Iccoh\Documents\school\Coding\bukidbayan_app\functions\scripts\seed_local_crowdfunding_campaigns.js>)
- [docs/FIREBASE_PAYMONGO_SETUP.md](<C:\Users\Iccoh\Documents\school\Coding\bukidbayan_app\docs\FIREBASE_PAYMONGO_SETUP.md>)

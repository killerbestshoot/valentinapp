# VOUPVAPCASH Project Resume

## Overview

This repository contains a Flutter application named `mon_premye_app`, branded as `VOUPVAPCASH`. The app is a Firebase-backed transaction, wallet, payout, commission, and enterprise management system. Most user-facing copy is in Haitian Creole, with some English and French labels.

The active application entry point is `lib/main.dart`. It initializes Firebase and opens `lib/pages/login_page.dart`. After login, the active login page navigates to `lib/pages/home_page.dart`.

The project also contains newer or alternate architecture folders under `lib/app`, `lib/core`, and `lib/features`, plus many duplicated top-level pages. Some of those modules are not currently used by `lib/main.dart`, but they show planned or partially integrated app structure.

## Technology Stack

- Flutter SDK with Dart `>=3.4.0 <4.0.0`
- Firebase Core
- Firebase Auth
- Cloud Firestore
- Cloud Functions
- Go Router
- PDF and printing support
- QR code support
- CSV export support
- Node.js backend utilities and Firebase functions

Important packages from `pubspec.yaml`:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `cloud_functions`
- `go_router`
- `http`
- `intl`
- `pdf`
- `printing`
- `open_file`
- `qr_flutter`
- `crypto`
- `csv`

## Active App Flow

### Startup

File: `lib/main.dart`

The app:

1. Calls `WidgetsFlutterBinding.ensureInitialized()`.
2. Initializes Firebase using `DefaultFirebaseOptions.currentPlatform`.
3. Runs `MyApp`.
4. Displays a `MaterialApp` titled `VOUPVAPCASH`.
5. Uses `LoginPage` as the home screen.

### Login

File: `lib/pages/login_page.dart`

The active login page uses Firebase email/password authentication:

- Validates that the email contains `@`.
- Requires a password length of at least 6 characters.
- Calls `FirebaseAuth.instance.signInWithEmailAndPassword`.
- On success, navigates to `HomePage`.
- Shows localized Firebase Auth error messages.

### Home Dashboard

File: `lib/pages/home_page.dart`

The current home page is a simple dashboard that:

- Confirms the app is connected to Firebase.
- Opens `CreateTransactionPage`.
- Streams the latest 10 documents from the `transactions` collection.
- Opens a receipt page when a transaction row is tapped.

## Firebase Configuration

Firebase config lives in:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `firebase.json`

The configured Firebase project is:

- Project ID: `voupvapcash`
- Web auth domain: `voupvapcash.firebaseapp.com`

`firebase.json` configures:

- Flutter web hosting from `build/web`
- Firestore rules from `firestore.rules`
- Firestore indexes from `firestore.indexes.json`
- A Firebase Functions codebase named `commission`, sourced from the `commission` folder

## Authentication and Roles

The codebase uses Firebase Auth for identity and Firestore documents for role/profile data.

Main role values found in code:

- `owner`
- `administrator`
- `admin`
- `agent`
- `client`

Important auth/profile files:

- `lib/pages/login_page.dart`
- `lib/auth_gate.dart`
- `lib/services/auth_guard_service.dart`
- `lib/services/auth_service.dart`
- `lib/core/services/auth_service.dart`
- `lib/features/auth/...`

`lib/auth_gate.dart` is an alternate role-based gate. It reads `users/{uid}` from Firestore and routes:

- `owner` to `OwnerDashboard`
- `administrator` to `AdminDashboard`
- `agent` to `AgentDashboard`

However, this gate is not currently used by `lib/main.dart`.

## Main Firestore Collections

Collections referenced across the app include:

- `users`
- `enterprise_users`
- `enterprises`
- `transactions`
- `balances`
- `wallets`
- `wallet_logs`
- `wallet_ledger`
- `wallet_topup_requests`
- `payout_requests`
- `payout_logs`
- `commission_logs`
- `ledger`
- `notifications`
- `services`
- `service_access`
- `agents`

## Transaction System

Main files:

- `lib/pages/create_transaction_page.dart`
- `lib/pages/new_transaction_page.dart`
- `lib/pages/quick_create_transaction_page.dart`
- `lib/services/transaction_service.dart`
- `lib/services/firestore_repo.dart`
- `lib/features/transactions/...`

The simplest active transaction form writes to `transactions` with fields like:

- `serviceName`
- `customerName`
- `customerPhone`
- `paymentAmount`
- `paymentCurrency`
- `status`
- `createdAt`

`FirestoreRepo.createTransaction` is stricter and intended for agent-created enterprise transactions. It requires the staff role to be `agent`, attaches enterprise and staff metadata, and writes richer transaction data:

- `txId`
- `enterpriseId`
- `enterpriseName`
- `staffUid`
- `staffName`
- `serviceName`
- `category`
- `customerPhone`
- `beneficiaryPhone`
- `beneficiaryName`
- `paymentAmount`
- `paymentCurrency`
- `transferAmount`
- `transferCurrency`
- `status`
- `paymentStatus`
- `commissionAgent`
- `commissionOwner`
- `commissionApplied`

## Wallet System

Main files:

- `lib/services/wallet_service.dart`
- `lib/services/wallet_engine.dart`
- `lib/services/wallet_topup_request_service.dart`
- `lib/pages/wallet_dashboard_page.dart`
- `lib/pages/wallet_page.dart`
- `lib/pages/wallet_history_page.dart`
- `lib/pages/wallet_topup_page.dart`
- `lib/pages/wallet_topup_request_page.dart`
- `lib/pages/wallet_topup_approval_page.dart`
- `lib/pages/wallet_transfer_page.dart`
- `lib/pages/wallet_transfer_history_page.dart`

Wallet features include:

- Creating or repairing a wallet document for the current user.
- Reading wallet balance and reserved balance.
- Owner/admin wallet topups.
- Wallet topup requests and approval flow.
- Withdrawal request submission.
- Withdrawal approval or rejection.
- Wallet history through `wallet_logs`.
- Wallet ledger entries through `wallet_ledger`.

Wallets are stored in the `wallets` collection with fields like:

- `uid`
- `email`
- `enterpriseId`
- `role`
- `balance`
- `reserved`
- `createdAt`
- `updatedAt`

## Payout System

Main files:

- `lib/pages/payout_center_page.dart`
- `lib/pages/payout_dashboard_page.dart`
- `lib/pages/payout_admin_hub_page.dart`
- `lib/pages/payout_hub_page.dart`
- `lib/pages/payout_approval_page.dart`
- `lib/pages/payout_requests_page.dart`
- `lib/pages/payout_history_page.dart`
- `lib/pages/agent_payout_page.dart`
- `lib/widgets/payout_button.dart`

Payout and withdrawal data appears to use:

- `payout_requests`
- `payout_logs`
- wallet reservation fields

The wallet service supports withdrawal request creation and owner/admin approval/rejection logic.

## Commission System

Main files:

- `lib/services/commission_service.dart`
- `lib/services/commission_auto_runner.dart`
- `lib/pages/commission_center_page.dart`
- `lib/pages/commission_automation_page.dart`
- `lib/pages/commission_history_page.dart`
- `lib/pages/commission_scheduler_page.dart`
- `lib/pages/commission_test_page.dart`
- `commission/index.js`
- `functions/index.js`

There are two commission implementations:

1. Flutter-side service in `lib/services/commission_service.dart`
   - Applies commission to a transaction.
   - Updates `balances/{enterpriseId}_{staffUid}`.
   - Updates `balances/{enterpriseId}_OWNER`.
   - Writes a `ledger` entry.
   - Marks the transaction as `commissionApplied`.

2. Firebase Functions in `commission/index.js`
   - Auto-applies commission when a delivered transaction is written.
   - Runs weekly on Sunday at 23:59 in `America/Mexico_City`.
   - Provides callable function `runCommissionNow`.
   - Writes `commission_logs`.
   - Creates commission notifications.

The older `functions/index.js` also includes a scheduled commission processor, but `firebase.json` currently points to the `commission` codebase.

## Receipt and Reporting

Main files:

- `lib/services/receipt_pdf_service.dart`
- `lib/pages/receipt_page.dart`
- `lib/pages/receipt_pdf_page.dart`
- `lib/pages/receipt_preview_page.dart`
- `lib/pages/receipt_success_page.dart`
- `lib/pages/receipt_history_page.dart`
- `lib/pages/receipt_validation_page.dart`
- `lib/pages/reprint_audit_page.dart`
- `lib/pages/reports_page.dart`
- `lib/pages/reports_export_page.dart`
- `lib/pages/closing_reports_page.dart`
- `lib/pages/daily_closing_page.dart`
- `lib/pages/weekly_monthly_closing_reports_page.dart`

`ReceiptPdfService` can:

- Read a transaction document from Firestore.
- Build a PDF receipt.
- Save it locally on non-web platforms.
- Print or share it through the `printing` package.

## Enterprise, Admin, and Access Control

Main files:

- `lib/pages/enterprise_control_page.dart`
- `lib/pages/enterprise_control_center_page.dart`
- `lib/pages/enterprise_detail_page.dart`
- `lib/pages/enterprise_settings_page.dart`
- `lib/pages/service_access_control_page.dart`
- `lib/pages/user_access_control_page.dart`
- `lib/pages/user_role_manager_page.dart`
- `lib/pages/admin_dashboard_page.dart`
- `lib/pages/owner_dashboard_page.dart`
- `lib/pages/owner_admin_reports_page.dart`
- `lib/pages/owner_admin_wallet_dashboard_page.dart`
- `lib/pages/run_platform_setup_page.dart`

The app models enterprise membership with `enterprise_users` documents containing:

- `uid`
- `email`
- `displayName`
- `role`
- `enterpriseId`
- `enterpriseName`
- `isActive`

There are setup/repair pages and scripts that create or patch users, enterprises, services, balances, and access-control documents.

## Service Catalog

Main files:

- `lib/core/catalogs/service_catalog.dart`
- `lib/pages/service_catalog_page.dart`
- `lib/pages/service_management_page.dart`
- `lib/features/services/...`

Services referenced include:

- MonCash
- NatCash
- Minit Haiti
- Papadap/Pappadap
- Cashwallet
- Western Union
- CAM transfer
- Topup

The setup page seeds service documents such as:

- `moncash_ht`
- `natcash_ht`
- `minutes_topup`

## OTP Server

Folder: `server`

This is a separate Express server for OTP email flows.

Important files:

- `server/src/index.js`
- `server/src/routes/otp.routes.js`
- `server/src/mailer.js`
- `server/src/otp_store.js`
- `server/package.json`

Endpoints:

- `GET /`
- `POST /api/otp/send`
- `POST /api/otp/verify`

The server listens on port `4700`. It uses `nodemailer` and environment variables from `server/.env`.

## Firebase Functions

There are two function folders:

- `commission`
- `functions`

The active Firebase configuration uses the `commission` folder as a named codebase.

`commission/index.js` provides:

- Firestore trigger: `autoApplyCommissionOnTransaction`
- Scheduled function: `runWeeklyCommissionV2`
- Callable function: `runCommissionNow`

`functions/scripts/create_users.js` is a utility script that can create seed Firebase Auth users and Firestore profile documents, but it depends on a service account file and modifies Firebase directly.

## Firestore Rules

File: `firestore.rules`

Current rule summary:

- Signed-in users can read `transactions` and create/update them.
- Only owners can delete transactions.
- Signed-in users can read `balances`.
- No client writes to `balances`.
- Only owner/admin can read `payout_logs` and `commission_logs`.
- Signed-in users can read `users`.
- Only owners can write `users`.
- Everything else is denied by default.

Important caveat: many app features write to collections that are not explicitly allowed in these rules, such as `wallets`, `wallet_logs`, `wallet_topup_requests`, `payout_requests`, `service_access`, and others. Those writes may fail from the client unless rules are expanded or writes are moved into trusted Cloud Functions.

## Project Structure

High-level folders:

- `lib`: Flutter app source.
- `lib/pages`: many screen widgets, including the currently active login/home flow.
- `lib/services`: app service layer for auth, Firestore, wallets, commissions, receipts, transactions, enterprise status, etc.
- `lib/widgets`: reusable dashboard and owner widgets.
- `lib/app`: alternate app shell using Go Router.
- `lib/core`: newer shared architecture for config, models, permissions, services, routing, session, widgets, and utilities.
- `lib/features`: feature-first modules for auth, admin, agent, client/customer, dashboard, services, reports, transactions, settings, owner, and gate flows.
- `commission`: Firebase Functions codebase for commission processing.
- `functions`: older/additional Firebase Functions and scripts.
- `server`: local Express OTP email server.
- `scripts`: Node utility scripts for fixing owner data, ledger, and profiles.
- `tool`: Dart/PowerShell utility tools.
- `web`, `android`, `ios`, `macos`, `windows`, `linux`: Flutter platform folders.
- `__project_archive__`: archived backups and older duplicate code.

## Development Commands

Common Flutter commands:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter build web
```

Firebase hosting deploy usually depends on building web first:

```sh
flutter build web
firebase deploy --only hosting
```

Commission functions:

```sh
cd commission
npm install
npm run serve
npm run deploy
```

OTP server:

```sh
cd server
npm install
npm run dev
```

## Important Caveats

- The active `lib/main.dart` uses the simple `MaterialApp` and `LoginPage`, not the newer `lib/app/app.dart` Go Router app.
- There are many duplicated pages at both `lib/` root and `lib/pages/`.
- There are archived duplicates under `__project_archive__`; these should not be treated as active code.
- Some Android/iOS/macOS generated and dependency folders are present in the repo.
- There are multiple service implementations with overlapping responsibilities.
- The Firestore rules are stricter than several client-side features expect.
- Some scripts reference Firebase service account files and can mutate live Firebase Auth/Firestore data.
- The repository is not currently initialized as a Git repository in this workspace.

## Current Product Summary

VOUPVAPCASH is intended to be an operational money-service platform for agents, administrators, and owners. Its core capabilities are:

- Login with Firebase Auth.
- Manage users and roles through Firestore profiles.
- Create and track financial/service transactions.
- Manage enterprise users and services.
- Maintain wallets, balances, topups, withdrawals, and payout flows.
- Apply and audit commissions for agents and owners.
- Generate receipts and reports.
- Run Firebase Functions for automated commission processing.
- Use a separate Express service for OTP email verification.

The project has strong feature coverage but needs consolidation. The main cleanup opportunity is to choose one app architecture, either the current `lib/pages` flow or the newer `lib/app`/`lib/features` flow, then remove or archive inactive duplicates and align Firestore rules with the intended write paths.



-- ####################################

# VOUPVAPCASH

VOUPVAPCASH is a mobile financial operations app for agents, administrators, and owners. The project supports role-based workflows, cash transfer services, transaction management, commission auditing, and enterprise control via Firebase.

## App Goal

The app is designed to:
- let agents authenticate and access service dashboards
- support MonCash, NatCash, Western Union, and CAM Transf service flows
- track transactions per agent and enterprise
- provide dashboards for owners, admins, and agents
- use Firebase Authentication and Firestore for persistence

## Architecture

The project is organized with a feature-driven S.O.L.I.D approach:

- `lib/app/` - application entry, router, and shared app configuration
- `lib/core/` - common persistence helpers and shared infrastructure
- `lib/features/auth/` - authentication models, repository, use cases, and presentation
- `lib/features/dashboard/` - dashboard data modeling, repository, use case, and UI
- `lib/features/services/` - service-related pages and flows
- `lib/features/transactions/` - transaction creation and listing screens

## Implemented layers

- `Model` - data classes such as `AuthUser`, `DashboardData`, and `ServiceOffer`
- `Repository` - abstractions for auth and dashboard persistence
- `Persistence` - `FirebasePersistence` for Firebase instance access
- `Use Case` - business logic encapsulated in `LoginUseCase` and `GetDashboardDataUseCase`
- `Presentation` - feature pages and widgets grouped by feature

## Running the app

1. Install Flutter and configure your environment.
2. Run `flutter pub get`.
3. Use `flutter run` to start the application.

## Notes

- The new feature structure uses `go_router` for navigation.
- Firebase emulator support is included via the `USE_FIREBASE_EMULATORS` environment flag.
- Existing legacy pages remain in the project, but the app entry now routes through the feature-based architecture.

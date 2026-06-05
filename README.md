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
- `lib/features/auth/` - authentication domain model, repository contract, Firebase/mock implementations, use cases, and login/register UI
- `lib/features/admin/` - administrator screens and workflows
- `lib/features/owner/` - owner screens and workflows
- `lib/features/dashboard/` - agent/client dashboard data modeling, repository, use case, and UI
- `lib/features/services/` - service-related pages and flows
- `lib/features/transactions/` - transaction creation and listing screens

The active application entrypoint is `lib/main.dart`, which loads `lib/app/app.dart` and `lib/app/app_router.dart`. New code should be added under `lib/features/<feature>/` and consumed through repository interfaces/use cases rather than importing Firebase directly from widgets.

Some older duplicate screens still exist at the top of `lib/` and in `lib/pages/`. Treat those files as legacy migration candidates. Do not add new behavior there unless a feature migration explicitly requires it.

## Implemented layers

- `Model` - data classes such as `AuthUser`, `DashboardData`, and `ServiceOffer`
- `Repository` - abstractions for auth, dashboard, and transactions
- `Data source implementation` - Firebase repositories for production and mock repositories for local/dev tests
- `Persistence` - `FirebasePersistence` for Firebase instance access
- `Use Case` - business logic encapsulated in classes such as `LoginUseCase`, `GetDashboardDataUseCase`, and transaction use cases
- `Presentation` - feature pages and widgets grouped by feature

## Role Routing

Authentication is role-aware through `AuthUser.role`.

- owners route to `/owner`
- admins route to `/admin`
- agents and clients route to `/dashboard`

For local development without Firebase, run with:

```sh
flutter run -d chrome --dart-define=MOCK_FIREBASE=true
```

Mock role shortcuts:

- `owner@...` logs in as owner
- `admin@...` logs in as admin
- `client@...` logs in as client
- any other email logs in as agent

## Testing

Run:

```sh
flutter test
flutter analyze
flutter build web --dart-define=MOCK_FIREBASE=true
```

The tests cover the auth repository seam, role routing, UUID generation, and the existing smoke test.

## Running the app

1. Install Flutter and configure your environment.
2. Run `flutter pub get`.
3. Use `flutter run` to start the application.

## Notes

- The new feature structure uses `go_router` for navigation.
- Firebase emulator support is included via the `USE_FIREBASE_EMULATORS` environment flag.
- Existing legacy pages remain in the project, but the app entry now routes through the feature-based architecture.

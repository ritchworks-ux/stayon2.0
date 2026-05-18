# StayOn

Never miss what matters. Track expiry, renewal, and due dates for warranties, subscriptions, IDs, insurance, medicines, groceries, bills, and documents.

- **Platforms:** iOS 16+, Android 10+ (web target enabled for dev preview only)
- **Stack:** Flutter 3.41 · Riverpod · Supabase · Drift · Nunito Sans
- **Bundle ID:** `app.getstayon.mobile`
- **Spec:** [docs/superpowers/specs/2026-05-18-stayon-mvp-design.md](docs/superpowers/specs/2026-05-18-stayon-mvp-design.md)
- **Plan:** [docs/superpowers/plans/2026-05-18-stayon-mvp.md](docs/superpowers/plans/2026-05-18-stayon-mvp.md)

## Run locally

```bash
flutter pub get
flutter run                  # picks an available device
flutter run -d chrome        # web preview
```

## Quality gates

```bash
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

CI runs all three on every push and pull request — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

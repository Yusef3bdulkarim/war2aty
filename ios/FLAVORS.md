# iOS flavors — one-time Xcode wiring (do on a Mac)

Android flavors (`dev`/`prod`) are fully configured in Gradle. iOS needs a
one-time setup in Xcode that **cannot be scripted on Windows** because it
creates build configurations and schemes inside `Runner.xcodeproj`.

The flavor-specific overrides already exist as xcconfig files:

- `ios/Flutter/flavors/Dev.xcconfig`  → bundle `com.war2aty.app.dev`, target `lib/main_dev.dart`
- `ios/Flutter/flavors/Prod.xcconfig` → bundle `com.war2aty.app`, target `lib/main_prod.dart`

## Steps (Xcode, once)

1. Open `ios/Runner.xcworkspace`.
2. **Project → Runner → Info → Configurations.** For each existing base
   configuration (`Debug`, `Release`, `Profile`) duplicate it into a `-dev`
   and a `-prod` variant, e.g. `Debug-dev`, `Release-dev`, `Profile-dev`,
   `Debug-prod`, `Release-prod`, `Profile-prod`.
3. For each `*-dev` configuration set its xcconfig to include the base file
   **and** `Flutter/flavors/Dev.xcconfig`; same for `*-prod` with `Prod.xcconfig`.
   (In the generated per-config xcconfig, add `#include "flavors/Dev.xcconfig"`
   after the existing `#include` line.)
4. In `ios/Runner/Info.plist` change `CFBundleDisplayName` to
   `$(APP_DISPLAY_NAME)` so each flavor shows its own name.
5. **Product → Scheme → Manage Schemes.** Create a `dev` scheme and a `prod`
   scheme; point each build action at the matching `*-<flavor>` configurations.

After this, `flutter run --flavor dev -t lib/main_dev.dart` works on iOS the
same way it already does on Android.

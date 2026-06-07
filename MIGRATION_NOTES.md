# Migration Notes

## predict_screen.dart → manual_predict_screen.dart

The file `lib/screens/predict_screen.dart` has been **renamed** to
`lib/screens/manual_predict_screen.dart` and the class renamed from
`PredictScreen` to `ManualPredictScreen`.

Update every reference in your router / nav:

```dart
// BEFORE
import '../screens/predict_screen.dart';
// …
Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictScreen()));

// AFTER
import '../screens/manual_predict_screen.dart';
// …
Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualPredictScreen()));
```

If you use named routes in `main.dart`, change the builder accordingly.
The old file `predict_screen.dart` can be deleted once you confirm the
new import compiles.

---

## Dashboard widgets extraction

Six widgets extracted from `lib/screens/dashboard_screen.dart` into
`lib/widgets/dashboard/`:

| Widget file | Extracted class |
|---|---|
| `command_header.dart` | `CommandHeader` |
| `hero_section.dart` | `HeroSection` |
| `quick_access_grid.dart` | `QuickAccessGrid` |
| `river_pulse_card.dart` | `RiverPulseCard` |
| `alert_activity_log.dart` | `AlertActivityLog`, `AlertEvent` |
| `section_header.dart` | `SectionHeader` |

Barrel export: `lib/widgets/dashboard/dashboard_widgets.dart`

In `dashboard_screen.dart`, replace the private `_CommandHeader`,
`_HeroSection`, `_QuickAccessGrid`, `_RiverPulseCard`, `_AlertEvent` +
log code, and `_SectionHeader` with the public exported versions and
add:

```dart
import '../widgets/dashboard/dashboard_widgets.dart';
```

Also rename `_AlertEvent` usages to `AlertEvent` (now in
`alert_activity_log.dart`).

---

## firebase_options.dart

Already in `.gitignore`. The file currently committed to the repo
should be removed from git history:

```bash
git rm --cached lib/firebase_options.dart
git commit -m 'chore: stop tracking firebase_options.dart'
```

Then regenerate locally with `flutterfire configure` and distribute via
your CI secret store using `--dart-define` at build time.

# myLeave

A small phone app (Flutter) that keeps count of annual leave when the leave
year follows your **contract**, not the calendar year.

## The rules it follows

- A contract starts on a date you choose (for example 1 March) and runs for
  any number of years and months, e.g. 1 year, 2 years, or 2 years 3 months.
- Each full contract year is one leave year (1 Mar – end of Feb) with the full
  entitlement (default **25 days**).
- Left-over months at the end form a short final period with **prorated**
  leave: 25 x 3/12 = 6.25, and a fraction under half a day is dropped while
  half a day or more counts as a full day, so 3 months gives 6 days.
- Inside one contract, unused days of a period carry into the next period, up
  to the carry-forward limit (default **10 days**).
- Carried-forward days are used first, expire at the end of the period they
  were carried into, and cannot be carried again.
- Nothing carries out of the last period of a contract. If you are allowed to
  bring days into a new contract, enter them as "Days brought forward".
- A leave is counted in the period it starts in, and must fit inside one
  period. Leave recorded for a future date shows as "Upcoming" and is already
  deducted from the days available. There is no approval status.
- The app suggests the number of Monday–Friday days in the dates you pick.
  Lower it yourself for public holidays or half days (steps of 0.5).

## Screens

- **Overview** — days available, how long until the period ends and what would
  be lost, the carried-forward / current-year breakdown, and recent leave.
- **Calendar** — a month view with a dot on every leave day.
- **History** — every leave recorded in a contract year.
- **Contract** — the contract, a year-by-year summary, backup and app updates.

## Data

Everything is stored on the phone only. Use **Contract → Copy backup** to copy
all records as text, and **Restore** to paste them back on a new phone.

## Updates happen inside the app

You install the APK by hand only once. After that:

1. Code is pushed to `main`.
2. GitHub Actions (`.github/workflows/release.yml`) runs the tests, builds a
   signed APK with version `1.0.<run number>` and publishes it as a GitHub
   release.
3. When the app is opened it asks GitHub for the latest release. If it is newer
   it shows "Version … is available" with an **Update** button, downloads the
   APK itself and opens the Android installer. Leave records are kept.

Android shows its own "Install" confirmation, and the first time asks you to
allow this app to install updates. That prompt cannot be skipped by any app
outside the Play Store.

### Signing key (one-time setup)

Android refuses an update that is signed with a different key from the
installed app, so every release must use the same key.

- The key lives in `android/upload-keystore.jks` with its password in
  `android/key.properties`. Both are ignored by git. **Keep a copy of both
  somewhere safe** — without them no future build can update an installed app.
- GitHub Actions needs the same key as two repository secrets
  (Settings → Secrets and variables → Actions):
  - `KEYSTORE_BASE64` — the keystore file, base64-encoded
  - `KEYSTORE_PASSWORD` — the `storePassword` value from `key.properties`

Until both secrets exist the workflow still tests and builds, but publishes no
release.

## Develop

```
flutter pub get
flutter test
flutter run
```

Build an installable Android app:

```
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Code map

| File | What it does |
| --- | --- |
| `lib/leave_calculator.dart` | Contract periods, proration, carry-forward, validation (no UI) |
| `lib/models.dart` | `Contract` and `Leave` |
| `lib/store.dart` | Saves and loads the data on the device |
| `lib/home_page.dart` | App shell and the Overview tab |
| `lib/records_tabs.dart` | Calendar and History tabs |
| `lib/theme.dart` | Colours and shared widgets of the myLeave design |
| `lib/leave_form_page.dart` | Record / edit a leave |
| `lib/contracts_page.dart` | Contract tab and the contract form |
| `lib/updater.dart` | Finds, downloads and installs a newer release |
| `lib/update_widgets.dart` | The "Update" banner and settings section |
| `android/.../MainActivity.kt` | Hands the downloaded APK to the Android installer |

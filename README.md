# Annual Leave

A small phone app (Flutter) that keeps count of annual leave when the leave
year follows your **contract**, not the calendar year.

## The rules it follows

- A contract starts on a date you choose (for example 1 March) and runs for
  1, 2 or 3 years. Each contract year is one leave year: 1 Mar – end of Feb.
- Every leave year gives the contract's entitlement (default **25 days**).
- Inside a multi-year contract, unused days carry into the next year, up to
  the carry-over limit (default **10 days**). Anything above the limit is lost.
- Nothing carries out of the last year of a contract automatically. If you are
  allowed to bring days into a new contract, enter them as "Days brought
  forward" on that contract.
- A leave is counted in the leave year it starts in, and must fit inside one
  leave year. Leave booked for a future date shows as "Planned" and is already
  deducted from the days left.
- The app suggests the number of Monday–Friday days in the dates you pick.
  Lower it yourself for public holidays or half days (steps of 0.5).

The home screen shows the days left, how long until the leave year ends, and
how many days you will lose if you do not use them.

## Data

Everything is stored on the phone only. Use **Settings → Copy backup** to copy
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
| `lib/leave_calculator.dart` | Leave years, carry-over, validation (no UI) |
| `lib/models.dart` | `Contract` and `Leave` |
| `lib/store.dart` | Saves and loads the data on the device |
| `lib/home_page.dart` | Days-left screen |
| `lib/leave_form_page.dart` | Add / edit a leave |
| `lib/contracts_page.dart` | Settings: contracts, backup, app version |
| `lib/updater.dart` | Finds, downloads and installs a newer release |
| `lib/update_widgets.dart` | The "Update" banner and settings section |
| `android/.../MainActivity.kt` | Hands the downloaded APK to the Android installer |

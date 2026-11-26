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

Everything is stored on the phone only. Use **Contracts → Copy backup** to copy
all records as text, and **Restore** to paste them back on a new phone.

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
| `lib/contracts_page.dart` | Contracts and backup |

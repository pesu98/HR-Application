import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leave_tracker/home_page.dart';
import 'package:leave_tracker/leave_calculator.dart';
import 'package:leave_tracker/main.dart';
import 'package:leave_tracker/models.dart';
import 'package:leave_tracker/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime d(String iso) => parseIsoDate(iso)!;

Map<String, Object> saved({
  required List<Map<String, Object?>> contracts,
  List<Map<String, Object?>> leaves = const [],
}) => {
  LeaveStore.storageKey: jsonEncode({'version': 1, 'contracts': contracts, 'leaves': leaves}),
};

const twoYearContract = {
  'id': 'c1',
  'start': '2025-03-01',
  'years': 2,
  'daysPerYear': 25,
  'carryMax': 10,
  'broughtForward': 0,
};

Future<LeaveStore> loadStore(Map<String, Object> initial, {String today = '2026-11-26'}) async {
  SharedPreferences.setMockInitialValues(initial);
  final store = LeaveStore(clock: () => d(today));
  await store.load();
  return store;
}

/// Lays the app out on a small phone screen (360 x 800).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Scrolls [finder] fully onto the screen, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 100, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the screen back to its top.
Future<void> scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 3000));
  await tester.pumpAndSettle();
}

String daysLeft(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('days-left'))).data!;

void main() {
  testWidgets('first launch sets up a 2 years 3 months contract', (tester) async {
    final store = await loadStore({});
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    expect(find.text('Set up your contract'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add contract'));
    await tester.pumpAndSettle();

    // 1 March is suggested as the start.
    expect(find.text('Sun, 1 Mar 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('contract-years')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 years').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract-months')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 months').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('length-summary'))).data,
      'Ends 31 May 2028. The last 3 months get 6 days (prorated from 25).',
    );

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Add contract'));

    expect(store.contracts.single.years, 2);
    expect(store.contracts.single.months, 3);
    expect(find.text('1 Mar 2026 – 28 Feb 2027'), findsOneWidget);
    expect(find.text('YEAR 1 / 3'), findsOneWidget);
    expect(daysLeft(tester), '25');

    // The prorated last period: 6 days plus 10 carried in.
    await tapVisible(tester, find.text('Last 3 months'));
    await scrollToTop(tester);
    expect(find.text('1 Mar 2028 – 31 May 2028'), findsOneWidget);
    expect(find.text('PERIOD 3 / 3'), findsOneWidget);
    expect(daysLeft(tester), '16');
    expect(find.text('of 16 days entitlement'), findsOneWidget);
  });

  testWidgets('year 2 shows 25 plus the 10 carried forward', (tester) async {
    final store = await loadStore(
      saved(
        contracts: [twoYearContract],
        leaves: [
          {'id': 'a', 'start': '2025-06-02', 'end': '2025-06-13', 'days': 10, 'note': ''},
          {'id': 'b', 'start': '2026-05-04', 'end': '2026-05-08', 'days': 5, 'note': 'Raya'},
          {'id': 'c', 'start': '2026-12-21', 'end': '2026-12-24', 'days': 4, 'note': ''},
        ],
      ),
    );
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    expect(find.text('1 Mar 2026 – 28 Feb 2027'), findsOneWidget);
    expect(daysLeft(tester), '26');
    expect(find.text('of 35 days entitlement'), findsOneWidget);
    expect(find.textContaining('last period of your contract'), findsOneWidget);

    // Carried-forward days are used first: 9 used, so 1 of the 10 is left.
    await tester.scrollUntilVisible(find.text('Carried-forward leave'), 100);
    expect(find.text('1 / 10', findRichText: true), findsOneWidget);
    expect(find.text('25 / 25', findRichText: true), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Raya'), 100);
    expect(find.text('Raya'), findsOneWidget);

    // Go back to year 1: 15 unused, 10 carried forward, 5 expired.
    await scrollToTop(tester);
    await tapVisible(tester, find.text('Year 1'));
    await scrollToTop(tester);
    expect(find.text('1 Mar 2025 – 28 Feb 2026'), findsOneWidget);
    expect(daysLeft(tester), '15');
    expect(find.text('10 days carried forward to the next period.'), findsOneWidget);
    expect(find.text('5 days expired unused on 28 Feb 2026.'), findsOneWidget);
  });

  testWidgets('recording a leave deducts weekdays and saves it', (tester) async {
    final store = await loadStore(
      saved(
        contracts: [
          {...twoYearContract, 'start': '2026-03-01', 'years': 1},
        ],
      ),
    );
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    await tapVisible(tester, find.text('Record new leave'));
    // Today (Thu 26 Nov 2026) is suggested as a one-day leave.
    expect(find.text('Thu, 26 Nov 2026'), findsNWidgets(2));
    expect(tester.widget<Text>(find.byKey(const ValueKey('leave-days'))).data, '1');
    expect(find.textContaining('After this you will have 24 days left.', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Half a day less'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('leave-days'))).data, '0.5');

    await tapVisible(tester, find.text('Save leave record'));

    expect(store.leaves.single.days, 0.5);
    await scrollToTop(tester);
    expect(daysLeft(tester), '24.5');

    // The data survives a restart.
    final reloaded = LeaveStore(clock: () => d('2026-11-26'));
    await reloaded.load();
    expect(reloaded.leaves.single.days, 0.5);
    expect(reloaded.contracts.single.years, 1);
  });

  testWidgets('calendar, history and contract tabs show the records', (tester) async {
    final store = await loadStore(
      saved(
        contracts: [
          {...twoYearContract, 'start': '2026-03-01', 'months': 3},
        ],
        leaves: [
          {'id': 'a', 'start': '2026-03-18', 'end': '2026-03-18', 'days': 1, 'note': ''},
          {'id': 'b', 'start': '2026-11-17', 'end': '2026-11-18', 'days': 2, 'note': 'Family trip'},
        ],
      ),
    );
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));
    expect(daysLeft(tester), '22');

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('No leave recorded for this date.'), findsOneWidget);
    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('17 – 18 Nov 2026'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Family trip'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('2 records'), findsOneWidget);
    expect(find.text('3 days used'), findsOneWidget);
    expect(find.text('18 Mar 2026'), findsOneWidget);

    await tester.tap(find.text('Contract'));
    await tester.pumpAndSettle();
    expect(find.text('2-year 3-month contract'), findsOneWidget);
    expect(find.text('1 Mar 2026 – 31 May 2028'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Prorated + carried in'), 200);
    expect(find.text('6 + 10'), findsOneWidget);
  });

  testWidgets('warns when the contract has run out', (tester) async {
    final store = await loadStore(saved(contracts: [twoYearContract]), today: '2027-03-05');
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    expect(find.textContaining('No contract covers today'), findsOneWidget);
    expect(find.text('1 Mar 2026 – 28 Feb 2027'), findsOneWidget);
  });

  test('backup round-trips and bad backups change nothing', () async {
    final store = await loadStore(
      saved(
        contracts: [
          {...twoYearContract, 'months': 3},
        ],
        leaves: [
          {'id': 'a', 'start': '2025-06-02', 'end': '2025-06-13', 'days': 10, 'note': 'x'},
        ],
      ),
    );
    final backup = store.exportJson();

    final other = await loadStore({});
    expect(await other.importJson(backup), isNull);
    expect(other.contracts.single.years, 2);
    expect(other.contracts.single.months, 3);
    expect(other.leaves.single.note, 'x');

    expect(await other.importJson('not a backup'), isNotNull);
    expect(
      await other.importJson('{"contracts":[],"leaves":[{"start":"2025-06-02","end":"2025-06-02","days":1}]}'),
      contains('leave problem'),
    );
    expect(other.leaves.single.note, 'x');
  });

  test('data saved before months existed still loads', () async {
    final store = await loadStore(saved(contracts: [twoYearContract]));
    expect(store.contracts.single.months, 0);
    expect(contractLength(store.contracts.single), '2 years');
  });

  test('deleting a contract removes its leave only', () async {
    final store = await loadStore(
      saved(
        contracts: [
          {...twoYearContract, 'years': 1},
          {...twoYearContract, 'id': 'c2', 'start': '2026-03-01', 'years': 1},
        ],
        leaves: [
          {'id': 'a', 'start': '2025-06-02', 'end': '2025-06-02', 'days': 1, 'note': ''},
          {'id': 'b', 'start': '2026-06-02', 'end': '2026-06-02', 'days': 1, 'note': ''},
        ],
      ),
    );
    await store.deleteContract(store.contracts.first);
    expect(store.contracts.single.id, 'c2');
    expect(store.leaves.single.id, 'b');
  });

  test('year notice explains what will be lost', () {
    Contract c(int years) =>
        Contract(id: 'c', start: d('2026-03-01'), years: years, daysPerYear: 25, carryMax: 10, broughtForward: 0);
    final today = d('2026-11-26');

    final oneYear = yearNotice(summarize([c(1)], [], today).first, today);
    expect(oneYear.warning, isTrue);
    expect(oneYear.lines.first, '94 days until this period ends on 28 Feb 2027.');
    expect(oneYear.lines.last, contains('Use your 25 days'));

    final twoYear = yearNotice(summarize([c(2)], [], today).first, today);
    expect(twoYear.warning, isTrue);
    expect(twoYear.lines.last, 'Only 10 days can carry forward. Use 15 more before then or lose them.');

    final used = [Leave(id: 'l', start: d('2026-04-01'), end: d('2026-04-28'), days: 18)];
    final safe = yearNotice(summarize([c(2)], used, today).first, today);
    expect(safe.warning, isFalse);
    expect(safe.lines.last, 'All 7 days you have left can carry forward.');
  });
}

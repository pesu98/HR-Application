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

Map<String, Object> saved({required List<Map<String, Object?>> contracts, List<Map<String, Object?>> leaves = const []}) => {
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

void main() {
  testWidgets('first launch asks for the contract and suggests 1 March', (tester) async {
    final store = await loadStore({});
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    expect(find.text('Set up your contract'), findsOneWidget);
    await tester.tap(find.text('Add contract'));
    await tester.pumpAndSettle();

    expect(find.text('Sun, 1 Mar 2026'), findsOneWidget);
    await tester.tap(find.text('2 years'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save contract'));
    await tester.pumpAndSettle();

    expect(store.contracts.single.years, 2);
    expect(find.text('1 Mar 2026 – 28 Feb 2027'), findsOneWidget);
    expect(find.text('Year 1 of 2 · current'), findsOneWidget);
    expect(find.byKey(const ValueKey('days-left')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('days-left'))).data, '25');
  });

  testWidgets('year 2 shows 25 plus the 10 carried over', (tester) async {
    final store = await loadStore(saved(contracts: [twoYearContract], leaves: [
      {'id': 'a', 'start': '2025-06-02', 'end': '2025-06-13', 'days': 10, 'note': ''},
      {'id': 'b', 'start': '2026-05-04', 'end': '2026-05-08', 'days': 5, 'note': 'Raya'},
      {'id': 'c', 'start': '2026-12-21', 'end': '2026-12-24', 'days': 4, 'note': ''},
    ]));
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    expect(find.text('1 Mar 2026 – 28 Feb 2027'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('days-left'))).data, '26');
    expect(find.text('9 of 35 days used'), findsOneWidget);
    expect(find.textContaining('last year of your contract'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Raya'), 100);
    expect(find.text('Raya'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();

    // Go back to year 1: 15 unused, 10 carried, 5 lost.
    await tester.tap(find.byTooltip('Previous leave year'));
    await tester.pumpAndSettle();
    expect(find.text('1 Mar 2025 – 28 Feb 2026'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('days-left'))).data, '15');
    expect(find.text('10 days carried over to the next year.'), findsOneWidget);
    expect(find.textContaining('5 days lost'), findsOneWidget);
  });

  testWidgets('adding a leave deducts weekdays and saves it', (tester) async {
    final store = await loadStore(saved(contracts: [
      {...twoYearContract, 'start': '2026-03-01', 'years': 1},
    ]));
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    await tester.tap(find.text('Add leave'));
    await tester.pumpAndSettle();
    // Today (Thu 26 Nov 2026) is suggested as a one-day leave.
    expect(find.text('Thu, 26 Nov 2026'), findsNWidgets(2));
    expect(tester.widget<Text>(find.byKey(const ValueKey('leave-days'))).data, '1');
    expect(find.text('After this you will have 24 days left in that leave year.'), findsOneWidget);

    await tester.tap(find.byTooltip('Half a day less'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('leave-days'))).data, '0.5');

    await tester.tap(find.text('Save leave'));
    await tester.pumpAndSettle();

    expect(store.leaves.single.days, 0.5);
    expect(tester.widget<Text>(find.byKey(const ValueKey('days-left'))).data, '24.5');

    // The data survives a restart.
    final reloaded = LeaveStore(clock: () => d('2026-11-26'));
    await reloaded.load();
    expect(reloaded.leaves.single.days, 0.5);
    expect(reloaded.contracts.single.years, 1);
  });

  testWidgets('warns when the contract has run out', (tester) async {
    final store = await loadStore(saved(contracts: [twoYearContract]), today: '2027-03-05');
    usePhoneScreen(tester);
    await tester.pumpWidget(LeaveApp(store: store));

    expect(find.textContaining('No contract covers today'), findsOneWidget);
    expect(find.text('1 Mar 2026 – 28 Feb 2027'), findsOneWidget);
  });

  test('backup round-trips and bad backups change nothing', () async {
    final store = await loadStore(saved(contracts: [twoYearContract], leaves: [
      {'id': 'a', 'start': '2025-06-02', 'end': '2025-06-13', 'days': 10, 'note': 'x'},
    ]));
    final backup = store.exportJson();

    final other = await loadStore({});
    expect(await other.importJson(backup), isNull);
    expect(other.contracts.single.years, 2);
    expect(other.leaves.single.note, 'x');

    expect(await other.importJson('not a backup'), isNotNull);
    expect(await other.importJson('{"contracts":[],"leaves":[{"start":"2025-06-02","end":"2025-06-02","days":1}]}'),
        contains('leave problem'));
    expect(other.leaves.single.note, 'x');
  });

  test('deleting a contract removes its leave only', () async {
    final store = await loadStore(saved(contracts: [
      {...twoYearContract, 'years': 1},
      {...twoYearContract, 'id': 'c2', 'start': '2026-03-01', 'years': 1},
    ], leaves: [
      {'id': 'a', 'start': '2025-06-02', 'end': '2025-06-02', 'days': 1, 'note': ''},
      {'id': 'b', 'start': '2026-06-02', 'end': '2026-06-02', 'days': 1, 'note': ''},
    ]));
    await store.deleteContract(store.contracts.first);
    expect(store.contracts.single.id, 'c2');
    expect(store.leaves.single.id, 'b');
  });

  test('year notice explains what will be lost', () {
    Contract c(int years) => Contract(
        id: 'c', start: d('2026-03-01'), years: years, daysPerYear: 25, carryMax: 10, broughtForward: 0);
    final today = d('2026-11-26');

    final oneYear = yearNotice(summarize([c(1)], [], today).first, today);
    expect(oneYear.warning, isTrue);
    expect(oneYear.lines.first, '94 days until this leave year ends on 28 Feb 2027.');
    expect(oneYear.lines.last, contains('Use your 25 days'));

    final twoYear = yearNotice(summarize([c(2)], [], today).first, today);
    expect(twoYear.warning, isTrue);
    expect(twoYear.lines.last, contains('Only 10 days can carry over'));
    expect(twoYear.lines.last, contains('Use 15 more'));

    final used = [Leave(id: 'l', start: d('2026-04-01'), end: d('2026-04-28'), days: 18)];
    final safe = yearNotice(summarize([c(2)], used, today).first, today);
    expect(safe.warning, isFalse);
    expect(safe.lines.last, 'All 7 days you have left can carry over to next year.');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:leave_tracker/leave_calculator.dart';
import 'package:leave_tracker/models.dart';

DateTime d(String iso) => parseIsoDate(iso)!;

Contract contract(String id, String start, int years, {double bf = 0, double perYear = 25, double carryMax = 10}) =>
    Contract(id: id, start: d(start), years: years, daysPerYear: perYear, carryMax: carryMax, broughtForward: bf);

int _leaveId = 0;
Leave leave(String start, String end, double days) =>
    Leave(id: 'l${_leaveId++}', start: d(start), end: d(end), days: days);

void main() {
  group('leave years', () {
    test('run from 1 March to the end of February', () {
      final years = leaveYears(contract('c', '2026-03-01', 2));
      expect(years, hasLength(2));
      expect(isoDate(years[0].start), '2026-03-01');
      expect(isoDate(years[0].end), '2027-02-28');
      expect(isoDate(years[1].start), '2027-03-01');
      expect(isoDate(years[1].end), '2028-02-29'); // leap year
      expect(years[0].isFinal, isFalse);
      expect(years[1].isFinal, isTrue);
      expect(isoDate(contractEnd(contract('c', '2026-03-01', 2))), '2028-02-29');
    });
  });

  group('one-year contract', () {
    final s = summarize(
      [contract('c', '2026-03-01', 1)],
      [leave('2026-04-06', '2026-04-10', 5), leave('2026-12-21', '2026-12-24', 4)],
      d('2026-11-26'),
    );

    test('25 days, split into taken and planned', () {
      expect(s, hasLength(1));
      expect(s[0].total, 25);
      expect(s[0].taken, 5);
      expect(s[0].upcoming, 4);
      expect(s[0].remaining, 16);
    });

    test('nothing carries out of the contract', () {
      expect(s[0].year.isFinal, isTrue);
      expect(s[0].carryOut, 0);
      expect(s[0].forfeit, 16);
    });

    test('knows the current year and days to its end', () {
      expect(s[0].isCurrent, isTrue);
      expect(s[0].daysToEnd, 94);
    });
  });

  group('two-year contract', () {
    test('carries at most 10 unused days into year 2', () {
      final s = summarize(
        [contract('c', '2025-03-01', 2)],
        [leave('2025-06-02', '2025-06-13', 10), leave('2026-05-04', '2026-05-08', 5)],
        d('2026-11-26'),
      );
      expect(s[0].remaining, 15);
      expect(s[0].carryOut, 10);
      expect(s[0].forfeit, 5);
      expect(s[1].carriedIn, 10);
      expect(s[1].total, 35);
      expect(s[1].remaining, 30);
      expect(s[1].isCurrent, isTrue);
      expect(s[1].carryOut, 0);
      expect(s[1].forfeit, 30);
    });

    test('carries exactly what is left when under the limit', () {
      final s = summarize([contract('c', '2025-03-01', 2)], [leave('2025-06-02', '2025-06-27', 19.5)], d('2026-11-26'));
      expect(s[0].carryOut, 5.5);
      expect(s[0].forfeit, 0);
      expect(s[1].total, 30.5);
    });

    test('an overdrawn year carries nothing, not a debt', () {
      final s = summarize([contract('c', '2025-03-01', 2)], [leave('2025-06-02', '2025-07-11', 27)], d('2026-11-26'));
      expect(s[0].remaining, -2);
      expect(s[0].carryOut, 0);
      expect(s[0].forfeit, 0);
      expect(s[1].total, 25);
    });

    test('planned leave in year 1 reduces what carries over', () {
      final s = summarize([contract('c', '2026-03-01', 2)], [leave('2026-12-01', '2026-12-28', 20)], d('2026-11-26'));
      expect(s[0].upcoming, 20);
      expect(s[0].carryOut, 5);
      expect(s[1].total, 30);
    });
  });

  group('separate contracts', () {
    test('do not chain; a new contract uses its brought-forward days', () {
      final s = summarize(
        [contract('new', '2026-03-01', 1, bf: 3), contract('old', '2025-03-01', 1)],
        [],
        d('2026-11-26'),
      );
      expect(isoDate(s[0].year.start), '2025-03-01'); // oldest first
      expect(s[0].forfeit, 25);
      expect(s[1].carriedIn, 3);
      expect(s[1].total, 28);
    });
  });

  group('year boundaries', () {
    final contracts = [contract('c', '2026-03-01', 2)];

    test('28 Feb belongs to year 1 and 1 March to year 2', () {
      final s = summarize(
        contracts,
        [leave('2027-02-26', '2027-02-26', 1), leave('2027-03-01', '2027-03-01', 1)],
        d('2027-03-01'),
      );
      expect(s[0].used, 1);
      expect(s[1].used, 1);
      expect(s[1].taken, 1); // leave starting today counts as taken
      expect(s[0].isCurrent, isFalse);
      expect(s[1].isCurrent, isTrue);
    });

    test('a leave must fit inside one leave year', () {
      expect(leaveProblem(contracts, d('2026-12-21'), d('2026-12-24')), isNull);
      expect(leaveProblem(contracts, d('2027-02-25'), d('2027-03-02')), contains('two leaves'));
      expect(leaveProblem(contracts, d('2026-02-27'), d('2026-02-27')), contains('No contract'));
      expect(leaveProblem(contracts, d('2026-05-05'), d('2026-05-04')), contains('before the first day'));
    });
  });

  group('checkLeave', () {
    final contracts = [contract('c', '2026-03-01', 1)];
    final existing = [Leave(id: 'a', start: d('2026-04-06'), end: d('2026-04-10'), days: 5)];

    test('accepts whole and half days', () {
      expect(checkLeave(contracts, existing, leave('2026-05-04', '2026-05-04', 0.5)), isNull);
      expect(checkLeave(contracts, existing, leave('2026-05-04', '2026-05-08', 5)), isNull);
    });

    test('rejects bad day counts', () {
      expect(checkLeave(contracts, existing, leave('2026-05-04', '2026-05-04', 0)), isNotNull);
      expect(checkLeave(contracts, existing, leave('2026-05-04', '2026-05-04', 0.3)), isNotNull);
      expect(checkLeave(contracts, existing, leave('2026-05-04', '2026-05-05', 3)), isNotNull);
    });

    test('rejects overlap, but not when editing the same leave', () {
      expect(checkLeave(contracts, existing, leave('2026-04-10', '2026-04-13', 2)), contains('overlaps'));
      expect(
        checkLeave(contracts, existing, Leave(id: 'a', start: d('2026-04-06'), end: d('2026-04-09'), days: 4)),
        isNull,
      );
    });
  });

  group('checkContract', () {
    test('back-to-back contracts are fine, overlapping ones are not', () {
      final first = contract('a', '2025-03-01', 1);
      expect(checkContract([first], [], contract('b', '2026-03-01', 2)), isNull);
      expect(checkContract([contract('a', '2025-03-01', 2)], [], contract('b', '2026-03-01', 1)), contains('overlaps'));
    });

    test('cannot be changed so that recorded leave falls outside it', () {
      final existing = contract('a', '2026-03-01', 1);
      final leaves = [leave('2026-04-06', '2026-04-10', 5)];
      expect(checkContract([existing], leaves, contract('a', '2026-03-01', 2)), isNull);
      expect(checkContract([existing], leaves, contract('a', '2026-05-01', 1)), contains('no longer fit'));
    });

    test('rejects nonsense numbers', () {
      expect(checkContract([], [], contract('a', '2026-03-01', 0)), isNotNull);
      expect(checkContract([], [], contract('a', '2026-03-01', 1, perYear: 0)), isNotNull);
      expect(checkContract([], [], contract('a', '2026-03-01', 1, carryMax: -1)), isNotNull);
    });
  });

  group('day counting and formatting', () {
    test('working days skip weekends', () {
      expect(workingDays(d('2026-11-23'), d('2026-11-27')), 5);
      expect(workingDays(d('2026-11-27'), d('2026-11-30')), 2);
      expect(workingDays(d('2026-11-28'), d('2026-11-29')), 0);
      expect(calendarDays(d('2026-11-27'), d('2026-11-30')), 4);
    });

    test('latest 1 March on or before today', () {
      expect(isoDate(latestAnniversary(d('2026-11-26'), 3, 1)), '2026-03-01');
      expect(isoDate(latestAnniversary(d('2027-02-28'), 3, 1)), '2026-03-01');
      expect(isoDate(latestAnniversary(d('2027-03-01'), 3, 1)), '2027-03-01');
    });

    test('dates parse strictly', () {
      expect(parseIsoDate('2026-02-28'), isNotNull);
      expect(parseIsoDate('2026-02-30'), isNull);
      expect(parseIsoDate('1 March'), isNull);
    });

    test('formatting', () {
      expect(formatDays(16), '16');
      expect(formatDays(5.5), '5.5');
      expect(daysLabel(1), '1 day');
      expect(daysLabel(0.5), '0.5 days');
      expect(prettyRange(d('2026-12-21'), d('2026-12-21')), '21 Dec 2026');
      expect(prettyRange(d('2026-12-21'), d('2026-12-24')), '21 – 24 Dec 2026');
      expect(prettyRange(d('2026-11-28'), d('2026-12-02')), '28 Nov – 2 Dec 2026');
      expect(prettyRange(d('2026-12-28'), d('2027-01-02')), '28 Dec 2026 – 2 Jan 2027');
    });
  });
}

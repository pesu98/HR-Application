/// Leave maths for contract-based annual leave.
///
/// A contract starts on a date (e.g. 1 March) and lasts one or more years.
/// Each contract year is its own leave year with its own entitlement.
/// Unused days carry from one year to the next INSIDE the same contract, up
/// to the contract's carry limit. Nothing carries out of the last year of a
/// contract automatically; a new contract can be given a manual
/// "brought forward" balance instead.
library;

import 'models.dart';

/// One leave year inside a contract.
class LeaveYear {
  const LeaveYear({
    required this.contractId,
    required this.index,
    required this.count,
    required this.start,
    required this.end,
  });

  final String contractId;

  /// 1-based position inside the contract.
  final int index;

  /// Number of years in the contract.
  final int count;
  final DateTime start;
  final DateTime end;

  String get key => '$contractId#$index';
  bool get isFinal => index == count;
  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
}

/// The balance of one leave year.
class YearSummary {
  const YearSummary({
    required this.year,
    required this.entitlement,
    required this.carriedIn,
    required this.taken,
    required this.upcoming,
    required this.carryMax,
    required this.carryOut,
    required this.isCurrent,
    required this.daysToEnd,
    required this.leaves,
  });

  final LeaveYear year;
  final double entitlement;

  /// Days carried in from the previous year (or brought forward).
  final double carriedIn;

  /// Leave that has already started.
  final double taken;

  /// Leave booked for a future date.
  final double upcoming;
  final double carryMax;

  /// Unused days that move on to the next year of the same contract.
  final double carryOut;
  final bool isCurrent;

  /// Days from today to the end of the year; null unless current.
  final int? daysToEnd;
  final List<Leave> leaves;

  double get total => entitlement + carriedIn;
  double get used => taken + upcoming;
  double get remaining => total - used;

  /// Unused days that are lost when the year ends.
  double get forfeit => (remaining > 0 ? remaining : 0) - carryOut;
}

List<LeaveYear> leaveYears(Contract c) {
  final years = <LeaveYear>[];
  final count = c.years < 1 ? 1 : c.years;
  for (var k = 0; k < count; k++) {
    final start = DateTime.utc(c.start.year + k, c.start.month, c.start.day);
    final next = DateTime.utc(c.start.year + k + 1, c.start.month, c.start.day);
    years.add(LeaveYear(
      contractId: c.id,
      index: k + 1,
      count: count,
      start: start,
      end: next.subtract(const Duration(days: 1)),
    ));
  }
  return years;
}

DateTime contractEnd(Contract c) => leaveYears(c).last.end;

/// Balance of every leave year of every contract, oldest first.
List<YearSummary> summarize(List<Contract> contracts, List<Leave> leaves, DateTime today) {
  final sorted = [...contracts]..sort((a, b) => a.start.compareTo(b.start));
  final sortedLeaves = [...leaves]..sort((a, b) => a.start.compareTo(b.start));
  final out = <YearSummary>[];

  for (final contract in sorted) {
    var carry = contract.broughtForward > 0 ? contract.broughtForward : 0.0;
    final carryMax = contract.carryMax > 0 ? contract.carryMax : 0.0;

    for (final year in leaveYears(contract)) {
      var taken = 0.0;
      var upcoming = 0.0;
      final mine = <Leave>[];
      for (final leave in sortedLeaves) {
        if (!year.contains(leave.start)) continue;
        mine.add(leave);
        if (leave.start.isAfter(today)) {
          upcoming += leave.days;
        } else {
          taken += leave.days;
        }
      }

      final remaining = contract.daysPerYear + carry - taken - upcoming;
      final unused = remaining > 0 ? remaining : 0.0;
      final carryOut = year.isFinal ? 0.0 : (unused < carryMax ? unused : carryMax);
      final isCurrent = year.contains(today);

      out.add(YearSummary(
        year: year,
        entitlement: contract.daysPerYear,
        carriedIn: carry,
        taken: taken,
        upcoming: upcoming,
        carryMax: carryMax,
        carryOut: carryOut,
        isCurrent: isCurrent,
        daysToEnd: isCurrent ? daysBetween(today, year.end) : null,
        leaves: mine,
      ));
      carry = carryOut;
    }
  }
  return out;
}

/// The leave year containing [date], or null.
LeaveYear? findYear(List<Contract> contracts, DateTime date) {
  for (final c in contracts) {
    for (final y in leaveYears(c)) {
      if (y.contains(date)) return y;
    }
  }
  return null;
}

/// Why a leave does not fit the contracts, or null if it fits.
/// A leave must sit entirely inside one leave year.
String? leaveProblem(List<Contract> contracts, DateTime start, DateTime end) {
  if (end.isBefore(start)) return 'The last day is before the first day.';
  final year = findYear(contracts, start);
  if (year == null) {
    return 'No contract covers ${prettyDate(start)}. Add that contract first.';
  }
  if (end.isAfter(year.end)) {
    final next = year.end.add(const Duration(days: 1));
    return 'This leave runs past the end of the leave year (${prettyDate(year.end)}). '
        'Enter it as two leaves: one up to ${prettyDate(year.end)} and one from ${prettyDate(next)}.';
  }
  return null;
}

/// Checks a leave before saving. Returns the problem, or null if valid.
String? checkLeave(List<Contract> contracts, List<Leave> leaves, Leave leave) {
  final problem = leaveProblem(contracts, leave.start, leave.end);
  if (problem != null) return problem;
  if (leave.days <= 0) return 'Days must be more than 0.';
  if ((leave.days * 2) != (leave.days * 2).roundToDouble()) {
    return 'Days must be a whole or half number, like 1 or 0.5.';
  }
  final span = calendarDays(leave.start, leave.end);
  if (leave.days > span) {
    return 'That is ${formatDays(leave.days)} days of leave in a $span-day period.';
  }
  for (final other in leaves) {
    if (other.id == leave.id) continue;
    if (!leave.start.isAfter(other.end) && !other.start.isAfter(leave.end)) {
      return 'This overlaps leave you already recorded for ${prettyRange(other.start, other.end)}.';
    }
  }
  return null;
}

/// Checks a contract before saving. Returns the problem, or null if valid.
String? checkContract(List<Contract> contracts, List<Leave> leaves, Contract contract) {
  if (contract.years < 1 || contract.years > 10) {
    return 'Contract length must be between 1 and 10 years.';
  }
  if (contract.daysPerYear <= 0 || contract.daysPerYear > 366) {
    return 'Days per year must be between 1 and 366.';
  }
  if (contract.carryMax < 0) return 'Carry-over limit cannot be negative.';
  if (contract.broughtForward < 0) return 'Days brought forward cannot be negative.';

  final next = [
    for (final c in contracts)
      if (c.id != contract.id) c,
    contract,
  ];
  final end = contractEnd(contract);
  for (final other in next) {
    if (other.id == contract.id) continue;
    if (!contract.start.isAfter(contractEnd(other)) && !other.start.isAfter(end)) {
      return 'This overlaps your contract of ${prettyRange(other.start, contractEnd(other))}.';
    }
  }
  for (final leave in leaves) {
    if (leaveProblem(next, leave.start, leave.end) != null) {
      return 'Your leave on ${prettyRange(leave.start, leave.end)} would no longer fit inside a '
          'leave year. Change or delete that leave first.';
    }
  }
  return null;
}

/// Monday-to-Friday days from [start] to [end], inclusive.
int workingDays(DateTime start, DateTime end) {
  var count = 0;
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    if (d.weekday <= DateTime.friday) count++;
  }
  return count;
}

/// Calendar days from [start] to [end], inclusive.
int calendarDays(DateTime start, DateTime end) => daysBetween(start, end) + 1;

/// Whole days from [from] to [to] (0 when equal).
int daysBetween(DateTime from, DateTime to) => to.difference(from).inDays;

/// The most recent occurrence of [month]/[day] on or before [today].
DateTime latestAnniversary(DateTime today, int month, int day) {
  final thisYear = DateTime.utc(today.year, month, day);
  return thisYear.isAfter(today) ? DateTime.utc(today.year - 1, month, day) : thisYear;
}

// --- Formatting --------------------------------------------------------------

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `16` for whole numbers, `5.5` for halves.
String formatDays(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// `1 day`, `5.5 days`.
String daysLabel(double v) => '${formatDays(v)} ${v == 1 ? 'day' : 'days'}';

/// `1 Mar 2026`.
String prettyDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// `Mon, 1 Mar 2026`.
String prettyDateLong(DateTime d) => '${_weekdays[d.weekday - 1]}, ${prettyDate(d)}';

/// `21 Dec 2026`, `21 – 24 Dec 2026`, `28 Nov – 2 Dec 2026` or
/// `28 Dec 2026 – 2 Jan 2027`.
String prettyRange(DateTime a, DateTime b) {
  if (a == b) return prettyDate(a);
  if (a.year != b.year) return '${prettyDate(a)} – ${prettyDate(b)}';
  if (a.month != b.month) return '${a.day} ${_months[a.month - 1]} – ${prettyDate(b)}';
  return '${a.day} – ${prettyDate(b)}';
}

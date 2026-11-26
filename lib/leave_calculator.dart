/// Leave maths for contract-based annual leave.
///
/// A contract starts on a date (e.g. 1 March) and lasts some years and
/// months, e.g. 2 years 3 months. Each full contract year is a leave year
/// with the full entitlement; left-over months at the end form a short final
/// period whose entitlement is prorated.
///
/// Unused days of a period carry into the next period of the SAME contract,
/// up to the contract's carry limit. Carried days are used first, expire at
/// the end of the period they were carried into, and cannot be carried
/// again. Nothing carries out of the last period of a contract; a new
/// contract can be given a manual "brought forward" balance instead.
library;

import 'models.dart';

/// One leave period inside a contract: a full year, or the short final
/// period of a contract that does not end on a whole year.
class LeaveYear {
  const LeaveYear({
    required this.contractId,
    required this.index,
    required this.count,
    required this.start,
    required this.end,
    required this.months,
  });

  final String contractId;

  /// 1-based position inside the contract.
  final int index;

  /// Number of leave periods in the contract.
  final int count;
  final DateTime start;
  final DateTime end;

  /// Length in months: 12, or fewer for a prorated final period.
  final int months;

  String get key => '$contractId#$index';
  bool get isFinal => index == count;
  bool get isPartial => months < 12;
  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
}

/// The balance of one leave period.
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

  /// Entitlement for this period (prorated when the period is partial).
  final double entitlement;

  /// Days carried in from the previous period (or brought forward).
  final double carriedIn;

  /// Leave that has already started.
  final double taken;

  /// Leave recorded for a future date.
  final double upcoming;
  final double carryMax;

  /// Unused days of this period's own entitlement that move to the next
  /// period of the same contract.
  final double carryOut;
  final bool isCurrent;

  /// Days from today to the end of the period; null unless current.
  final int? daysToEnd;
  final List<Leave> leaves;

  double get total => entitlement + carriedIn;
  double get used => taken + upcoming;
  double get remaining => total - used;

  /// Carried-in days are deducted first.
  double get carryUsed => used < carriedIn ? used : carriedIn;
  double get carryLeft => carriedIn - carryUsed;

  /// What is used and left of this period's own entitlement.
  double get baseUsed => used - carryUsed;
  double get baseLeft => entitlement - baseUsed;

  /// Unused days that are lost when the period ends: carried-in days that
  /// were not used, plus own entitlement above the carry limit.
  double get forfeit => remaining > 0 ? remaining - carryOut : 0;
}

/// [d] moved forward by [months], keeping the day of month where it exists.
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, d.day > lastDay ? lastDay : d.day);
}

/// Entitlement for a period of [months] months. A fraction under half a day
/// is dropped and half a day or more counts as a full day, as in section 60E
/// of the Malaysian Employment Act.
double proratedEntitlement(double daysPerYear, int months) {
  if (months >= 12) return daysPerYear;
  final raw = daysPerYear * months / 12;
  final whole = raw.floorToDouble();
  return raw - whole >= 0.5 ? whole + 1 : whole;
}

List<LeaveYear> leaveYears(Contract c) {
  final total = c.totalMonths < 1 ? 12 : c.totalMonths;
  final count = (total / 12).ceil();
  final years = <LeaveYear>[];
  for (var k = 0; k < count; k++) {
    final months = (k + 1) * 12 <= total ? 12 : total - k * 12;
    final start = addMonths(c.start, k * 12);
    final next = addMonths(c.start, k * 12 + months);
    years.add(
      LeaveYear(
        contractId: c.id,
        index: k + 1,
        count: count,
        start: start,
        end: next.subtract(const Duration(days: 1)),
        months: months,
      ),
    );
  }
  return years;
}

DateTime contractEnd(Contract c) => leaveYears(c).last.end;

/// `2 years 3 months`, `1 year`, `6 months`.
String contractLength(Contract c) {
  final parts = [
    if (c.years > 0) '${c.years} ${c.years == 1 ? 'year' : 'years'}',
    if (c.months > 0) '${c.months} ${c.months == 1 ? 'month' : 'months'}',
  ];
  return parts.isEmpty ? '1 year' : parts.join(' ');
}

/// `2-year contract`, `2-year 3-month contract`, `6-month contract`.
String contractTitle(Contract c) {
  final parts = [if (c.years > 0) '${c.years}-year', if (c.months > 0) '${c.months}-month'];
  return '${parts.isEmpty ? '1-year' : parts.join(' ')} contract';
}

/// Balance of every leave period of every contract, oldest first.
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

      final entitlement = proratedEntitlement(contract.daysPerYear, year.months);
      final used = taken + upcoming;
      // Carried-in days go first; only this period's own unused entitlement
      // can move on.
      final baseLeft = entitlement - (used > carry ? used - carry : 0);
      final unused = baseLeft > 0 ? baseLeft : 0.0;
      final carryOut = year.isFinal ? 0.0 : (unused < carryMax ? unused : carryMax);
      final isCurrent = year.contains(today);

      out.add(
        YearSummary(
          year: year,
          entitlement: entitlement,
          carriedIn: carry,
          taken: taken,
          upcoming: upcoming,
          carryMax: carryMax,
          carryOut: carryOut,
          isCurrent: isCurrent,
          daysToEnd: isCurrent ? daysBetween(today, year.end) : null,
          leaves: mine,
        ),
      );
      carry = carryOut;
    }
  }
  return out;
}

/// The leave period containing [date], or null.
LeaveYear? findYear(List<Contract> contracts, DateTime date) {
  for (final c in contracts) {
    for (final y in leaveYears(c)) {
      if (y.contains(date)) return y;
    }
  }
  return null;
}

/// Why a leave does not fit the contracts, or null if it fits.
/// A leave must sit entirely inside one leave period.
String? leaveProblem(List<Contract> contracts, DateTime start, DateTime end) {
  if (end.isBefore(start)) return 'The last day is before the first day.';
  final year = findYear(contracts, start);
  if (year == null) {
    return 'No contract covers ${prettyDate(start)}. Add that contract first.';
  }
  if (end.isAfter(year.end)) {
    final next = year.end.add(const Duration(days: 1));
    return 'This leave runs past the end of the contract year (${prettyDate(year.end)}). '
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
  if (contract.years < 0 || contract.years > 10 || contract.months < 0 || contract.months > 11) {
    return 'Contract length must be 0-10 years and 0-11 months.';
  }
  if (contract.totalMonths < 1) return 'The contract must be at least 1 month long.';
  if (contract.daysPerYear <= 0 || contract.daysPerYear > 366) {
    return 'Days per year must be between 1 and 366.';
  }
  if (contract.carryMax < 0) return 'Carry-forward limit cannot be negative.';
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
          'contract year. Change or delete that leave first.';
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

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthNamesLong = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `16` for whole numbers, `5.5` for halves.
String formatDays(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// `1 day`, `5.5 days`.
String daysLabel(double v) => '${formatDays(v)} ${v == 1 ? 'day' : 'days'}';

/// `1 Mar 2026`.
String prettyDate(DateTime d) => '${d.day} ${monthNames[d.month - 1]} ${d.year}';

/// `1 Mar`.
String shortDate(DateTime d) => '${d.day} ${monthNames[d.month - 1]}';

/// `Mon, 1 Mar 2026`.
String prettyDateLong(DateTime d) => '${_weekdays[d.weekday - 1]}, ${prettyDate(d)}';

/// `21 Dec 2026`, `21 – 24 Dec 2026`, `28 Nov – 2 Dec 2026` or
/// `28 Dec 2026 – 2 Jan 2027`.
String prettyRange(DateTime a, DateTime b) {
  if (a == b) return prettyDate(a);
  if (a.year != b.year) return '${prettyDate(a)} – ${prettyDate(b)}';
  if (a.month != b.month) return '${a.day} ${monthNames[a.month - 1]} – ${prettyDate(b)}';
  return '${a.day} – ${prettyDate(b)}';
}

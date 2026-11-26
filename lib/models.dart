/// Calendar dates are stored as `DateTime.utc(y, m, d)` so that day
/// arithmetic is never shifted by time zones or daylight saving.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parses a strict `YYYY-MM-DD` date. Returns null for anything else,
/// including impossible dates such as 2026-02-30.
DateTime? parseIsoDate(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (m == null) return null;
  final d = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return isoDate(d) == value ? d : null;
}

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_idCounter++).toRadixString(36)}';

/// One employment contract. Each year of the contract is its own leave year.
class Contract {
  const Contract({
    required this.id,
    required this.start,
    required this.years,
    this.months = 0,
    required this.daysPerYear,
    required this.carryMax,
    required this.broughtForward,
  });

  final String id;

  /// First day of the contract, e.g. 1 March.
  final DateTime start;

  /// Whole years in the contract.
  final int years;

  /// Extra months after the whole years (0-11). A contract of 2 years and
  /// 3 months ends with a 3-month leave period whose entitlement is prorated.
  final int months;

  int get totalMonths => years * 12 + months;

  /// Leave entitlement for each contract year.
  final double daysPerYear;

  /// Most unused days that move from one contract year to the next.
  final double carryMax;

  /// Days brought in from before this contract (normally 0).
  final double broughtForward;

  Map<String, Object?> toJson() => {
    'id': id,
    'start': isoDate(start),
    'years': years,
    'months': months,
    'daysPerYear': daysPerYear,
    'carryMax': carryMax,
    'broughtForward': broughtForward,
  };

  static Contract? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = parseIsoDate(json['start']);
    final years = json['years'];
    final months = json['months'];
    final daysPerYear = json['daysPerYear'];
    final carryMax = json['carryMax'];
    final broughtForward = json['broughtForward'];
    if (start == null || years is! int || daysPerYear is! num || carryMax is! num) {
      return null;
    }
    return Contract(
      id: json['id'] is String ? json['id'] as String : newId(),
      start: start,
      years: years,
      months: months is int ? months : 0,
      daysPerYear: daysPerYear.toDouble(),
      carryMax: carryMax.toDouble(),
      broughtForward: broughtForward is num ? broughtForward.toDouble() : 0,
    );
  }
}

/// One block of leave, from [start] to [end] inclusive.
class Leave {
  const Leave({required this.id, required this.start, required this.end, required this.days, this.note = ''});

  final String id;
  final DateTime start;
  final DateTime end;

  /// Leave days deducted. Can be less than the calendar span (weekends,
  /// public holidays) and can be a half day.
  final double days;
  final String note;

  Map<String, Object?> toJson() => {'id': id, 'start': isoDate(start), 'end': isoDate(end), 'days': days, 'note': note};

  static Leave? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = parseIsoDate(json['start']);
    final end = parseIsoDate(json['end']);
    final days = json['days'];
    if (start == null || end == null || days is! num) return null;
    return Leave(
      id: json['id'] is String ? json['id'] as String : newId(),
      start: start,
      end: end,
      days: days.toDouble(),
      note: json['note'] is String ? json['note'] as String : '',
    );
  }
}

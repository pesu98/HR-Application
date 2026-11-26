import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leave_calculator.dart';
import 'models.dart';

/// Holds contracts and leave, and keeps them saved on the device.
///
/// Methods that change data return an error message when the change is not
/// allowed, or null when it was saved.
class LeaveStore extends ChangeNotifier {
  LeaveStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const storageKey = 'leave_tracker_data_v1';

  final DateTime Function() _clock;
  SharedPreferences? _prefs;
  List<Contract> _contracts = [];
  List<Leave> _leaves = [];

  DateTime get today => dateOnly(_clock());
  List<Contract> get contracts => List.unmodifiable(_contracts);
  List<Leave> get leaves => List.unmodifiable(_leaves);

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    final parsed = _decode(raw);
    if (parsed == null) {
      // Keep unreadable data aside instead of overwriting it on next save.
      await prefs.setString('${storageKey}_unreadable', raw);
      return;
    }
    _contracts = parsed.$1;
    _leaves = parsed.$2;
    notifyListeners();
  }

  Future<String?> saveContract(Contract contract) async {
    final problem = checkContract(_contracts, _leaves, contract);
    if (problem != null) return problem;
    _contracts = [
      for (final c in _contracts)
        if (c.id != contract.id) c,
      contract,
    ]..sort((a, b) => a.start.compareTo(b.start));
    await _persist();
    return null;
  }

  /// Leave recorded inside [contract].
  List<Leave> leavesIn(Contract contract) {
    final end = contractEnd(contract);
    return [
      for (final l in _leaves)
        if (!l.start.isBefore(contract.start) && !l.start.isAfter(end)) l,
    ];
  }

  /// Deletes a contract together with the leave recorded inside it.
  Future<void> deleteContract(Contract contract) async {
    final gone = {for (final l in leavesIn(contract)) l.id};
    _leaves = [
      for (final l in _leaves)
        if (!gone.contains(l.id)) l,
    ];
    _contracts = [
      for (final c in _contracts)
        if (c.id != contract.id) c,
    ];
    await _persist();
  }

  Future<String?> saveLeave(Leave leave) async {
    final problem = checkLeave(_contracts, _leaves, leave);
    if (problem != null) return problem;
    _leaves = [
      for (final l in _leaves)
        if (l.id != leave.id) l,
      leave,
    ]..sort((a, b) => a.start.compareTo(b.start));
    await _persist();
    return null;
  }

  Future<void> deleteLeave(String id) async {
    _leaves = [
      for (final l in _leaves)
        if (l.id != id) l,
    ];
    await _persist();
  }

  /// Everything as text, for copying somewhere safe.
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'leave_tracker',
        'version': 1,
        'contracts': [for (final c in _contracts) c.toJson()],
        'leaves': [for (final l in _leaves) l.toJson()],
      });

  /// Replaces all data with a backup made by [exportJson].
  Future<String?> importJson(String text) async {
    final parsed = _decode(text.trim());
    if (parsed == null) return 'That is not a backup from this app.';
    final (contracts, leaves) = parsed;

    final checkedContracts = <Contract>[];
    for (final c in contracts) {
      final problem = checkContract(checkedContracts, const [], c);
      if (problem != null) return 'The backup has a contract problem: $problem';
      checkedContracts.add(c);
    }
    final checkedLeaves = <Leave>[];
    for (final l in leaves) {
      final problem = checkLeave(checkedContracts, checkedLeaves, l);
      if (problem != null) return 'The backup has a leave problem: $problem';
      checkedLeaves.add(l);
    }

    _contracts = checkedContracts..sort((a, b) => a.start.compareTo(b.start));
    _leaves = checkedLeaves..sort((a, b) => a.start.compareTo(b.start));
    await _persist();
    return null;
  }

  (List<Contract>, List<Leave>)? _decode(String raw) {
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['contracts'] is! List || json['leaves'] is! List) {
      return null;
    }
    final contracts = <Contract>[];
    for (final item in json['contracts'] as List) {
      final c = Contract.fromJson(item);
      if (c == null) return null;
      contracts.add(c);
    }
    final leaves = <Leave>[];
    for (final item in json['leaves'] as List) {
      final l = Leave.fromJson(item);
      if (l == null) return null;
      leaves.add(l);
    }
    return (contracts, leaves);
  }

  Future<void> _persist() async {
    notifyListeners();
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(storageKey, exportJson());
  }
}

import 'package:flutter/material.dart';

import 'leave_calculator.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Record a new leave, or edit / delete an existing one.
class LeaveFormPage extends StatefulWidget {
  const LeaveFormPage({super.key, required this.store, required this.initialDate, this.leave});

  final LeaveStore store;

  /// The leave being edited; null when adding.
  final Leave? leave;

  /// First day suggested for a new leave.
  final DateTime initialDate;

  @override
  State<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends State<LeaveFormPage> {
  late DateTime _start;
  late DateTime _end;
  late double _days;
  late final TextEditingController _note;
  String? _error;
  bool _saving = false;

  LeaveStore get _store => widget.store;
  bool get _editing => widget.leave != null;

  @override
  void initState() {
    super.initState();
    final leave = widget.leave;
    _start = leave?.start ?? widget.initialDate;
    _end = leave?.end ?? widget.initialDate;
    _days = leave?.days ?? _suggestedDays();
    _note = TextEditingController(text: leave?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Weekdays in the range; a weekend-only range counts every day.
  double _suggestedDays() {
    final weekdays = workingDays(_start, _end);
    return (weekdays > 0 ? weekdays : calendarDays(_start, _end)).toDouble();
  }

  Future<void> _pick({required bool first}) async {
    final contracts = _store.contracts;
    final earliest = contracts.first.start;
    final latest = contractEnd(contracts.last);
    var initial = first ? _start : _end;
    if (initial.isBefore(earliest)) initial = earliest;
    if (initial.isAfter(latest)) initial = latest;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ? earliest : (_start.isBefore(earliest) ? earliest : _start),
      lastDate: latest,
      helpText: first ? 'Start date' : 'End date',
    );
    if (picked == null) return;
    final date = dateOnly(picked);
    setState(() {
      if (first) {
        // A single-day leave stays single-day when its date moves.
        if (_end == _start || _end.isBefore(date)) _end = date;
        _start = date;
      } else {
        _end = date;
      }
      _days = _suggestedDays();
      _error = null;
    });
  }

  void _step(double delta) {
    final max = calendarDays(_start, _end).toDouble();
    setState(() {
      _days = (_days + delta).clamp(0.5, max);
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await _store.saveLeave(
      Leave(id: widget.leave?.id ?? newId(), start: _start, end: _end, days: _days, note: _note.text.trim()),
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final leave = widget.leave!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this leave record?'),
        content: Text(
          '${prettyRange(leave.start, leave.end)} · ${daysLabel(leave.days)} will go back to your balance.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteLeave(leave.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// The balance of the period that [_start] falls in, without this leave;
  /// null when the date is outside every contract.
  YearSummary? _periodWithoutThis() {
    final others = [
      for (final l in _store.leaves)
        if (l.id != widget.leave?.id) l,
    ];
    for (final s in summarize(_store.contracts, others, _store.today)) {
      if (s.year.contains(_start)) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = workingDays(_start, _end);
    final period = _periodWithoutThis();
    final leftAfter = period == null ? null : period.remaining - _days;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          _editing
              ? const PageHead('LEAVE RECORD', 'Annual leave', 'Change the dates or days, or delete the record.')
              : const PageHead('NEW RECORD', 'Time for a break.', 'Record the leave you have applied for.'),
          if (period != null)
            NoticeBox(
              warn: leftAfter! < 0,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${daysLabel(period.remaining)} available',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' · ${periodLabel(period.year)}\n'),
                    TextSpan(
                      text: leftAfter < 0
                          ? 'This is ${daysLabel(-leftAfter)} more than you have left.'
                          : 'After this you will have ${daysLabel(leftAfter)} left.',
                    ),
                    if (period.carryLeft > 0)
                      TextSpan(text: ' ${daysLabel(period.carryLeft)} carried forward will be used first.'),
                  ],
                ),
              ),
            ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Start date'),
                          DateField(key: const ValueKey('start-date'), date: _start, onTap: () => _pick(first: true)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('End date'),
                DateField(key: const ValueKey('end-date'), date: _end, onTap: () => _pick(first: false)),
                const SizedBox(height: 16),
                const FieldLabel('Chargeable days'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Half a day less',
                        onPressed: _days > 0.5 ? () => _step(-0.5) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppColors.accent,
                      ),
                      Expanded(
                        child: Text(
                          formatDays(_days),
                          key: const ValueKey('leave-days'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Half a day more',
                        onPressed: _days < calendarDays(_start, _end) ? () => _step(0.5) : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$weekdays ${weekdays == 1 ? 'weekday' : 'weekdays'} (Mon–Fri) in these dates. '
                  'Lower it for a public holiday or a half day.',
                  style: subStyle,
                ),
                const SizedBox(height: 16),
                const FieldLabel('Remarks (optional)'),
                TextField(
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(hintText: 'Personal matters…', counterText: ''),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          PrimaryButton(
            icon: Icons.check,
            label: _editing ? 'Update record' : 'Save leave record',
            onPressed: _saving ? null : _save,
          ),
          if (_editing) ...[const SizedBox(height: 12), DangerButton(label: 'Delete record', onPressed: _delete)],
        ],
      ),
    );
  }
}

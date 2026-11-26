import 'package:flutter/material.dart';

import 'leave_calculator.dart';
import 'models.dart';
import 'store.dart';

/// Add a new leave, or edit / delete an existing one.
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
      helpText: first ? 'First day of leave' : 'Last day of leave',
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
    final error = await _store.saveLeave(Leave(
      id: widget.leave?.id ?? newId(),
      start: _start,
      end: _end,
      days: _days,
      note: _note.text.trim(),
    ));
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
        title: const Text('Delete this leave?'),
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

  /// Days left in the leave year after this leave, or null when the dates
  /// are outside every contract.
  double? _leftAfter() {
    final others = [
      for (final l in _store.leaves)
        if (l.id != widget.leave?.id) l,
    ];
    for (final s in summarize(_store.contracts, others, _store.today)) {
      if (s.year.contains(_start)) return s.remaining - _days;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekdays = workingDays(_start, _end);
    final leftAfter = _leftAfter();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit leave' : 'Add leave'),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Delete leave', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _DateTile(label: 'First day', date: _start, onTap: () => _pick(first: true)),
          const SizedBox(height: 8),
          _DateTile(label: 'Last day', date: _end, onTap: () => _pick(first: false)),
          const SizedBox(height: 24),
          Text('Leave days to deduct', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Half a day less',
                onPressed: _days > 0.5 ? () => _step(-0.5) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  formatDays(_days),
                  key: const ValueKey('leave-days'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall,
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Half a day more',
                onPressed: _days < calendarDays(_start, _end) ? () => _step(0.5) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$weekdays ${weekdays == 1 ? 'weekday' : 'weekdays'} (Mon–Fri) in these dates. '
            'Lower it for a public holiday or a half day.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Balik kampung',
              border: OutlineInputBorder(),
            ),
          ),
          if (leftAfter != null) ...[
            const SizedBox(height: 8),
            Text(
              leftAfter < 0
                  ? 'This is ${daysLabel(-leftAfter)} more than you have left in that leave year.'
                  : 'After this you will have ${daysLabel(leftAfter)} left in that leave year.',
              style: theme.textTheme.bodyMedium?.copyWith(color: leftAfter < 0 ? scheme.error : null),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(_editing ? 'Save changes' : 'Save leave'),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.calendar_today_outlined),
        title: Text(label),
        subtitle: Text(prettyDateLong(date)),
        trailing: const Icon(Icons.edit_calendar_outlined),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'leave_calculator.dart';
import 'models.dart';
import 'store.dart';
import 'update_widgets.dart';
import 'updater.dart';

/// Settings: contracts, backup / restore, and app updates.
class ContractsPage extends StatelessWidget {
  const ContractsPage({super.key, required this.store, this.updates});

  final LeaveStore store;

  /// Null where in-app updates are not supported.
  final UpdateController? updates;

  Future<void> _openForm(BuildContext context, [Contract? contract]) => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ContractFormPage(store: store, contract: contract),
        ),
      );

  Future<void> _copyBackup(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup copied. Paste it into a note or message to yourself.')),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste a backup below. It replaces everything currently in the app.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste backup text'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Replace my data')),
        ],
      ),
    );
    if (text == null || !context.mounted) return;
    final error = await store.importJson(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Backup restored.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final today = store.today;
        final contracts = store.contracts.reversed.toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('Contracts', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (contracts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('No contract yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
              for (final c in contracts)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: scheme.surfaceContainerLow,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => _openForm(context, c),
                    title: Text('${prettyDate(c.start)} – ${prettyDate(contractEnd(c))}'),
                    subtitle: Text(_describe(c, today)),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: Text(contracts.isEmpty ? 'Add contract' : 'Add new contract'),
                ),
              ),
              const SizedBox(height: 32),
              Text('Backup', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Your leave records are kept only on this phone. Copy a backup now and then, '
                'so you can restore them on a new phone.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copyBackup(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _restore(context),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                  ),
                ],
              ),
              if (updates != null) ...[
                const SizedBox(height: 32),
                UpdateSection(updates: updates!),
              ],
            ],
          ),
        );
      },
    );
  }

  String _describe(Contract c, DateTime today) {
    final parts = [
      '${c.years} ${c.years == 1 ? 'year' : 'years'}',
      '${formatDays(c.daysPerYear)} days a year',
      if (c.years > 1) 'carry up to ${formatDays(c.carryMax)}',
      if (c.broughtForward > 0) '${formatDays(c.broughtForward)} brought forward',
    ];
    final current = !today.isBefore(c.start) && !today.isAfter(contractEnd(c));
    return '${parts.join(' · ')}${current ? '\nCurrent contract' : ''}';
  }
}

/// Add a new contract, or edit / delete an existing one.
class ContractFormPage extends StatefulWidget {
  const ContractFormPage({super.key, required this.store, this.contract});

  final LeaveStore store;

  /// The contract being edited; null when adding.
  final Contract? contract;

  @override
  State<ContractFormPage> createState() => _ContractFormPageState();
}

class _ContractFormPageState extends State<ContractFormPage> {
  late DateTime _start;
  late int _years;
  late final TextEditingController _daysPerYear;
  late final TextEditingController _carryMax;
  late final TextEditingController _broughtForward;
  String? _error;
  bool _saving = false;

  LeaveStore get _store => widget.store;
  bool get _editing => widget.contract != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    final existing = _store.contracts;
    _start = c?.start ??
        (existing.isEmpty
            // Contracts start on 1 March; suggest the most recent one.
            ? latestAnniversary(_store.today, DateTime.march, 1)
            : contractEnd(existing.last).add(const Duration(days: 1)));
    _years = c?.years ?? 1;
    _daysPerYear = TextEditingController(text: formatDays(c?.daysPerYear ?? 25));
    _carryMax = TextEditingController(text: formatDays(c?.carryMax ?? 10));
    _broughtForward = TextEditingController(text: formatDays(c?.broughtForward ?? 0));
  }

  @override
  void dispose() {
    _daysPerYear.dispose();
    _carryMax.dispose();
    _broughtForward.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.utc(_start.year - 10),
      lastDate: DateTime.utc(_start.year + 10, 12, 31),
      helpText: 'Contract start date',
    );
    if (picked == null) return;
    setState(() {
      _start = dateOnly(picked);
      _error = null;
    });
  }

  double? _number(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final daysPerYear = _number(_daysPerYear);
    final carryMax = _number(_carryMax);
    final broughtForward = _number(_broughtForward);
    if (daysPerYear == null || carryMax == null || broughtForward == null) {
      setState(() => _error = 'Enter numbers only, like 25 or 0.5.');
      return;
    }
    setState(() => _saving = true);
    final error = await _store.saveContract(Contract(
      id: widget.contract?.id ?? newId(),
      start: _start,
      years: _years,
      daysPerYear: daysPerYear,
      carryMax: carryMax,
      broughtForward: broughtForward,
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
    final contract = widget.contract!;
    final count = _store.leavesIn(contract).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this contract?'),
        content: Text(
          count == 0
              ? 'No leave is recorded in this contract.'
              : 'The $count leave ${count == 1 ? 'entry' : 'entries'} recorded in this contract will be deleted too. '
                  'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteContract(contract);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const numeric = TextInputType.numberWithOptions(decimal: true);
    final end = DateTime.utc(_start.year + _years, _start.month, _start.day).subtract(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit contract' : 'Add contract'),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Delete contract', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: _pickStart,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Contract starts'),
              subtitle: Text(prettyDateLong(_start)),
              trailing: const Icon(Icons.edit_calendar_outlined),
            ),
          ),
          const SizedBox(height: 24),
          Text('Contract length', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1 year')),
              ButtonSegment(value: 2, label: Text('2 years')),
              ButtonSegment(value: 3, label: Text('3 years')),
            ],
            selected: {_years},
            onSelectionChanged: (s) => setState(() {
              _years = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Ends ${prettyDate(end)}. '
            '${_years == 1 ? 'Unused leave is lost when it ends.' : 'Unused leave carries from one year to the next, up to the limit below.'}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _daysPerYear,
            keyboardType: numeric,
            decoration: const InputDecoration(
              labelText: 'Leave days per year',
              border: OutlineInputBorder(),
            ),
          ),
          if (_years > 1) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _carryMax,
              keyboardType: numeric,
              decoration: const InputDecoration(
                labelText: 'Carry-over limit (days)',
                helperText: 'Most unused days that move into the next contract year',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _broughtForward,
            keyboardType: numeric,
            decoration: const InputDecoration(
              labelText: 'Days brought forward',
              helperText: 'Extra days carried in from before this contract. Usually 0.',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(_editing ? 'Save changes' : 'Save contract'),
          ),
        ],
      ),
    );
  }
}

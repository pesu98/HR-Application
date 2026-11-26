import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';
import 'leave_calculator.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'update_widgets.dart';

/// Contract: the contract being viewed, its year-by-year summary, other
/// contracts, backup and app updates.
class ContractTab extends StatelessWidget {
  const ContractTab({super.key, required this.view});

  final LeaveView view;

  LeaveStore get _store => view.store;

  Future<void> _copyBackup(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _store.exportJson()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Backup copied. Paste it into a note or message to yourself.')));
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
              decoration: const InputDecoration(hintText: 'Paste backup text'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  controller.text = clip?.text ?? '';
                },
                icon: const Icon(Icons.content_paste, size: 16),
                label: const Text('Paste from clipboard'),
              ),
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
    final error = await _store.importJson(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Backup restored.')));
  }

  @override
  Widget build(BuildContext context) {
    final a = view.selected;
    final contract = view.contract;
    final others = [
      for (final c in _store.contracts.reversed)
        if (c.id != contract?.id) c,
    ];

    return ListView(
      padding: tabPadding,
      children: [
        const PageHead('EMPLOYMENT', 'My contract', 'Manage your entitlement and contract period.'),
        if (a == null || contract == null)
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No contract yet.', style: subStyle),
                const SizedBox(height: 12),
                PrimaryButton(icon: Icons.add, label: 'Add contract', onPressed: () => view.openContract()),
              ],
            ),
          )
        else ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Bubble(Icons.description_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contractTitle(contract),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text('${prettyDate(contract.start)} – ${prettyDate(contractEnd(contract))}', style: subStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                YearTrack(years: view.contractYears, selected: a, onSelect: view.selectYear),
                const SizedBox(height: 14),
                _Detail('Annual entitlement', '${formatDays(contract.daysPerYear)} days'),
                _Detail('Carry-forward limit', '${formatDays(contract.carryMax)} days'),
                if (contract.broughtForward > 0)
                  _Detail('Brought forward', '${formatDays(contract.broughtForward)} days'),
                const SizedBox(height: 12),
                PrimaryButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit contract',
                  onPressed: () => view.openContract(contract: contract),
                ),
              ],
            ),
          ),
          const NoticeBox(
            child: Text(
              'Carried-forward days are used first, expire at the end of the next contract year and cannot be '
              'carried again. Only unused current-year entitlement can transfer, up to the limit. Left-over '
              'months at the end of a contract get prorated leave. Nothing transfers at the end of the contract.',
            ),
          ),
          const SectionTitle('Year-by-year summary'),
          for (final y in view.contractYears)
            SoftCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(periodLabel(y.year), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${prettyDate(y.year.start)} – ${prettyDate(y.year.end)}',
                          style: subStyle,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _Detail(
                    y.year.isPartial ? 'Prorated + carried in' : 'Annual + carried in',
                    '${formatDays(y.entitlement)} + ${formatDays(y.carriedIn)}',
                  ),
                  _Detail('Carry used first', formatDays(y.carryUsed)),
                  _Detail('Current-year used', formatDays(y.baseUsed)),
                  _Detail('Remaining', formatDays(y.remaining)),
                  _Detail('Eligible next year', formatDays(y.carryOut), accent: true),
                  _Detail('Unused days expiring', formatDays(y.forfeit), last: true),
                ],
              ),
            ),
        ],
        if (others.isNotEmpty) ...[
          const SectionTitle('Other contracts'),
          for (final c in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: const BorderSide(color: AppColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () {
                    final first = view.all.firstWhere((s) => s.year.contractId == c.id);
                    view.selectYear(first);
                  },
                  title: Text(
                    '${prettyDate(c.start)} – ${prettyDate(contractEnd(c))}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${contractLength(c)} · ${formatDays(c.daysPerYear)} days a year', style: subStyle),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                ),
              ),
            ),
        ],
        if (contract != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => view.openContract(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a new contract (renewal)'),
            ),
          ),
        const SizedBox(height: 6),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Local data',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.35),
              ),
              const SizedBox(height: 8),
              const Text(
                'Records are kept only on this phone. Copy a backup now and then, so you can restore them on a new phone.',
                style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.55),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copyBackup(context),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _restore(context),
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Restore'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (view.updates != null) SoftCard(child: UpdateSection(updates: view.updates!)),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value, {this.accent = false, this.last = false});

  final String label;
  final String value;
  final bool accent;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: subStyle)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent ? AppColors.accent : AppColors.ink,
            ),
          ),
        ],
      ),
    );
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
  late int _months;
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
    _start =
        c?.start ??
        (existing.isEmpty
            // Contracts start on 1 March; suggest the most recent one.
            ? latestAnniversary(_store.today, DateTime.march, 1)
            : contractEnd(existing.last).add(const Duration(days: 1)));
    _years = c?.years ?? 1;
    _months = c?.months ?? 0;
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
    final error = await _store.saveContract(
      Contract(
        id: widget.contract?.id ?? newId(),
        start: _start,
        years: _years,
        months: _months,
        daysPerYear: daysPerYear,
        carryMax: carryMax,
        broughtForward: broughtForward,
      ),
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
    final contract = widget.contract!;
    final count = _store.leavesIn(contract).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this contract?'),
        content: Text(
          count == 0
              ? 'No leave is recorded in this contract.'
              : 'The $count leave ${count == 1 ? 'record' : 'records'} in this contract will be deleted too. '
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

  /// What the chosen length means, e.g. the end date and the prorated days.
  String _lengthSummary() {
    final total = _years * 12 + _months;
    if (total < 1) return 'Choose at least 1 month.';
    final end = addMonths(_start, total).subtract(const Duration(days: 1));
    final perYear = _number(_daysPerYear) ?? 25;
    final parts = ['Ends ${prettyDate(end)}.'];
    if (_months > 0) {
      parts.add(
        'The ${_years > 0 ? 'last ' : ''}$_months ${_months == 1 ? 'month gets' : 'months get'} '
        '${daysLabel(proratedEntitlement(perYear, _months))} (prorated from ${formatDays(perYear)}).',
      );
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    const numeric = TextInputType.numberWithOptions(decimal: true);
    final multiPeriod = _years * 12 + _months > 12;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: tabPadding,
        children: [
          PageHead(
            'EMPLOYMENT',
            _editing ? 'Edit contract' : 'Add contract',
            'Each contract year is its own leave year.',
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Contract start date'),
                DateField(date: _start, onTap: _pickStart),
                const SizedBox(height: 16),
                const FieldLabel('Contract duration'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('contract-years'),
                        value: _years,
                        isExpanded: true,
                        items: [
                          for (var n = 0; n <= 5; n++)
                            DropdownMenuItem(value: n, child: Text('$n ${n == 1 ? 'year' : 'years'}')),
                        ],
                        onChanged: (v) => setState(() {
                          _years = v ?? _years;
                          _error = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('contract-months'),
                        value: _months,
                        isExpanded: true,
                        items: [
                          for (var n = 0; n <= 11; n++)
                            DropdownMenuItem(value: n, child: Text('$n ${n == 1 ? 'month' : 'months'}')),
                        ],
                        onChanged: (v) => setState(() {
                          _months = v ?? _months;
                          _error = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_lengthSummary(), key: const ValueKey('length-summary'), style: subStyle),
                const SizedBox(height: 16),
                const FieldLabel('Annual entitlement (days)'),
                TextField(controller: _daysPerYear, keyboardType: numeric, onChanged: (_) => setState(() {})),
                if (multiPeriod) ...[
                  const SizedBox(height: 16),
                  const FieldLabel('Carry-forward limit (days)'),
                  TextField(controller: _carryMax, keyboardType: numeric),
                ],
                const SizedBox(height: 16),
                const FieldLabel('Days brought forward'),
                TextField(controller: _broughtForward, keyboardType: numeric),
                const SizedBox(height: 6),
                const Text('Extra days carried in from before this contract. Usually 0.', style: subStyle),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          PrimaryButton(label: _editing ? 'Save contract' : 'Add contract', onPressed: _saving ? null : _save),
          if (_editing) ...[const SizedBox(height: 12), DangerButton(label: 'Delete contract', onPressed: _delete)],
        ],
      ),
    );
  }
}

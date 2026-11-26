import 'package:flutter/material.dart';

import 'contracts_page.dart';
import 'leave_calculator.dart';
import 'leave_form_page.dart';
import 'models.dart';
import 'store.dart';

/// The main screen: how many days are left in a leave year, and the leave
/// recorded in it.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final LeaveStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Key of the leave year the user switched to; null follows today.
  String? _selectedKey;

  LeaveStore get _store => widget.store;

  int _selectedIndex(List<YearSummary> summaries, DateTime today) {
    final chosen = summaries.indexWhere((s) => s.year.key == _selectedKey);
    if (chosen >= 0) return chosen;
    final current = summaries.indexWhere((s) => s.isCurrent);
    if (current >= 0) return current;
    final started = summaries.lastIndexWhere((s) => !s.year.start.isAfter(today));
    return started >= 0 ? started : 0;
  }

  Future<void> _openContracts() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ContractsPage(store: _store)),
      );

  Future<void> _addContract() => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ContractFormPage(store: _store),
        ),
      );

  Future<void> _editLeave(Leave? leave, YearSummary summary) {
    final today = _store.today;
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LeaveFormPage(
          store: _store,
          leave: leave,
          initialDate: summary.year.contains(today) ? today : summary.year.start,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final today = _store.today;
        final summaries = summarize(_store.contracts, _store.leaves, today);
        final index = summaries.isEmpty ? -1 : _selectedIndex(summaries, today);
        final selected = index < 0 ? null : summaries[index];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Annual Leave'),
            actions: [
              IconButton(
                tooltip: 'Contracts and backup',
                icon: const Icon(Icons.settings_outlined),
                onPressed: _openContracts,
              ),
            ],
          ),
          floatingActionButton: selected == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _editLeave(null, selected),
                  icon: const Icon(Icons.add),
                  label: const Text('Add leave'),
                ),
          body: selected == null
              ? _Welcome(onSetUp: _addContract)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    _YearSwitcher(
                      summary: selected,
                      onPrevious: index > 0
                          ? () => setState(() => _selectedKey = summaries[index - 1].year.key)
                          : null,
                      onNext: index < summaries.length - 1
                          ? () => setState(() => _selectedKey = summaries[index + 1].year.key)
                          : null,
                    ),
                    if (!summaries.any((s) => s.isCurrent)) ...[
                      const SizedBox(height: 8),
                      _NoContractBanner(today: today, onAdd: _addContract),
                    ],
                    const SizedBox(height: 8),
                    _BalanceCard(summary: selected, today: today),
                    const SizedBox(height: 12),
                    _YearNotice(summary: selected, today: today),
                    const SizedBox(height: 20),
                    ..._leaveSections(context, selected, today),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _leaveSections(BuildContext context, YearSummary summary, DateTime today) {
    final planned = [
      for (final l in summary.leaves)
        if (l.start.isAfter(today)) l,
    ];
    final taken = [
      for (final l in summary.leaves.reversed)
        if (!l.start.isAfter(today)) l,
    ];

    if (planned.isEmpty && taken.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No leave recorded in this leave year yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ];
    }

    return [
      if (planned.isNotEmpty) ...[
        _SectionTitle('Planned', daysLabel(summary.upcoming)),
        for (final l in planned) _LeaveTile(leave: l, onTap: () => _editLeave(l, summary)),
        const SizedBox(height: 12),
      ],
      if (taken.isNotEmpty) ...[
        _SectionTitle('Taken', daysLabel(summary.taken)),
        for (final l in taken) _LeaveTile(leave: l, onTap: () => _editLeave(l, summary)),
      ],
    ];
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSetUp});

  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Set up your contract', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Tell the app when your contract starts and how long it runs. '
              'It will then keep count of your leave for each contract year.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSetUp,
              icon: const Icon(Icons.add),
              label: const Text('Add contract'),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearSwitcher extends StatelessWidget {
  const _YearSwitcher({required this.summary, required this.onPrevious, required this.onNext});

  final YearSummary summary;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = summary.year;
    final position = year.count == 1 ? '1-year contract' : 'Year ${year.index} of ${year.count}';
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous leave year',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${prettyDate(year.start)} – ${prettyDate(year.end)}',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                summary.isCurrent ? '$position · current' : position,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Next leave year',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _NoContractBanner extends StatelessWidget {
  const _NoContractBanner({required this.today, required this.onAdd});

  final DateTime today;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'No contract covers today (${prettyDate(today)}). Add your current contract to keep counting.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.today});

  final YearSummary summary;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = summary.remaining;
    final over = remaining < 0;
    final ended = summary.year.end.isBefore(today);
    final shown = over ? -remaining : remaining;
    final unit = shown == 1 ? 'day' : 'days';
    final label = over
        ? '$unit over your entitlement'
        : ended
            ? '$unit unused'
            : '$unit left';
    final foreground = over ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    final progress = summary.total <= 0 ? 0.0 : (summary.used / summary.total).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: over ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatDays(shown),
                  key: const ValueKey('days-left'),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(label, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: over ? scheme.error : scheme.primary,
                backgroundColor: foreground.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${formatDays(summary.used)} of ${formatDays(summary.total)} days used',
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat('Yearly', summary.entitlement, foreground),
                _Stat('Carried in', summary.carriedIn, foreground),
                _Stat('Taken', summary.taken, foreground),
                _Stat('Planned', summary.upcoming, foreground),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDays(value),
            style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// What happens to the unused days of [s] when its leave year ends.
/// Returns the lines to show and whether they are a warning.
({List<String> lines, bool warning}) yearNotice(YearSummary s, DateTime today) {
  final end = prettyDate(s.year.end);
  final left = s.remaining > 0 ? s.remaining : 0.0;

  if (s.year.start.isAfter(today)) {
    return (
      lines: [
        'This leave year starts on ${prettyDate(s.year.start)}.',
        if (s.carriedIn > 0)
          '${daysLabel(s.carriedIn)} are expected to carry in from the year before, if you do not use them first.',
      ],
      warning: false,
    );
  }

  if (s.year.end.isBefore(today)) {
    return (
      lines: [
        if (s.carryOut > 0) '${daysLabel(s.carryOut)} carried over to the next year.',
        if (s.forfeit > 0)
          s.year.isFinal
              ? '${daysLabel(s.forfeit)} unused when the contract ended on $end.'
              : '${daysLabel(s.forfeit)} lost — over the ${formatDays(s.carryMax)}-day carry-over limit.',
        if (s.carryOut == 0 && s.forfeit == 0) 'This leave year ended on $end with no unused days.',
      ],
      warning: false,
    );
  }

  final toEnd = s.daysToEnd ?? 0;
  final countdown = toEnd == 0
      ? 'This leave year ends today.'
      : '$toEnd ${toEnd == 1 ? 'day' : 'days'} until this leave year ends on $end.';

  if (left == 0) {
    return (lines: [countdown, 'You have no unused days to lose.'], warning: false);
  }
  if (s.year.isFinal) {
    return (
      lines: [
        countdown,
        'This is the last year of your contract, so nothing carries over. '
            'Use your ${daysLabel(left)} before then or lose them.',
      ],
      warning: true,
    );
  }
  if (s.forfeit > 0) {
    return (
      lines: [
        countdown,
        s.carryMax > 0
            ? 'Only ${daysLabel(s.carryMax)} can carry over to next year. '
                'Use ${formatDays(s.forfeit)} more before then or lose them.'
            : 'Nothing carries over to next year. Use your ${daysLabel(left)} before then or lose them.',
      ],
      warning: true,
    );
  }
  return (
    lines: [countdown, 'All ${daysLabel(left)} you have left can carry over to next year.'],
    warning: false,
  );
}

class _YearNotice extends StatelessWidget {
  const _YearNotice({required this.summary, required this.today});

  final YearSummary summary;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notice = yearNotice(summary, today);
    final background = notice.warning ? scheme.tertiaryContainer : scheme.surfaceContainerHighest;
    final foreground = notice.warning ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(notice.warning ? Icons.hourglass_bottom : Icons.info_outline, color: foreground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, line) in notice.lines.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                      child: Text(line, style: TextStyle(color: foreground)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.trailing);

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
          Text(trailing, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  const _LeaveTile({required this.leave, required this.onTap});

  final Leave leave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(leave.start == leave.end ? prettyDateLong(leave.start) : prettyRange(leave.start, leave.end)),
        subtitle: leave.note.isEmpty ? null : Text(leave.note, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(daysLabel(leave.days), style: theme.textTheme.titleSmall),
      ),
    );
  }
}

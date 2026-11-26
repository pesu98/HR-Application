import 'package:flutter/material.dart';

import 'contracts_page.dart';
import 'leave_calculator.dart';
import 'leave_form_page.dart';
import 'models.dart';
import 'records_tabs.dart';
import 'store.dart';
import 'theme.dart';
import 'update_widgets.dart';
import 'updater.dart';

/// Everything a tab needs: the data, the leave period being viewed, and how
/// to move around.
class LeaveView {
  const LeaveView({
    required this.store,
    required this.updates,
    required this.today,
    required this.all,
    required this.selected,
    required this.contractYears,
    required this.selectYear,
    required this.openLeave,
    required this.openContract,
    required this.goTab,
  });

  final LeaveStore store;
  final UpdateController? updates;
  final DateTime today;

  /// Every leave period of every contract, oldest first.
  final List<YearSummary> all;

  /// The period being viewed; null until a contract exists.
  final YearSummary? selected;

  /// The periods of the contract that [selected] belongs to.
  final List<YearSummary> contractYears;

  final ValueChanged<YearSummary> selectYear;

  /// Opens the form to record a leave, or to edit [leave].
  final void Function({Leave? leave, DateTime? date}) openLeave;

  /// Opens the form to add a contract, or to edit [contract].
  final void Function({Contract? contract}) openContract;
  final ValueChanged<int> goTab;

  Contract? get contract {
    final id = selected?.year.contractId;
    for (final c in store.contracts) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// The app shell: brand header, four tabs and the bottom navigation.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store, this.updates});

  final LeaveStore store;

  /// Null where in-app updates are not supported.
  final UpdateController? updates;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const tabOverview = 0;
  static const tabCalendar = 1;
  static const tabHistory = 2;
  static const tabContract = 3;

  int _tab = tabOverview;

  /// Key of the leave period the user switched to; null follows today.
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

  void _openContract({Contract? contract}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ContractFormPage(store: _store, contract: contract),
      ),
    );
  }

  void _openLeave(YearSummary? selected, {Leave? leave, DateTime? date}) {
    if (selected == null) return;
    final today = _store.today;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LeaveFormPage(
          store: _store,
          leave: leave,
          initialDate: date ?? (selected.year.contains(today) ? today : selected.year.start),
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
        final all = summarize(_store.contracts, _store.leaves, today);
        final selected = all.isEmpty ? null : all[_selectedIndex(all, today)];
        final view = LeaveView(
          store: _store,
          updates: widget.updates,
          today: today,
          all: all,
          selected: selected,
          contractYears: [
            for (final s in all)
              if (s.year.contractId == selected?.year.contractId) s,
          ],
          selectYear: (s) => setState(() => _selectedKey = s.year.key),
          openLeave: ({leave, date}) {
            // Recording from the calendar follows the tapped day's period.
            if (leave == null && date != null) {
              final period = findYear(_store.contracts, date);
              if (period != null) setState(() => _selectedKey = period.key);
            }
            _openLeave(selected, leave: leave, date: date);
          },
          openContract: _openContract,
          goTab: (i) => setState(() => _tab = i),
        );

        final Widget body = switch (_tab) {
          tabCalendar => CalendarTab(view: view),
          tabHistory => HistoryTab(view: view),
          tabContract => ContractTab(view: view),
          _ => OverviewTab(view: view),
        };

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _BrandHeader(),
                Expanded(
                  child: KeyedSubtree(key: ValueKey(_tab), child: body),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(index: _tab, onTap: (i) => setState(() => _tab = i)),
        );
      },
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'myLeave',
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: AppColors.accent),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
            SizedBox(height: 2),
            Text(
              'PERSONAL HR ASSISTANT',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.7, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, 'Overview'),
    (Icons.calendar_month_outlined, 'Calendar'),
    (Icons.history, 'History'),
    (Icons.description_outlined, 'Contract'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
          child: Row(
            children: [
              for (final (i, item) in _items.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    child: InkWell(
                      onTap: () => onTap(i),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 46,
                            height: 31,
                            decoration: BoxDecoration(
                              color: i == index ? AppColors.soft : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.$1, size: 20, color: i == index ? AppColors.accent : AppColors.muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 10,
                              color: i == index ? AppColors.accent : AppColors.muted,
                              fontWeight: i == index ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Padding shared by every tab's scrolling content.
const tabPadding = EdgeInsets.fromLTRB(24, 0, 24, 24);

/// Overview: the balance, where it comes from, and the latest leave.
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.view});

  final LeaveView view;

  @override
  Widget build(BuildContext context) {
    final a = view.selected;
    if (a == null) return _Welcome(view: view);

    final today = view.today;
    final notice = yearNotice(a, today);
    final recent = a.leaves.reversed.take(3).toList();
    final contract = view.contract;

    return ListView(
      padding: tabPadding,
      children: [
        PageHead('PERSONAL HR', 'Leave overview', '${prettyDate(a.year.start)} – ${prettyDate(a.year.end)}'),
        if (view.updates != null) UpdateBanner(updates: view.updates!, margin: const EdgeInsets.only(bottom: 12)),
        if (!view.all.any((s) => s.isCurrent))
          NoticeBox(
            warn: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'No contract covers today (${prettyDate(today)}). Add your current contract to keep counting.',
                  ),
                ),
                TextButton(onPressed: () => view.openContract(), child: const Text('Add')),
              ],
            ),
          ),
        _Hero(summary: a, today: today),
        const SizedBox(height: 12),
        NoticeBox(
          warn: notice.warning,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 8),
                child: Icon(notice.warning ? Icons.hourglass_bottom : Icons.info_outline, size: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final line in notice.lines) Text(line)],
                ),
              ),
            ],
          ),
        ),
        PrimaryButton(icon: Icons.add, label: 'Record new leave', onPressed: () => view.openLeave()),
        const SectionTitle('Leave breakdown'),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bucket(
                icon: Icons.schedule,
                amber: true,
                title: 'Carried-forward leave',
                subtitle: a.carriedIn > 0
                    ? 'Used first · Expires ${shortDate(a.year.end)}'
                    : 'Nothing carried into this period',
                left: a.carryLeft,
                total: a.carriedIn,
              ),
              const SizedBox(height: 16),
              _Bucket(
                icon: Icons.eco_outlined,
                title: a.year.isPartial ? 'Prorated leave' : 'Current-year leave',
                subtitle: a.year.isPartial
                    ? '${a.year.months} of 12 months of ${formatDays(contract?.daysPerYear ?? a.entitlement)} days'
                    : 'Annual entitlement',
                left: a.baseLeft,
                total: a.entitlement,
              ),
              const SizedBox(height: 12),
              const Text(
                'Carried-forward days are deducted first and cannot be carried again.',
                style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.55),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _Mini(
                label: 'Upcoming leave',
                value: daysLabel(a.upcoming),
                caption: 'Booked ahead',
                color: AppColors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Mini(
                label: 'Eligible carry forward',
                value: daysLabel(a.carryOut),
                caption: a.year.isFinal ? 'Final contract period' : 'To next contract year',
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        SectionTitle('My contract', action: 'Manage', onAction: () => view.goTab(3)),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contract == null ? 'Contract' : contractTitle(contract),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    a.year.isPartial ? periodLabel(a.year) : 'Year ${a.year.index} of ${a.year.count}',
                    style: subStyle,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              YearTrack(years: view.contractYears, selected: a, onSelect: view.selectYear),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Expanded(child: Text('Unused days expiring at period end', style: subStyle)),
                  Text(daysLabel(a.forfeit), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        SectionTitle('Recent leave', action: 'View all', onAction: () => view.goTab(2)),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Text('No leave recorded for this period.', textAlign: TextAlign.center, style: subStyle),
          ),
        for (final l in recent)
          LeaveRecordTile(
            leave: l,
            upcoming: l.start.isAfter(today),
            onTap: () => view.openLeave(leave: l),
          ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.view});

  final LeaveView view;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: tabPadding,
      children: [
        const PageHead(
          'PERSONAL HR',
          'Set up your contract',
          'Tell myLeave when your contract starts and how long it runs.',
        ),
        if (view.updates != null) UpdateBanner(updates: view.updates!, margin: const EdgeInsets.only(bottom: 12)),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Bubble(Icons.event_available),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your leave is counted per contract year, with carry-forward and prorated months worked out for you.',
                      style: subStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(icon: Icons.add, label: 'Add contract', onPressed: () => view.openContract()),
            ],
          ),
        ),
        Center(
          child: TextButton(onPressed: () => view.goTab(3), child: const Text('Have a backup? Restore it in Contract')),
        ),
      ],
    );
  }
}

/// The dark gradient card with the big balance.
class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.today});

  final YearSummary summary;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final a = summary;
    final over = a.remaining < 0;
    final pct = a.total > 0 ? (a.remaining / a.total).clamp(0.0, 1.0) : 0.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment(-1, -0.6),
          end: Alignment(1, 0.6),
          colors: [Color(0xFF24233E), Color(0xFF44366D), Color(0xFF604A94)],
          stops: [0, 0.75, 1],
        ),
        boxShadow: const [BoxShadow(color: Color(0x253E306B), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Stack(
        children: [
          for (final size in [235.0, 290.0])
            Positioned(
              right: -size * 0.476,
              top: -size * 0.54,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        over ? 'Annual leave overdrawn' : 'Available annual leave',
                        style: const TextStyle(color: AppColors.heroText, fontSize: 12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x35FFFFFF)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${a.year.isPartial ? 'PERIOD' : 'YEAR'} ${a.year.index} / ${a.year.count}',
                        style: const TextStyle(color: Color(0xFFE4DAFA), fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  formatDays(a.remaining),
                                  key: const ValueKey('days-left'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 67,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -4,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  a.remaining == 1 ? 'day' : 'days',
                                  style: const TextStyle(color: AppColors.heroText, fontSize: 19),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'of ${formatDays(a.total)} days entitlement',
                            style: const TextStyle(color: AppColors.heroText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: CircularProgressIndicator(
                              value: pct,
                              strokeWidth: 7,
                              strokeCap: StrokeCap.round,
                              color: const Color(0xFFC4B1FF),
                              backgroundColor: const Color(0x24FFFFFF),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(pct * 100).round()}%',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                              const Text('remaining', style: TextStyle(color: AppColors.heroText, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(height: 1, color: const Color(0x26FFFFFF)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _HeroStat(formatDays(a.entitlement), a.year.isPartial ? 'Prorated' : 'Annual'),
                    _HeroStat(formatDays(a.carriedIn), 'Carried in', divider: true, tint: true),
                    _HeroStat(formatDays(a.used), 'Used', divider: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.value, this.label, {this.divider = false, this.tint = false});

  final String value;
  final String label;
  final bool divider;
  final bool tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(left: divider ? 12 : 0),
        decoration: BoxDecoration(
          border: divider ? const Border(left: BorderSide(color: Color(0x25FFFFFF))) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: tint ? const Color(0xFFD8C4FF) : Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(color: AppColors.heroText, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _Bucket extends StatelessWidget {
  const _Bucket({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.left,
    required this.total,
    this.amber = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double left;
  final double total;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Bubble(icon, amber: amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: subStyle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                text: formatDays(left),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                children: [TextSpan(text: ' / ${formatDays(total)}', style: subStyle)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        BarLine(left: left, total: total, amber: amber),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.caption, required this.color});

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.7, color: color),
            ),
          ),
          Text(caption, style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// What happens to the unused days of [s] when its period ends.
/// Returns the lines to show and whether they are a warning.
({List<String> lines, bool warning}) yearNotice(YearSummary s, DateTime today) {
  final end = prettyDate(s.year.end);
  final left = s.remaining > 0 ? s.remaining : 0.0;

  if (s.year.start.isAfter(today)) {
    return (
      lines: [
        'This period starts on ${prettyDate(s.year.start)}.',
        if (s.carriedIn > 0)
          '${daysLabel(s.carriedIn)} are expected to carry in from the year before, if you do not use them first.',
      ],
      warning: false,
    );
  }

  if (s.year.end.isBefore(today)) {
    return (
      lines: [
        if (s.carryOut > 0) '${daysLabel(s.carryOut)} carried forward to the next period.',
        if (s.forfeit > 0)
          s.year.isFinal
              ? '${daysLabel(s.forfeit)} unused when the contract ended on $end.'
              : '${daysLabel(s.forfeit)} expired unused on $end.',
        if (s.carryOut == 0 && s.forfeit == 0) 'This period ended on $end with no unused days.',
      ],
      warning: false,
    );
  }

  final toEnd = s.daysToEnd ?? 0;
  final countdown = toEnd == 0
      ? 'This period ends today.'
      : '$toEnd ${toEnd == 1 ? 'day' : 'days'} until this period ends on $end.';

  if (left == 0) {
    return (lines: [countdown, 'You have no unused days to lose.'], warning: false);
  }
  if (s.year.isFinal) {
    return (
      lines: [
        countdown,
        'This is the last period of your contract, so nothing carries forward. '
            'Use your ${daysLabel(left)} before then or lose them.',
      ],
      warning: true,
    );
  }
  if (s.forfeit > 0) {
    final String rule;
    if (s.carryMax <= 0) {
      rule = 'Nothing carries forward.';
    } else if (s.carryLeft > 0) {
      rule = 'Carried-in days expire, and only ${daysLabel(s.carryMax)} of this year\'s leave can carry forward.';
    } else {
      rule = 'Only ${daysLabel(s.carryMax)} can carry forward.';
    }
    return (lines: [countdown, '$rule Use ${formatDays(s.forfeit)} more before then or lose them.'], warning: true);
  }
  return (lines: [countdown, 'All ${daysLabel(left)} you have left can carry forward.'], warning: false);
}

import 'package:flutter/material.dart';

import 'home_page.dart';
import 'leave_calculator.dart';
import 'models.dart';
import 'theme.dart';

/// Shown by a tab when no contract exists yet.
class NoContractYet extends StatelessWidget {
  const NoContractYet({super.key, required this.view, required this.eyebrow, required this.title});

  final LeaveView view;
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: tabPadding,
      children: [
        PageHead(eyebrow, title, 'Add your contract first.'),
        PrimaryButton(icon: Icons.add, label: 'Add contract', onPressed: () => view.openContract()),
      ],
    );
  }
}

/// History: every leave recorded in the period being viewed.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, required this.view});

  final LeaveView view;

  @override
  Widget build(BuildContext context) {
    final a = view.selected;
    if (a == null) return NoContractYet(view: view, eyebrow: 'LEAVE RECORDS', title: 'My leave history');

    final records = a.leaves.reversed.toList();
    return ListView(
      padding: tabPadding,
      children: [
        PageHead(
          'LEAVE RECORDS',
          'My leave history',
          '${periodLabel(a.year)} · ${prettyDate(a.year.start)} – ${prettyDate(a.year.end)}',
        ),
        SoftCard(
          child: YearTrack(years: view.contractYears, selected: a, onSelect: view.selectYear),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              Expanded(child: Text('${records.length} ${records.length == 1 ? 'record' : 'records'}', style: subStyle)),
              Text('${daysLabel(a.used)} used', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Text('No leave recorded for this period.', textAlign: TextAlign.center, style: subStyle),
          ),
        for (final l in records)
          LeaveRecordTile(
            leave: l,
            upcoming: l.start.isAfter(view.today),
            onTap: () => view.openLeave(leave: l),
          ),
        const SizedBox(height: 8),
        PrimaryButton(icon: Icons.add, label: 'Record leave', onPressed: () => view.openLeave()),
      ],
    );
  }
}

/// Calendar: a month grid with a dot on every leave day.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.view});

  final LeaveView view;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _selected = widget.view.today;
  late DateTime _month = DateTime.utc(_selected.year, _selected.month);

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime.utc(_month.year, _month.month + delta);
      _selected = _month;
    });
  }

  List<Leave> _leavesOn(DateTime day) => [
    for (final l in widget.view.store.leaves)
      if (!l.start.isAfter(day) && !l.end.isBefore(day)) l,
  ];

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    if (view.selected == null) return NoContractYet(view: view, eyebrow: 'YOUR SCHEDULE', title: 'Leave calendar');

    final daysInMonth = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final leading = _month.weekday - 1; // Monday first
    final onSelected = _leavesOn(_selected);
    final covered = findYear(view.store.contracts, _selected) != null;

    return ListView(
      padding: tabPadding,
      children: [
        const PageHead('YOUR SCHEDULE', 'Leave calendar', 'Make room for life outside work.'),
        SoftCard(
          child: Column(
            children: [
              Row(
                children: [
                  _RoundIconButton(icon: Icons.chevron_left, tooltip: 'Previous month', onTap: () => _moveMonth(-1)),
                  Expanded(
                    child: Text(
                      '${monthNamesLong[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.35),
                    ),
                  ),
                  _RoundIconButton(icon: Icons.chevron_right, tooltip: 'Next month', onTap: () => _moveMonth(1)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Text(d, textAlign: TextAlign.center, style: subStyle),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                  for (var day = 1; day <= daysInMonth; day++)
                    _DayCell(
                      day: day,
                      selected: DateTime.utc(_month.year, _month.month, day) == _selected,
                      isToday: DateTime.utc(_month.year, _month.month, day) == view.today,
                      hasLeave: _leavesOn(DateTime.utc(_month.year, _month.month, day)).isNotEmpty,
                      onTap: () => setState(() => _selected = DateTime.utc(_month.year, _month.month, day)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '● ',
                        style: TextStyle(color: AppColors.green),
                      ),
                      TextSpan(text: 'Annual leave'),
                    ],
                  ),
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        SectionTitle(prettyDateLong(_selected)),
        if (onSelected.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Text('No leave recorded for this date.', textAlign: TextAlign.center, style: subStyle),
          ),
        for (final l in onSelected)
          LeaveRecordTile(
            leave: l,
            upcoming: l.start.isAfter(view.today),
            onTap: () => view.openLeave(leave: l),
          ),
        const SizedBox(height: 8),
        if (covered && onSelected.isEmpty)
          PrimaryButton(
            icon: Icons.add,
            label: 'Record leave',
            onPressed: () => view.openLeave(date: _selected),
          ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 43, height: 43, child: Icon(icon, size: 20, color: AppColors.ink)),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.hasLeave,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool isToday;
  final bool hasLeave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: isToday && !selected ? const BorderSide(color: AppColors.line) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
            if (hasLeave)
              Positioned(
                bottom: 5,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : const Color(0xFF36A687),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

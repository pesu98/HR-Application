import 'package:flutter/material.dart';

import 'leave_calculator.dart';
import 'models.dart';

/// The myLeave palette.
abstract final class AppColors {
  static const bg = Color(0xFFF6F5FA);
  static const ink = Color(0xFF25243A);
  static const muted = Color(0xFF77758A);
  static const accent = Color(0xFF7358D3);
  static const soft = Color(0xFFEDE8FC);
  static const line = Color(0xFFE9E6F0);
  static const field = Color(0xFFF8F7FB);
  static const green = Color(0xFF187E66);
  static const amber = Color(0xFF94600D);
  static const amberSoft = Color(0xFFFFF2D9);
  static const danger = Color(0xFFA33C50);
  static const heroText = Color(0xFFD9CFEE);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    error: AppColors.danger,
  );
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
  final base = ThemeData(colorScheme: scheme, scaffoldBackgroundColor: AppColors.bg);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(const Color(0xFFB5A4EE), 2),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  );
}

const subStyle = TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5);

/// Eyebrow, big title and subtitle at the top of a screen.
class PageHead extends StatelessWidget {
  const PageHead(this.eyebrow, this.title, this.subtitle, {super.key});

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1.1, height: 1.16),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: subStyle),
        ],
      ),
    );
  }
}

/// White rounded card with a hairline border.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Section heading with an optional link on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.35)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(action!), const Icon(Icons.chevron_right, size: 18)],
              ),
            )
          else
            const SizedBox(height: 36),
        ],
      ),
    );
  }
}

/// The full-width purple action button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Rounded square holding an icon.
class Bubble extends StatelessWidget {
  const Bubble(this.icon, {super.key, this.amber = false});

  final IconData icon;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: amber ? AppColors.amberSoft : AppColors.soft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 20, color: amber ? AppColors.amber : AppColors.accent),
    );
  }
}

/// Thin progress bar: [left] out of [total].
class BarLine extends StatelessWidget {
  const BarLine({super.key, required this.left, required this.total, this.amber = false});

  final double left;
  final double total;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final value = total > 0 ? (left / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: const Color(0xFFEFEDF4),
        color: amber ? const Color(0xFFE5B56A) : const Color(0xFF9B85E6),
      ),
    );
  }
}

/// Tinted information box.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.child, this.warn = false});

  final Widget child;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warn ? AppColors.amberSoft : AppColors.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 12, height: 1.6, color: warn ? const Color(0xFF855A15) : const Color(0xFF665394)),
        child: child,
      ),
    );
  }
}

/// The contract's periods as tappable segments: "Year 1", "Year 2", "3 mo".
class YearTrack extends StatelessWidget {
  const YearTrack({super.key, required this.years, required this.selected, required this.onSelect});

  /// The periods of one contract, in order.
  final List<YearSummary> years;
  final YearSummary selected;
  final ValueChanged<YearSummary> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, y) in years.indexed) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: Semantics(
              button: true,
              selected: y.year.key == selected.year.key,
              child: InkWell(
                onTap: () => onSelect(y),
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: y.year.key == selected.year.key
                              ? AppColors.accent
                              : y.year.index < selected.year.index
                              ? const Color(0xFFB9A9EC)
                              : const Color(0xFFEBE8F0),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        periodLabel(y.year),
                        style: TextStyle(
                          fontSize: 10,
                          color: y.year.key == selected.year.key ? AppColors.accent : AppColors.muted,
                          fontWeight: y.year.key == selected.year.key ? FontWeight.w800 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// `Year 2`, or `Last 3 months` for a prorated final period.
String periodLabel(LeaveYear y) {
  if (!y.isPartial) return 'Year ${y.index}';
  final unit = y.months == 1 ? 'month' : 'months';
  return y.count == 1 ? '${y.months} $unit' : 'Last ${y.months} $unit';
}

/// One recorded leave in a list.
class LeaveRecordTile extends StatelessWidget {
  const LeaveRecordTile({super.key, required this.leave, required this.onTap, this.upcoming = false});

  final Leave leave;
  final VoidCallback onTap;

  /// True when the leave is still in the future.
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Bubble(upcoming ? Icons.schedule : Icons.description_outlined, amber: upcoming),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prettyRange(leave.start, leave.end),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leave.note.isEmpty ? (upcoming ? 'Upcoming annual leave' : 'Annual leave') : leave.note,
                        style: subStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(daysLabel(leave.days), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bold label above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// A form field showing a date; tapping it opens the date picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(prettyDateLong(date), style: const TextStyle(fontSize: 14))),
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// White button with red text for destructive actions.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: Color(0xFFEDD8DC)),
        ),
        child: Text(label),
      ),
    );
  }
}

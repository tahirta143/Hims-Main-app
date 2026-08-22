import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_management/task_model.dart';

// ── Palette matching HIMS Dashboard design language ──────────────────────────
class TaskColors {
  static const Color medicalAccent     = Color(0xFF00B5AD);
  static const Color medicalAccentDark = Color(0xFF0D9488);
  static const Color border            = Color(0xFFEDF2F7);   // ← matches dashboard
  static const Color borderLight       = Color(0xFFF1F5F9);
  static const Color bgSurface         = Color(0xFFF8FAFC);
  static const Color slateText         = Color(0xFF334155);
  static const Color slateMuted        = Color(0xFF64748B);
  static const Color slateLight        = Color(0xFF94A3B8);

  static const List<Color> avatarColors = [
    Color(0xFF0D9488), // Teal
    Color(0xFF2563EB), // Blue
    Color(0xFF7C3AED), // Violet
    Color(0xFFD97706), // Amber
    Color(0xFFE11D48), // Rose
    Color(0xFF059669), // Emerald
  ];
}

// ── Status Meta ──────────────────────────────────────────────────────────────
class StatusMeta {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Color dotColor;

  const StatusMeta({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.dotColor,
  });

  static const Map<String, StatusMeta> map = {
    'pending': StatusMeta(
      label: 'Pending',
      bgColor: Color(0xFFF1F5F9),
      textColor: Color(0xFF475569),
      borderColor: Color(0xFFE2E8F0),
      dotColor: Color(0xFF94A3B8),
    ),
    'in_progress': StatusMeta(
      label: 'In Progress',
      bgColor: Color(0xFFF0FDFA),
      textColor: Color(0xFF0F766E),
      borderColor: Color(0xFF99F6E4),
      dotColor: Color(0xFF00B5AD),
    ),
    'completed': StatusMeta(
      label: 'Completed',
      bgColor: Color(0xFFECFDF5),
      textColor: Color(0xFF047857),
      borderColor: Color(0xFFA7F3D0),
      dotColor: Color(0xFF10B981),
    ),
    'hold': StatusMeta(
      label: 'On Hold',
      bgColor: Color(0xFFFFFBEB),
      textColor: Color(0xFFB45309),
      borderColor: Color(0xFFFDE68A),
      dotColor: Color(0xFFF59E0B),
    ),
  };

  static StatusMeta of(String? status) {
    return map[status] ?? map['pending']!;
  }
}

// ── Priority Meta ────────────────────────────────────────────────────────────
class PriorityMeta {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const PriorityMeta({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });

  static const Map<String, PriorityMeta> map = {
    'low': PriorityMeta(
      label: 'Low',
      bgColor: Color(0xFFF8FAFC),
      textColor: Color(0xFF64748B),
      borderColor: Color(0xFFE2E8F0),
    ),
    'medium': PriorityMeta(
      label: 'Medium',
      bgColor: Color(0xFFEFF6FF),
      textColor: Color(0xFF1D4ED8),
      borderColor: Color(0xFFBFDBFE),
    ),
    'high': PriorityMeta(
      label: 'High',
      bgColor: Color(0xFFFFF7ED),
      textColor: Color(0xFFC2410C),
      borderColor: Color(0xFFFED7AA),
    ),
    'urgent': PriorityMeta(
      label: 'Urgent',
      bgColor: Color(0xFFFFF1F2),
      textColor: Color(0xFFBE123C),
      borderColor: Color(0xFFFECDD3),
    ),
  };

  static PriorityMeta of(String? priority) {
    return map[priority] ?? map['medium']!;
  }
}

// ── Status Chip Widget ───────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final meta = StatusMeta.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.bgColor,
        border: Border.all(color: meta.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: meta.dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              color: meta.textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Priority Chip Widget ─────────────────────────────────────────────────────
class PriorityChip extends StatelessWidget {
  final String priority;
  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final meta = PriorityMeta.of(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.bgColor,
        border: Border.all(color: meta.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          color: meta.textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Due Countdown Chip Widget ────────────────────────────────────────────────
class DueChip extends StatelessWidget {
  final String? dueDate;
  final String status;

  const DueChip({super.key, this.dueDate, required this.status});

  int? get daysRemaining {
    if (dueDate == null || dueDate!.isEmpty) return null;
    try {
      final due = DateTime.parse(dueDate!);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      return dueDay.difference(today).inDays;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          border: Border.all(color: const Color(0xFFA7F3D0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 10, color: Color(0xFF047857)),
            SizedBox(width: 3),
            Text(
              'Done',
              style: TextStyle(color: Color(0xFF047857), fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final days = daysRemaining;
    if (days == null) return const SizedBox.shrink();

    Color bgColor;
    Color textColor;
    Color borderColor;
    String label;

    if (days < 0) {
      bgColor = const Color(0xFFFFF1F2);
      textColor = const Color(0xFFBE123C);
      borderColor = const Color(0xFFFECDD3);
      label = '${days.abs()}d overdue';
    } else if (days == 0) {
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFB45309);
      borderColor = const Color(0xFFFDE68A);
      label = 'Due today';
    } else if (days <= 3) {
      bgColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFFC2410C);
      borderColor = const Color(0xFFFED7AA);
      label = '${days}d left';
    } else {
      bgColor = const Color(0xFFF8FAFC);
      textColor = const Color(0xFF64748B);
      borderColor = const Color(0xFFE2E8F0);
      label = '${days}d left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Avatar Widget ────────────────────────────────────────────────────────────
class AvatarWidget extends StatelessWidget {
  final TaskAssignee? person;
  final String? name;
  final int? id;
  final double size;

  const AvatarWidget({
    super.key,
    this.person,
    this.name,
    this.id,
    this.size = 26,
  });

  String get _initials {
    final rawName = person?.name ?? name ?? '?';
    final clean = rawName.replaceAll(RegExp(r'^(Dr|Mr|Mrs|Ms|Miss|Prof)\.?\s+', caseSensitive: false), '').trim();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color get _color {
    final effectiveId = person?.id ?? id ?? 0;
    return TaskColors.avatarColors[effectiveId.abs() % TaskColors.avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = person?.profileImageUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: _color,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Avatar Stack Widget ──────────────────────────────────────────────────────
class AvatarStackWidget extends StatelessWidget {
  final List<TaskAssignee> people;
  final int max;
  final double size;

  const AvatarStackWidget({
    super.key,
    required this.people,
    this.max = 3,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const Text(
        'Unassigned',
        style: TextStyle(fontSize: 10, color: TaskColors.slateLight, fontStyle: FontStyle.italic),
      );
    }

    final shown = people.take(max).toList();
    final extra = people.length - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: (shown.length * (size * 0.65)) + (size * 0.35),
          height: size,
          child: Stack(
            children: List.generate(shown.length, (i) {
              return Positioned(
                left: i * (size * 0.65),
                child: AvatarWidget(person: shown[i], size: size),
              );
            }),
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 3),
          Text(
            '+$extra',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateMuted),
          ),
        ],
      ],
    );
  }
}

// ── Progress Bar ─────────────────────────────────────────────────────────────
class TaskProgressBar extends StatelessWidget {
  final int done;
  final int total;
  final String status;
  final String? dueDate;
  final bool showLabel;

  const TaskProgressBar({
    super.key,
    required this.done,
    required this.total,
    required this.status,
    this.dueDate,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    final pct = (done / total).clamp(0.0, 1.0);
    final pctInt = (pct * 100).round();

    Color barColor = TaskColors.medicalAccent;
    if (pctInt == 100 || status == 'completed') {
      barColor = const Color(0xFF10B981);
    } else if (dueDate != null && dueDate!.isNotEmpty) {
      try {
        final due = DateTime.parse(dueDate!);
        final now = DateTime.now();
        if (due.isBefore(now)) {
          barColor = const Color(0xFFE11D48);
        } else if (due.difference(now).inDays <= 3) {
          barColor = const Color(0xFFF59E0B);
        }
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 5,
            width: double.infinity,
            color: const Color(0xFFE2E8F0),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: pct,
              child: Container(color: barColor),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$done/$total done',
                style: const TextStyle(fontSize: 9, color: TaskColors.slateMuted),
              ),
              Text(
                '$pctInt%',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: TaskColors.slateMuted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Stat Tile Widget — matches dashboard _StatCard aesthetics ─────────────────
class StatTileWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  const StatTileWidget({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),          // matches dashboard _StatCard
        border: Border.all(color: TaskColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header row — dot + label + icon count badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Icon(icon, size: 13, color: accentColor.withOpacity(0.6)),
            ],
          ),
          // Big value
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accentColor,
              fontFamily: 'monospace',
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass Panel — matches dashboard _buildGlassPanel ─────────────────────────
/// Wrap any content in this to match the dashboard's white rounded panel style.
class TaskGlassPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const TaskGlassPanel({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaskColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

// ── Empty State Widget ───────────────────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: TaskColors.slateLight),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: TaskColors.slateText,
              ),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint!,
                style: const TextStyle(fontSize: 12, color: TaskColors.slateMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Star Picker Widget ───────────────────────────────────────────────────────
class StarPickerWidget extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChange;
  final bool disabled;

  const StarPickerWidget({
    super.key,
    required this.value,
    required this.onChange,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final isFilled = starNumber <= value;
        return GestureDetector(
          onTap: disabled
              ? null
              : () {
                  onChange(starNumber == value ? 0 : starNumber);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.star_rounded,
              size: 20,
              color: isFilled ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
            ),
          ),
        );
      }),
    );
  }
}

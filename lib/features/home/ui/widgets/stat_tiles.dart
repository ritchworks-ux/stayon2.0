import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

/// The two at-a-glance stat tiles under the hero card: "Due soon"
/// (overdue + this week) and "Upcoming" (this month + later). Numbers
/// use the display weight so the dashboard scans in under a second.
class StatTiles extends StatelessWidget {
  const StatTiles({super.key, required this.dueSoon, required this.upcoming});

  final int dueSoon;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tile(
            label: 'Due soon',
            value: dueSoon,
            surface: AppColors.catBill,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Tile(
            label: 'Upcoming',
            value: upcoming,
            surface: AppColors.mint,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.surface,
  });

  final String label;
  final int value;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodyMedium?.copyWith(color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: t.displayMedium?.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

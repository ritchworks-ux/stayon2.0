import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

/// The "This week" hero card at the top of the Home dashboard.
///
/// Turns the item list into a single plain-language answer to "what
/// needs me?" — the reassurance the product sells. [dueSoon] counts
/// items in the overdue + this-week window; [overdue] is the subset
/// already past due. Tapping opens the Alerts tab.
class ThisWeekHeroCard extends StatelessWidget {
  const ThisWeekHeroCard({
    super.key,
    required this.dueSoon,
    required this.overdue,
    required this.onTap,
  });

  final int dueSoon;
  final int overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final unit = dueSoon == 1 ? 'thing needs' : 'things need';
    final headline = dueSoon == 0
        ? "You're all caught up"
        : '$dueSoon $unit you this week';
    final sub = overdue > 0 ? '$overdue overdue' : 'Nothing overdue right now';

    return Semantics(
      button: true,
      label: 'This week. $headline. $sub.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS WEEK',
                    style: t.labelSmall?.copyWith(color: AppColors.mint),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    headline,
                    style: t.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        overdue > 0
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sub,
                        style: t.bodyMedium?.copyWith(color: AppColors.mint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

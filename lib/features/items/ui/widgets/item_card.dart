import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/money.dart';
import '../../utils/date_buckets.dart';

/// Dashboard card for a single [Item].
///
/// Renders the category icon + label, item name, relative-date label,
/// and (when present) amount and assignee. Tinted with the category's
/// pastel surface. Tap is injectable via [onTap]; archive/delete live
/// on Item Detail (Phase 2 Task 15) so the card stays uncluttered.
///
/// Overdue items get a coral accent on the relative-date label as a
/// secondary, color-blind-safe signal (the text already starts with
/// "Overdue by ...").
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.onTap, this.now});

  final Item item;
  final VoidCallback? onTap;

  /// Inject for tests; defaults to `DateTime.now()` in production.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isOverdue =
        bucketFor(item.targetDate, now: now) == DateBucket.overdue;
    final rel = relativeDateLabel(item.targetDate, now: now);
    final amount = pesoFromMinor(item.amountMinor);

    return Semantics(
      button: true,
      label:
          '${item.name}, ${item.category.label}, $rel'
          '${amount.isNotEmpty ? ', $amount' : ''}'
          '${item.assigneeLabel != null ? ', assigned to ${item.assigneeLabel}' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: item.category.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.category.icon, size: 22, color: AppColors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category.label.toUpperCase(),
                          style: t.labelSmall?.copyWith(color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          style: t.titleMedium?.copyWith(color: AppColors.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rel,
                          style: t.bodyMedium?.copyWith(
                            color: isOverdue
                                ? AppColors.coral
                                : AppColors.ink.withValues(alpha: 0.72),
                            fontWeight: isOverdue
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        if (item.assigneeLabel != null ||
                            amount.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (item.assigneeLabel != null) ...[
                                const Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: AppColors.ink,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.assigneeLabel!,
                                  style: t.bodyMedium?.copyWith(
                                    color: AppColors.ink.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                ),
                              ],
                              if (item.assigneeLabel != null &&
                                  amount.isNotEmpty)
                                const SizedBox(width: 12),
                              if (amount.isNotEmpty)
                                Text(
                                  amount,
                                  style: t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

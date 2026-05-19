import 'package:flutter/material.dart';

import '../../../../core/models/item.dart';
import '../../utils/date_buckets.dart';
import 'item_card.dart';

/// One labelled section on the Home dashboard ("Overdue", "This week",
/// etc.) containing zero or more [ItemCard]s. Renders nothing when the
/// bucket is empty so we don't show "Overdue (0)" headers.
class ItemCardSection extends StatelessWidget {
  const ItemCardSection({
    super.key,
    required this.bucket,
    required this.items,
    required this.onTapItem,
    this.now,
  });

  final DateBucket bucket;
  final List<Item> items;
  final ValueChanged<Item> onTapItem;
  final DateTime? now;

  String _label() {
    switch (bucket) {
      case DateBucket.overdue:
        return 'Overdue';
      case DateBucket.thisWeek:
        return 'This week';
      case DateBucket.thisMonth:
        return 'This month';
      case DateBucket.later:
        return 'Later';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_label(), style: t.titleMedium),
              Text(
                '${items.length}',
                style: t.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ItemCard(item: item, now: now, onTap: () => onTapItem(item)),
          ),
      ],
    );
  }
}

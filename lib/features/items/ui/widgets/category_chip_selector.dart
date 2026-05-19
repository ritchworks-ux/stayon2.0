import 'package:flutter/material.dart';

import '../../../../core/models/item_category.dart';
import 'category_chip.dart';

/// Single-select picker for all 9 [ItemCategory] values.
///
/// Lays the chips out in a [Wrap] so the form sheet stays responsive on
/// narrow phones (multi-line) and roomy tablets (one line). Calls
/// [onChanged] with the tapped category; if it matches [selected], no
/// callback is fired (no toggle-off — a category is always required).
class CategoryChipSelector extends StatelessWidget {
  const CategoryChipSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ItemCategory selected;
  final ValueChanged<ItemCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Category',
      explicitChildNodes: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in ItemCategory.values)
            CategoryChip(
              category: c,
              selected: c == selected,
              onTap: c == selected ? null : () => onChanged(c),
            ),
        ],
      ),
    );
  }
}

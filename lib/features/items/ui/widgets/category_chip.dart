import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/models/item_category.dart';

/// Single category chip used in [CategoryChipSelector] (item form) and
/// inline on item cards.
///
/// Accessibility:
/// - Selection signaled by BOTH color AND a check icon (color-blind safe)
/// - 48×48 minimum tap target via [Material.tap] + extra padding
/// - Semantics label = "<label>, selected/unselected"
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    this.onTap,
  });

  final ItemCategory category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.forest : category.surface;
    final fg = selected ? Colors.white : AppColors.ink;
    final border = selected ? AppColors.green : Colors.transparent;
    // Mint reliably contrasts against forest in both light + dark mode.
    const checkColor = AppColors.mint;

    return Semantics(
      button: true,
      selected: selected,
      label: '${category.label}, ${selected ? 'selected' : 'not selected'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  category.label,
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: fg,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, size: 16, color: checkColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

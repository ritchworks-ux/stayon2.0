import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

/// Friendly empty state shown on Home when the user has no active items.
/// Static — no provider reads — so it can render inside any container.
class EmptyHomeState extends StatelessWidget {
  const EmptyHomeState({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.event_available_outlined,
              size: 40,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No items yet',
            style: t.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first item.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

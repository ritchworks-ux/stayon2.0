import 'package:flutter/material.dart';

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('StayOn')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Never miss what matters.', style: t.displayMedium),
            const SizedBox(height: 8),
            Text(
              'Project scaffold ready. Auth and features land in Phase 1.',
              style: t.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('People & Shares', style: t.displayMedium),
            const SizedBox(height: 8),
            Text('Coming in Phase 6', style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Calendar', style: t.displayMedium),
            const SizedBox(height: 8),
            Text('Coming in Phase 5', style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}

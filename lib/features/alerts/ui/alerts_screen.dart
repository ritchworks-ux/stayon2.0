import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Alerts', style: t.displayMedium),
            const SizedBox(height: 8),
            Text('Coming in Phase 5', style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}

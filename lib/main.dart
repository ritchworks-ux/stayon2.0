import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/shell/placeholder_home.dart';
import 'app/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: StayOnApp()));
}

class StayOnApp extends StatelessWidget {
  const StayOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StayOn',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const PlaceholderHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

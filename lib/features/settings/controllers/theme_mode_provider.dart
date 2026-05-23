import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives [MaterialApp.themeMode] from user preference.
///
/// Defaults to [ThemeMode.system] so the first launch always honours the
/// OS setting. Persistence via shared_preferences is a Phase 3+ TODO —
/// for now the choice resets on cold start, which is acceptable for a
/// polish-batch MVP.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setMode(ThemeMode mode) => state = mode;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

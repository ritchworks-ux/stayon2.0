/// Time-of-day greeting line for the Home header.
///
/// Returns the label with a trailing comma ("Good morning,") so the
/// user's name renders on the line directly below it. Boundaries:
///   00:00–11:59 -> morning
///   12:00–17:59 -> afternoon
///   18:00–23:59 -> evening
String greetingLine(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 18) return 'Good afternoon,';
  return 'Good evening,';
}

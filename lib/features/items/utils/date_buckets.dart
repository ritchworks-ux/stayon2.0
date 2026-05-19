import '../../../core/models/item.dart';

/// Home dashboard sections. Ordered from most urgent to least.
enum DateBucket { overdue, thisWeek, thisMonth, later }

/// Whole-day delta between two dates (target - now), ignoring time-of-day.
int _daysBetween(DateTime target, DateTime now) {
  final t = DateTime.utc(target.year, target.month, target.day);
  final n = DateTime.utc(now.year, now.month, now.day);
  return t.difference(n).inDays;
}

/// Which Home section a [target] date belongs to.
///
/// Buckets (delta from "today" at midnight, ignoring time-of-day):
///   delta < 0          -> overdue
///   0 <= delta <= 6    -> thisWeek (includes today)
///   7 <= delta <= 30   -> thisMonth
///   delta > 30         -> later
DateBucket bucketFor(DateTime target, {DateTime? now}) {
  final delta = _daysBetween(target, now ?? DateTime.now());
  if (delta < 0) return DateBucket.overdue;
  if (delta <= 6) return DateBucket.thisWeek;
  if (delta <= 30) return DateBucket.thisMonth;
  return DateBucket.later;
}

/// Group items by [DateBucket] and sort each bucket ascending by
/// `target_date`. Always returns all 4 buckets, possibly empty.
Map<DateBucket, List<Item>> bucketize(List<Item> items, {DateTime? now}) {
  final out = <DateBucket, List<Item>>{
    DateBucket.overdue: [],
    DateBucket.thisWeek: [],
    DateBucket.thisMonth: [],
    DateBucket.later: [],
  };
  for (final item in items) {
    out[bucketFor(item.targetDate, now: now)]!.add(item);
  }
  for (final list in out.values) {
    list.sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }
  return out;
}

/// Human-friendly "Due in N days" / "Overdue by N days" string.
///
/// Branches:
///   delta < 0       -> "Overdue by N day(s)" (singular for 1)
///   delta == 0      -> "Due today"
///   delta == 1      -> "Due tomorrow"
///   2..6            -> "Due in N days"
///   7..30           -> "Due in ~N weeks" (rounded)
///   31..364         -> "Due in N month(s)" (singular for 1)
///   >= 365          -> "Due in over a year"
String relativeDateLabel(DateTime target, {DateTime? now}) {
  final delta = _daysBetween(target, now ?? DateTime.now());
  if (delta < 0) {
    final n = -delta;
    return 'Overdue by $n day${n == 1 ? '' : 's'}';
  }
  if (delta == 0) return 'Due today';
  if (delta == 1) return 'Due tomorrow';
  if (delta <= 6) return 'Due in $delta days';
  if (delta <= 30) {
    final weeks = (delta / 7).round();
    return 'Due in ~$weeks weeks';
  }
  if (delta < 365) {
    final months = (delta / 30).round();
    return 'Due in $months month${months == 1 ? '' : 's'}';
  }
  return 'Due in over a year';
}

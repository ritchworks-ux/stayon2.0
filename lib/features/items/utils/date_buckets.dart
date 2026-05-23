import '../../../core/models/item.dart';
import '../../../core/models/item_date_type.dart';

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

/// Human-friendly relative-date string. The verb is driven by [dateType]
/// so cards read "Expires in 3 days", "Renews tomorrow", "Due today", etc.
///
/// When [dateType] is null the function falls back to "Due …" so any
/// call-site that omits the parameter keeps working (backward-compat).
///
/// Overdue copy is always "Overdue by N days" regardless of type —
/// an item is overdue no matter what its date was meant to represent.
///
/// Day-level precision through 30 days, then months, then "over a year":
///   delta < 0        → "Overdue by N day(s)"
///   delta == 0       → "`Verb` today"
///   delta == 1       → "`Verb` tomorrow"
///   2..30            → "`Verb` in N days"
///   31..364          → "`Verb` in N month(s)" (rounded)
///   >= 365           → "`Verb` in over a year"
String relativeDateLabel(
  DateTime target, {
  DateTime? now,
  ItemDateType? dateType,
}) {
  final delta = _daysBetween(target, now ?? DateTime.now());
  final verb = _verb(dateType);

  if (delta < 0) {
    final n = -delta;
    return 'Overdue by $n day${n == 1 ? '' : 's'}';
  }
  if (delta == 0) return '$verb today';
  if (delta == 1) return '$verb tomorrow';
  if (delta <= 30) return '$verb in $delta days';
  if (delta < 365) {
    final months = (delta / 30).round();
    return '$verb in $months month${months == 1 ? '' : 's'}';
  }
  return '$verb in over a year';
}

/// Maps [ItemDateType] to a past-tense verb prefix for relative date labels.
/// Returns "Due" when [dt] is null for backward compatibility.
String _verb(ItemDateType? dt) {
  switch (dt) {
    case ItemDateType.expires:
      return 'Expires';
    case ItemDateType.renews:
      return 'Renews';
    case ItemDateType.due:
    case null:
      return 'Due';
  }
}

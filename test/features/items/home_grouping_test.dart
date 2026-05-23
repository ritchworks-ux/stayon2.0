import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/utils/date_buckets.dart';

DateTime _d(int y, int m, int day) => DateTime.utc(y, m, day);

Item _item({required String id, required DateTime target}) => Item(
  id: id,
  ownerId: 'u',
  name: id,
  category: ItemCategory.other,
  dateType: ItemDateType.expires,
  targetDate: target,
  currencyCode: 'PHP',
  status: ItemStatus.active,
  createdAt: _d(2026, 1, 1),
  updatedAt: _d(2026, 1, 1),
);

void main() {
  final now = _d(2026, 5, 18);

  group('relativeDateLabel', () {
    test('-3 -> Overdue by 3 days', () {
      expect(
        relativeDateLabel(now.subtract(const Duration(days: 3)), now: now),
        'Overdue by 3 days',
      );
    });
    test('-1 -> Overdue by 1 day (singular)', () {
      expect(
        relativeDateLabel(now.subtract(const Duration(days: 1)), now: now),
        'Overdue by 1 day',
      );
    });
    test('0 -> Due today', () {
      expect(relativeDateLabel(now, now: now), 'Due today');
    });
    test('1 -> Due tomorrow', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 1)), now: now),
        'Due tomorrow',
      );
    });
    test('3 -> Due in 3 days', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 3)), now: now),
        'Due in 3 days',
      );
    });
    test('6 -> Due in 6 days', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 6)), now: now),
        'Due in 6 days',
      );
    });
    test('7 -> Due in 7 days (day-level precision)', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 7)), now: now),
        'Due in 7 days',
      );
    });
    test('11 -> Due in 11 days (no week rounding)', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 11)), now: now),
        'Due in 11 days',
      );
    });
    test('30 -> Due in 30 days (upper day-level bound)', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 30)), now: now),
        'Due in 30 days',
      );
    });
    test('11 days overdue -> Overdue by 11 days', () {
      expect(
        relativeDateLabel(now.subtract(const Duration(days: 11)), now: now),
        'Overdue by 11 days',
      );
    });
    test('45 -> Due in 2 months (months kick in past 30 days)', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 45)), now: now),
        'Due in 2 months',
      );
    });
    test('45 -> Due in 2 months (rounded)', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 45)), now: now),
        'Due in 2 months',
      );
    });
    test('40 -> Due in 1 month (singular)', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 40)), now: now),
        'Due in 1 month',
      );
    });
    test('120 -> Due in 4 months', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 120)), now: now),
        'Due in 4 months',
      );
    });
    test('400 -> Due in over a year', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 400)), now: now),
        'Due in over a year',
      );
    });
  });

  group('bucketFor', () {
    test('past -> overdue', () {
      expect(bucketFor(_d(2026, 5, 1), now: now), DateBucket.overdue);
    });
    test('today -> thisWeek', () {
      expect(bucketFor(now, now: now), DateBucket.thisWeek);
    });
    test('+6 days -> thisWeek', () {
      expect(
        bucketFor(now.add(const Duration(days: 6)), now: now),
        DateBucket.thisWeek,
      );
    });
    test('+7 days -> thisMonth', () {
      expect(
        bucketFor(now.add(const Duration(days: 7)), now: now),
        DateBucket.thisMonth,
      );
    });
    test('+30 days -> thisMonth', () {
      expect(
        bucketFor(now.add(const Duration(days: 30)), now: now),
        DateBucket.thisMonth,
      );
    });
    test('+31 days -> later', () {
      expect(
        bucketFor(now.add(const Duration(days: 31)), now: now),
        DateBucket.later,
      );
    });
  });

  // ── verb-by-dateType coverage ────────────────────────────────────────────
  // These tests pass an explicit dateType so labels read "Expires / Renews /
  // Due". The legacy group above omits dateType (null → "Due") to stay
  // backward-compatible with any call-site that doesn't have a dateType handy.
  group('relativeDateLabel — verb by dateType', () {
    test('expires + future → "Expires in N days"', () {
      expect(
        relativeDateLabel(
          now.add(const Duration(days: 5)),
          now: now,
          dateType: ItemDateType.expires,
        ),
        'Expires in 5 days',
      );
    });

    test('renews + future → "Renews in N days"', () {
      expect(
        relativeDateLabel(
          now.add(const Duration(days: 5)),
          now: now,
          dateType: ItemDateType.renews,
        ),
        'Renews in 5 days',
      );
    });

    test('due + future → "Due in N days"', () {
      expect(
        relativeDateLabel(
          now.add(const Duration(days: 5)),
          now: now,
          dateType: ItemDateType.due,
        ),
        'Due in 5 days',
      );
    });

    test('null dateType → "Due in N days" (backward compat)', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 5)), now: now),
        'Due in 5 days',
      );
    });

    test('overdue is always "Overdue by N days" regardless of type', () {
      for (final dt in ItemDateType.values) {
        expect(
          relativeDateLabel(
            now.subtract(const Duration(days: 3)),
            now: now,
            dateType: dt,
          ),
          'Overdue by 3 days',
          reason: 'dateType: $dt',
        );
      }
    });

    test('expires + today → "Expires today"', () {
      expect(
        relativeDateLabel(now, now: now, dateType: ItemDateType.expires),
        'Expires today',
      );
    });

    test('renews + tomorrow → "Renews tomorrow"', () {
      expect(
        relativeDateLabel(
          now.add(const Duration(days: 1)),
          now: now,
          dateType: ItemDateType.renews,
        ),
        'Renews tomorrow',
      );
    });

    test('expires + months range → "Expires in N months"', () {
      expect(
        relativeDateLabel(
          now.add(const Duration(days: 45)),
          now: now,
          dateType: ItemDateType.expires,
        ),
        'Expires in 2 months',
      );
    });

    test('renews + over a year → "Renews in over a year"', () {
      expect(
        relativeDateLabel(
          now.add(const Duration(days: 400)),
          now: now,
          dateType: ItemDateType.renews,
        ),
        'Renews in over a year',
      );
    });
  });

  group('bucketize', () {
    test('groups + sorts ascending by target_date within each bucket', () {
      final items = [
        _item(id: 'a', target: now.add(const Duration(days: 100))),
        _item(id: 'b', target: now.subtract(const Duration(days: 2))),
        _item(id: 'c', target: now.add(const Duration(days: 2))),
        _item(id: 'd', target: now.add(const Duration(days: 5))),
        _item(id: 'e', target: now.add(const Duration(days: 10))),
        _item(id: 'f', target: now.subtract(const Duration(days: 5))),
      ];
      final out = bucketize(items, now: now);

      expect(out[DateBucket.overdue]!.map((i) => i.id), ['f', 'b']);
      expect(out[DateBucket.thisWeek]!.map((i) => i.id), ['c', 'd']);
      expect(out[DateBucket.thisMonth]!.map((i) => i.id), ['e']);
      expect(out[DateBucket.later]!.map((i) => i.id), ['a']);
    });

    test('empty input -> 4 empty buckets', () {
      final out = bucketize(const [], now: now);
      expect(out.length, 4);
      expect(out.values.every((l) => l.isEmpty), isTrue);
    });
  });
}

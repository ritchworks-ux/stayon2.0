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
    test('14 -> Due in ~2 weeks', () {
      expect(
        relativeDateLabel(now.add(const Duration(days: 14)), now: now),
        'Due in ~2 weeks',
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

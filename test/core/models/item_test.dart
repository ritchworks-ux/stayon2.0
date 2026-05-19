import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';

void main() {
  test('round-trips via JSON with all fields populated', () {
    final item = Item(
      id: 'a',
      ownerId: 'o',
      name: 'PhilHealth',
      category: ItemCategory.idLicense,
      dateType: ItemDateType.renews,
      targetDate: DateTime.utc(2026, 12, 31),
      notes: 'Annual',
      assigneeLabel: 'Mom',
      amountMinor: 250000,
      currencyCode: 'PHP',
      status: ItemStatus.active,
      trashedAt: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    expect(Item.fromJson(item.toJson()), item);
  });

  test('round-trips with nullables omitted', () {
    final item = Item(
      id: 'a',
      ownerId: 'o',
      name: 'Bread',
      category: ItemCategory.grocery,
      dateType: ItemDateType.expires,
      targetDate: DateTime.utc(2026, 5, 25),
      notes: null,
      assigneeLabel: null,
      amountMinor: null,
      currencyCode: 'PHP',
      status: ItemStatus.active,
      trashedAt: null,
      createdAt: DateTime.utc(2026, 5, 18),
      updatedAt: DateTime.utc(2026, 5, 18),
    );
    expect(Item.fromJson(item.toJson()), item);
  });

  test('decodes a Supabase row shape (date as YYYY-MM-DD string)', () {
    final row = {
      'id': 'abc',
      'owner_id': 'u1',
      'name': 'PhilHealth',
      'category': 'id_license',
      'date_type': 'renews',
      'target_date': '2026-12-31',
      'notes': null,
      'assignee_label': null,
      'amount_minor': null,
      'currency_code': 'PHP',
      'status': 'active',
      'trashed_at': null,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-02T00:00:00Z',
    };
    final item = Item.fromJson(row);
    expect(item.category, ItemCategory.idLicense);
    expect(item.dateType, ItemDateType.renews);
    expect(item.status, ItemStatus.active);
    expect(item.targetDate, DateTime.utc(2026, 12, 31));
  });
}

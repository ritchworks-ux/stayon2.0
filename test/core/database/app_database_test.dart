import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/database/app_database.dart';

void main() {
  group('AppDatabase', () {
    test('can be initialized with in-memory database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      expect(db, isNotNull);
      expect(db.schemaVersion, 1);
      await db.close();
    });

    test('has both attachment and cached product DAOs', () async {
      final db = AppDatabase(NativeDatabase.memory());
      expect(db.attachmentDao, isNotNull);
      expect(db.cachedProductDao, isNotNull);
      await db.close();
    });
  });
}

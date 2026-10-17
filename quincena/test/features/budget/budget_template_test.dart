import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/features/budget/data/models/models.dart';

void main() {
  group('BudgetTemplate and QuincenaPeriod Tests (RF-04 / R2)', () {
    test('Maps QuincenaPeriod enum values and labels accurately', () {
      expect(QuincenaPeriod.fromValue('first_half'), QuincenaPeriod.firstHalf);
      expect(QuincenaPeriod.fromValue('second_half'), QuincenaPeriod.secondHalf);
      expect(QuincenaPeriod.fromValue('unknown'), QuincenaPeriod.firstHalf);
      expect(QuincenaPeriod.fromValue(null), QuincenaPeriod.firstHalf);

      expect(QuincenaPeriod.firstHalf.value, 'first_half');
      expect(QuincenaPeriod.firstHalf.label, '1ra Quincena');
      expect(QuincenaPeriod.secondHalf.value, 'second_half');
      expect(QuincenaPeriod.secondHalf.label, '2da Quincena');
    });

    test('Serializes and deserializes BudgetTemplate with joined data', () {
      final json = {
        'id': 'tmpl-123',
        'period': 'second_half',
        'category_id': 'cat-456',
        'destination_account_id': 'acc-789',
        'default_amount': 850.50,
        'categories': {
          'id': 'cat-456',
          'name': 'Supermercado',
          'icon': 'shopping_cart',
          'color_hex': '#79ADDC',
        },
        'destination_account': {
          'id': 'acc-789',
          'name': 'Cuenta Monetaria',
          'account_type': 'checking',
          'color_hex': '#79ADDC',
          'icon': 'account_balance',
        },
      };

      final template = BudgetTemplate.fromJson(json);

      expect(template.id, 'tmpl-123');
      expect(template.period, QuincenaPeriod.secondHalf);
      expect(template.categoryId, 'cat-456');
      expect(template.destinationAccountId, 'acc-789');
      expect(template.defaultAmount, 850.50);
      expect(template.category?.name, 'Supermercado');
      expect(template.destinationAccount?.name, 'Cuenta Monetaria');

      final serialized = template.toJson();
      expect(serialized['id'], 'tmpl-123');
      expect(serialized['period'], 'second_half');
      expect(serialized['category_id'], 'cat-456');
      expect(serialized['destination_account_id'], 'acc-789');
      expect(serialized['default_amount'], 850.50);
    });

    test('Handles null destination account and fallback values', () {
      final json = {
        'id': 'tmpl-empty',
        'period': 'first_half',
        'category_id': 'cat-1',
        'default_amount': 150.0,
      };

      final template = BudgetTemplate.fromJson(json);

      expect(template.destinationAccountId, isNull);
      expect(template.destinationAccount, isNull);
      expect(template.category, isNull);
      expect(template.period, QuincenaPeriod.firstHalf);
      expect(template.defaultAmount, 150.0);
    });

    test('Category parses color hex and provides fallback', () {
      const validCategory = Category(
        id: 'c1',
        name: 'Transporte',
        colorHex: '#FFC09F',
      );
      expect(validCategory.parsedColor.toARGB32(), 0xFFFFC09F);

      const invalidCategory = Category(
        id: 'c2',
        name: 'Varios',
        colorHex: 'invalid',
      );
      expect(invalidCategory.parsedColor.toARGB32(), 0xFF79ADDC);
    });
  });
}

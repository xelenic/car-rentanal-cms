import 'package:driver_app/models/hire.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _hireJson({
  String paymentType = 'cash',
  Object? paidAmount,
  Object? balanceRemaining,
  Object? paymentStatus,
}) =>
    {
      'id': 5,
      'tour_type': 'drop_pickup',
      'tour_type_label': 'Drop and Pickup',
      'hire_full_value': 100,
      'payment_type': paymentType,
      'payment_type_label': paymentType == 'credit' ? 'Credit' : 'Cash',
      if (paidAmount != 'omit') 'paid_amount': paidAmount,
      if (balanceRemaining != 'omit') 'balance_remaining': balanceRemaining,
      if (paymentStatus != 'omit') 'payment_status': paymentStatus,
    };

void main() {
  group('payment fields from the API', () {
    test('are read as given', () {
      final hire = Hire.fromJson(_hireJson(
        paymentType: 'credit',
        paidAmount: 40,
        balanceRemaining: 60,
        paymentStatus: 'partial',
      ));

      expect(hire.paidAmount, 40);
      expect(hire.balanceRemaining, 60);
      expect(hire.paymentStatus, 'partial');
    });

    test('a server that predates them defaults to unpaid, not a crash', () {
      final hire = Hire.fromJson(_hireJson(paidAmount: 'omit', balanceRemaining: 'omit', paymentStatus: 'omit'));

      expect(hire.paidAmount, 0);
      expect(hire.balanceRemaining, 0);
      expect(hire.paymentStatus, 'unpaid');
    });

    test('survive copyWith (the hire screen copies the hire on every status update)', () {
      final hire = Hire.fromJson(_hireJson(paymentType: 'credit', paidAmount: 40, balanceRemaining: 60, paymentStatus: 'partial'));

      final copy = hire.copyWith(isTracking: true);

      expect(copy.paidAmount, 40);
      expect(copy.balanceRemaining, 60);
      expect(copy.paymentStatus, 'partial');
    });
  });

  group('isCredit', () {
    test('is true only for a credit hire', () {
      expect(Hire.fromJson(_hireJson(paymentType: 'credit')).isCredit, isTrue);
      expect(Hire.fromJson(_hireJson(paymentType: 'cash')).isCredit, isFalse);
    });
  });

  group('isFullyPaid', () {
    test('is true once payment_status is "paid", whatever the payment type', () {
      expect(Hire.fromJson(_hireJson(paymentType: 'credit', paymentStatus: 'paid')).isFullyPaid, isTrue);
      expect(Hire.fromJson(_hireJson(paymentType: 'credit', paymentStatus: 'partial')).isFullyPaid, isFalse);
      expect(Hire.fromJson(_hireJson(paymentType: 'credit', paymentStatus: 'unpaid')).isFullyPaid, isFalse);
    });
  });
}

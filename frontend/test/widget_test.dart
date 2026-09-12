import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_manager/main.dart';

void main() {
  testWidgets('shows auth screen', (tester) async {
    await tester.pumpWidget(const ReceiptManagerApp());

    expect(find.text('Receipt Manager'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
  });
}

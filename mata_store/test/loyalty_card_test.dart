import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sport_store/widgets/loyalty_card.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('карта: лицо с баллами, по тапу переворот на QR и обратно', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const LoyaltyCard3D(
          balance: 3852,
          levelLabel: 'Платина',
          holderName: 'Михаил Татаринов',
          qrData: 'MATA:LOYALTY:42:3852',
        ),
      ),
    );

    // Лицо: баллы и уровень видны, QR ещё нет.
    expect(find.text('3852'), findsOneWidget);
    expect(find.text('ПЛАТИНА'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    // Тап — переворот: после анимации виден QR, лицо скрыто.
    await tester.tap(find.byType(LoyaltyCard3D));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('3852'), findsNothing);

    // Обратный тап — снова лицо.
    await tester.tap(find.byType(LoyaltyCard3D));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('3852'), findsOneWidget);
  });
}

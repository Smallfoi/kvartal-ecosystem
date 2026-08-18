import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/shared/widgets/brand_sweep.dart';

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  testWidgets('шторка: onCovered в середине, оверлей убран в конце', (
    tester,
  ) async {
    var covered = false;
    late BuildContext ctx;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: Text('форма'));
          },
        ),
      ),
    );

    final future = playBrandSweep(
      ctx,
      title: 'Код из SMS',
      subtitle: 'тест',
      onCovered: () async => covered = true,
    );
    // Въезд 420мс + пауза 80мс + выезд 420мс.
    await _pumpFor(tester, const Duration(milliseconds: 1200));
    await future;

    expect(covered, isTrue);
    expect(find.text('Код из SMS'), findsNothing); // оверлей удалён
  });

  testWidgets('reduced motion: без шторки, onCovered сразу', (tester) async {
    var covered = false;
    late BuildContext ctx;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text('форма'));
            },
          ),
        ),
      ),
    );

    await playBrandSweep(ctx, title: 'Код из SMS', onCovered: () async {
      covered = true;
    });
    expect(covered, isTrue);
    expect(find.text('Код из SMS'), findsNothing);
  });
}

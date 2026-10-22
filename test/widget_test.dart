import 'package:flutter_test/flutter_test.dart';

import 'package:novaseed_mobile/main.dart';

void main() {
  testWidgets('muestra el shell de trabajo de campo', (tester) async {
    await tester.pumpWidget(const NovaSeedApp());

    expect(find.text('NOVASEED'), findsOneWidget);
    expect(find.text('Ensayos'), findsWidgets);
    expect(find.text('SIN CONEXIÓN'), findsOneWidget);
  });
}

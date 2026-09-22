import 'package:flutter_test/flutter_test.dart';

import 'package:cell_tuner/main.dart';

void main() {
  testWidgets('shows the CellTuner shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CellTunerApp());

    expect(find.text('CellTuner'), findsWidgets);
    expect(find.text('Router signal dashboard'), findsOneWidget);
  });
}

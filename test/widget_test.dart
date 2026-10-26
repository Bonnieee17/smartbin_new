import 'package:flutter_test/flutter_test.dart';
import 'package:smartbin_new/main.dart';

void main() {
  testWidgets('SmartBinApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartBinApp());
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:easy_recharge/main.dart'; // Ensure import is correct

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 🛠️ FIX: MyApp() ki jagah EasyRechargeApp() laga diya
    await tester.pumpWidget(const EasyRechargeApp());
  });
}

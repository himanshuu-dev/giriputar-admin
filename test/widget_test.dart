import 'package:flutter_test/flutter_test.dart';
import 'package:giriputtar_admin/main.dart';

void main() {
  testWidgets('shows missing config message', (WidgetTester tester) async {
    await tester.pumpWidget(const ConfigMissingApp());
    expect(find.textContaining('Missing SUPABASE_URL'), findsOneWidget);
  });
}

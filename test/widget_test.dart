import 'package:bookat/src/app/bookat_app.dart';
import 'package:bookat/src/app/service_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows businesses on home screen', (tester) async {
    await configureDependencies(useMockData: true);
    await tester.pumpWidget(const BookatApp());

    await tester.pumpAndSettle();

    expect(find.text('Bookat'), findsOneWidget);
    expect(find.text('Find and book trusted businesses'), findsOneWidget);
    expect(find.text('Businesses'), findsOneWidget);
    expect(find.text('gwrswfefw'), findsOneWidget);
    expect(find.text('View slots'), findsWidgets);
  });
}

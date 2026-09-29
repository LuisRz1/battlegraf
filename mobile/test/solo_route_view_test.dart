import 'package:battlegraf_mobile/core/theme/app_theme.dart';
import 'package:battlegraf_mobile/domain/models/solo_campaign.dart';
import 'package:battlegraf_mobile/presentation/providers/solo_journey_provider.dart';
import 'package:battlegraf_mobile/presentation/views/student/solo_route_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('solo branching map fits a compact phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final campaign = SoloCampaignDefinition(
      grade: '5to de primaria',
      subject: 'Matemática',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soloCampaignProvider.overrideWithValue(campaign),
          soloJourneyProvider.overrideWith(
            (ref) =>
                SoloJourneyNotifier(playerProfileId: null, campaign: campaign),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: SoloRouteView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RUTA AL CASTILLO'), findsOneWidget);
    expect(find.text('EL CRUCE'), findsOneWidget);
    expect(find.text('GUARDIÁN DEL CASTILLO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

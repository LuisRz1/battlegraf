import 'package:battlegraf_mobile/domain/models/solo_campaign.dart';
import 'package:battlegraf_mobile/presentation/providers/solo_journey_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'the learner chooses a branch and local progress survives restart',
    () async {
      final campaign = SoloCampaignDefinition(
        grade: '5to de primaria',
        subject: 'Matemática',
      );
      final journey = SoloJourneyNotifier(
        playerProfileId: null,
        campaign: campaign,
      );
      await journey.load();

      expect(journey.state.isUnlocked(campaign.node('first_step')), isTrue);
      expect(journey.state.isUnlocked(campaign.node('path_choice')), isFalse);
      expect(
        await journey.completeNode('first_step', score: 100, stars: 3),
        isTrue,
      );
      expect(journey.state.isUnlocked(campaign.node('path_choice')), isTrue);

      expect(await journey.chooseRoute('forest'), isTrue);
      expect(journey.state.isUnlocked(campaign.node('forest_lesson')), isTrue);
      expect(journey.state.isUnlocked(campaign.node('ruins_lesson')), isFalse);
      expect(
        await journey.completeNode('forest_lesson', score: 100, stars: 3),
        isTrue,
      );
      expect(
        journey.state.isUnlocked(campaign.node('forest_treasure')),
        isTrue,
      );
      journey.dispose();

      final restored = SoloJourneyNotifier(
        playerProfileId: null,
        campaign: campaign,
      );
      await restored.load();
      expect(restored.state.selectedRoute, 'forest');
      expect(restored.state.isComplete('first_step'), isTrue);
      expect(restored.state.isComplete('forest_lesson'), isTrue);
      expect(restored.state.isUnlocked(campaign.node('castle_gate')), isFalse);
      restored.dispose();
    },
  );

  test('campaign ids are stable for a grade and subject pair', () {
    final first = SoloCampaignDefinition(
      grade: '5to de primaria',
      subject: 'Matemática',
    );
    final same = SoloCampaignDefinition(
      grade: '5to de primaria',
      subject: 'Matemática',
    );
    final different = SoloCampaignDefinition(
      grade: '1ro de secundaria',
      subject: 'Ciencia y tecnología',
    );

    expect(first.id, same.id);
    expect(first.id, isNot(different.id));
    expect(first.questions, isNotEmpty);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:mind_diary/main.dart';
import 'package:mind_diary/providers/app_provider.dart';
import 'package:mind_diary/models/app_models.dart';
import 'package:mind_diary/widgets/plant_view.dart';

Future<void> _pumpApp(WidgetTester tester, AppProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: const MindDiaryApp(),
    ),
  );
  // 정원 화면은 무한 애니메이션이 있어 pumpAndSettle 대신 단일 프레임만 펌프한다.
  await tester.pump();
}

void main() {
  setUp(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('첫 실행 시 온보딩 화면이 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.load();

    await _pumpApp(tester, provider);

    expect(find.text('마음 정원에 오신 걸 환영해요'), findsOneWidget);
    expect(find.text('정원 시작하기'), findsOneWidget);
  });

  testWidgets('온보딩을 마치면 이름이 들어간 정원 화면으로 들어간다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'studentName': '초롱',
      'currentPlant':
          '{"type":"appleTree","growthLevel":50,"plantedAt":"2026-05-20T00:00:00.000"}',
    });
    final provider = AppProvider();
    await provider.load();

    await _pumpApp(tester, provider);

    expect(find.text('초롱의 마음 정원'), findsOneWidget);
  });

  test('연속 기록일과 감정 집계가 올바르게 계산된다', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.load();

    await provider.addDiaryEntry('happy', '좋은 하루');
    await provider.addDiaryEntry('sad', '속상한 일');

    expect(provider.totalEntries, 2);
    expect(provider.streakDays, 1);
    final counts = provider.emotionCounts();
    expect(counts['happy'], 1);
    expect(counts['sad'], 1);
  });

  testWidgets('4종 식물 페인터가 모든 성장 단계에서 예외 없이 그려진다', (tester) async {
    for (final type in PlantType.values) {
      for (final growth in [0, 8, 35, 70, 100]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: PlantView(type: type, growthLevel: growth),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull,
            reason: '$type @ $growth%에서 렌더 예외 발생');
      }
    }
  });

  test('API 키를 저장하면 AI가 활성화되고, 비우면 비활성화된다', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.load();

    expect(provider.aiEnabled, false);
    await provider.setApiKey('test-key-123');
    expect(provider.aiEnabled, true);
    expect(provider.apiKey, 'test-key-123');
    await provider.setApiKey('');
    expect(provider.aiEnabled, false);
  });

  test('AI 서술을 일기에 첨부하면 해당 기록에 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.load();

    final entry = await provider.addDiaryEntry('happy', '좋은 하루');
    await provider.attachAiResult(entry.id, narration: '오늘 너의 하루는 반짝였어 🌟');

    final updated = provider.diaryEntries.firstWhere((e) => e.id == entry.id);
    expect(updated.aiNarration, '오늘 너의 하루는 반짝였어 🌟');
  });

  test('식물이 다 자라면 수확 후 새 씨앗으로 도감에 보관된다', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'currentPlant':
          '{"type":"appleTree","growthLevel":100,"plantedAt":"2026-05-20T00:00:00.000"}',
    });
    final provider = AppProvider();
    await provider.load();

    expect(provider.currentPlant.isFullyGrown, true);
    await provider.harvestAndPlant(PlantType.sunflower);

    expect(provider.collection.length, 1);
    expect(provider.collection.first.type, PlantType.appleTree);
    expect(provider.currentPlant.type, PlantType.sunflower);
    expect(provider.currentPlant.growthLevel, 0);
  });
}

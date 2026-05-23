import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/app_models.dart';

/// 사용자에게 보여줄 친절한 메시지를 담은 AI 오류
class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// Gemini를 감싸 그림일기 생성과 교사용 정서 분석을 제공한다.
/// 모든 호출은 교사가 설정에 입력한 API 키로 이루어진다.
class AiService {
  final String apiKey;
  AiService(this.apiKey);

  // 텍스트 분석/서술용 (안정적인 GA 모델)
  static const _textModel = 'gemini-2.0-flash';
  // 이미지 생성용 (가용 시도, 실패하면 글로 폴백)
  static const _imageModel = 'gemini-2.5-flash-image-preview';

  GenerativeModel get _model =>
      GenerativeModel(model: _textModel, apiKey: apiKey);

  // ── 아동용: 그림일기 서술 + 공감 답글 ──────────────────────────────────────
  Future<String> generateDiaryNarration({
    required String childName,
    required String emotionLabel,
    required String diaryText,
  }) async {
    final name = childName.trim().isEmpty ? '친구' : childName.trim();
    final text =
        diaryText.trim().isEmpty ? '(오늘 있었던 일을 글로 적지는 않았어요)' : diaryText.trim();
    final prompt = '''
너는 '마음 정원'의 따뜻한 정원지기야. 초등학생 $name이(가) 오늘 '$emotionLabel' 기분으로 아래 일기를 썼어.

일기: "$text"

이 일기를 바탕으로 다음을 해줘:
1) 아이의 하루를 그림일기처럼 2~3문장으로 따뜻하게 다시 들려줘. 아이를 '너'라고 부르며 다정한 반말로.
2) 마지막 줄에 아이의 감정을 있는 그대로 인정하고 위로·격려하는 한 문장을 더해줘.

규칙: 초등학생이 이해할 쉬운 말. 이모지는 1~2개만. 진단하거나 훈계하지 말 것. 4문장 이내.''';

    try {
      final res = await _model.generateContent([Content.text(prompt)]);
      final out = res.text?.trim();
      if (out == null || out.isEmpty) {
        throw AiException('AI가 답을 만들지 못했어요. 잠시 후 다시 시도해주세요.');
      }
      return out;
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException(_friendly(e));
    }
  }

  // ── 아동용: 그림 생성 (best-effort, 실패 시 null) ───────────────────────────
  Future<Uint8List?> generateIllustration({
    required String emotionLabel,
    required String diaryText,
  }) async {
    final scene = diaryText.trim().isEmpty
        ? 'a calm everyday moment in a child\'s day'
        : diaryText.trim();
    final imagePrompt =
        'A gentle children\'s storybook illustration representing a child\'s day. '
        'Mood: $emotionLabel. Scene: $scene. '
        'Soft watercolor, warm pastel colors, cozy and hopeful. '
        'No text, no words, no letters anywhere in the image. '
        'Do not depict realistic human faces.';

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_imageModel:generateContent?key=$apiKey');
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': imagePrompt}
                  ]
                }
              ],
              'generationConfig': {
                'responseModalities': ['TEXT', 'IMAGE']
              }
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      final parts =
          candidates?.firstOrNull?['content']?['parts'] as List?;
      if (parts == null) return null;
      for (final p in parts) {
        final inline = p['inlineData'] ?? p['inline_data'];
        final b64 = inline?['data'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          return base64Decode(b64);
        }
      }
      return null;
    } catch (_) {
      return null; // 이미지 실패는 조용히 폴백
    }
  }

  // ── 아동용: 사진 분석 → 일기 주제 질문 3개 ─────────────────────────────────
  // API 키가 있을 때만 호출. 실패하면 null 반환(조용히 폴백).
  Future<List<String>?> analyzePhotoForPrompts(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final mime =
          imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      const prompt = '''
이 사진을 보고, 초등학생 아이가 오늘 있었던 일을 일기에 잘 쓸 수 있도록 도와줘.
사진 속 장소·사물·사람·분위기를 참고해서 아이가 답하기 쉬운 질문 3개를 만들어줘.

아래 형식만 출력해줘 (다른 말은 쓰지 말 것):
Q1: [질문]
Q2: [질문]
Q3: [질문]

규칙: 초등학생이 이해할 쉬운 한국어. 각 질문은 20자 이내. 답하기 쉬운 열린 질문.''';

      final content = Content.multi([
        DataPart(mime, bytes),
        TextPart(prompt),
      ]);

      final res = await _model.generateContent([content]);
      final text = res.text?.trim();
      if (text == null || text.isEmpty) return null;

      final prompts = <String>[];
      for (final line in text.split('\n')) {
        final m = RegExp(r'^Q\d+:\s*(.+)$').firstMatch(line.trim());
        if (m != null) prompts.add(m.group(1)!.trim());
      }
      return prompts.isEmpty ? null : prompts;
    } catch (_) {
      return null;
    }
  }

  // ── 교사용: 아동별 정서 리포트 + 감정 패턴 분석 ─────────────────────────────
  Future<String> analyzeChild({
    required String childName,
    required List<EmotionEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw AiException('분석할 기록이 아직 없어요. 일기를 먼저 작성해주세요.');
    }
    final name = childName.trim().isEmpty ? '학생' : childName.trim();
    final df = DateFormat('M/d(E)', 'ko_KR');
    final recent = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    final limited =
        recent.length > 40 ? recent.sublist(recent.length - 40) : recent;
    final records = limited
        .map((e) =>
            '- ${df.format(e.date)} [${e.emotionInfo.label}] ${e.diaryText.trim().isEmpty ? '(내용 없음)' : e.diaryText.trim()}')
        .join('\n');

    final prompt = '''
너는 초등 담임교사를 돕는 아동 정서 분석 보조자야. 아래는 학생 "$name"의 최근 감정 일기 기록이야.

$records

이 기록을 바탕으로 아래 형식의 한국어 보고서를 작성해줘:

## 정서 요약
최근 전반적인 정서 상태를 3~4문장으로.

## 감정 패턴·변화
자주 나타난 감정, 시간이나 요일에 따른 흐름·변화, 눈에 띄는 전환점을 짚어줘.

## 자주 등장한 주제
일기에 반복되는 관심사·사건·인물.

## 교사를 위한 제안
아이와 나눌 수 있는 대화나 살펴보면 좋을 점 2~3가지.

주의사항: 이 분석은 참고용이며 의학적·심리학적 진단이 아니야. '~로 보입니다', '~일 수 있습니다'처럼 신중한 표현을 쓰고, 단정하지 말 것. 아이를 존중하는 따뜻한 톤으로.''';

    try {
      final res = await _model.generateContent([Content.text(prompt)]);
      final out = res.text?.trim();
      if (out == null || out.isEmpty) {
        throw AiException('AI 분석을 받지 못했어요. 잠시 후 다시 시도해주세요.');
      }
      return out;
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException(_friendly(e));
    }
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('api key') ||
        s.contains('api_key') ||
        s.contains('invalid') ||
        s.contains('permission') ||
        s.contains('401') ||
        s.contains('403')) {
      return 'API 키가 올바르지 않은 것 같아요. 설정에서 키를 확인해주세요.';
    }
    if (s.contains('network') ||
        s.contains('socket') ||
        s.contains('timeout') ||
        s.contains('failed host')) {
      return '인터넷 연결을 확인해주세요.';
    }
    if (s.contains('quota') || s.contains('429') || s.contains('rate')) {
      return 'AI 사용량이 잠시 초과됐어요. 조금 뒤 다시 시도해주세요.';
    }
    return 'AI 응답 중 문제가 생겼어요. 잠시 후 다시 시도해주세요.';
  }
}

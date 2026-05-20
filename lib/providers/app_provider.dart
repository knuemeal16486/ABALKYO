import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class AppProvider with ChangeNotifier {
  static const _kOnboarded = 'onboarded';
  static const _kName = 'studentName';
  static const _kPlant = 'currentPlant';
  static const _kEntries = 'diaryEntries';
  static const _kCollection = 'collection';
  static const _kApiKey = 'geminiApiKey';

  // 일기 한 번에 자라는 성장량 (약 15회 기록 시 만개)
  static const int growthPerEntry = 7;

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  bool _onboarded = false;
  bool get onboarded => _onboarded;

  String _studentName = '';
  String get studentName => _studentName;

  static int _newSeed() => Random().nextInt(0x7fffffff);

  Plant _currentPlant = Plant(
      type: PlantType.appleTree,
      growthLevel: 0,
      plantedAt: DateTime.now(),
      seed: _newSeed());
  Plant get currentPlant => _currentPlant;

  final List<EmotionEntry> _diaryEntries = [];
  List<EmotionEntry> get diaryEntries => List.unmodifiable(_diaryEntries);

  final List<HarvestedPlant> _collection = [];
  List<HarvestedPlant> get collection => List.unmodifiable(_collection);

  bool _isRaining = false;
  bool get isRaining => _isRaining;
  Timer? _rainTimer;

  String _apiKey = '';
  String get apiKey => _apiKey;
  bool get aiEnabled => _apiKey.trim().isNotEmpty;

  // ── 로딩 ────────────────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;

    _onboarded = prefs.getBool(_kOnboarded) ?? false;
    _studentName = prefs.getString(_kName) ?? '';
    _apiKey = prefs.getString(_kApiKey) ?? '';

    final plantJson = prefs.getString(_kPlant);
    if (plantJson != null) {
      try {
        _currentPlant = Plant.fromJson(jsonDecode(plantJson));
      } catch (_) {}
    }

    final entriesJson = prefs.getString(_kEntries);
    if (entriesJson != null) {
      try {
        final list = (jsonDecode(entriesJson) as List)
            .map((e) => EmotionEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _diaryEntries
          ..clear()
          ..addAll(list);
      } catch (_) {}
    }

    final collectionJson = prefs.getString(_kCollection);
    if (collectionJson != null) {
      try {
        final list = (jsonDecode(collectionJson) as List)
            .map((e) => HarvestedPlant.fromJson(e as Map<String, dynamic>))
            .toList();
        _collection
          ..clear()
          ..addAll(list);
      } catch (_) {}
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(_kOnboarded, _onboarded);
    await prefs.setString(_kName, _studentName);
    await prefs.setString(_kPlant, jsonEncode(_currentPlant.toJson()));
    await prefs.setString(
        _kEntries, jsonEncode(_diaryEntries.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _kCollection, jsonEncode(_collection.map((e) => e.toJson()).toList()));
    await prefs.setString(_kApiKey, _apiKey);
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _save();
    notifyListeners();
  }

  // ── 온보딩 ──────────────────────────────────────────────────────────────
  Future<void> completeOnboarding(String name, PlantType type) async {
    _studentName = name.trim();
    _currentPlant = Plant(
        type: type,
        growthLevel: 0,
        plantedAt: DateTime.now(),
        seed: _newSeed());
    _onboarded = true;
    await _save();
    notifyListeners();
  }

  Future<void> setStudentName(String name) async {
    _studentName = name.trim();
    await _save();
    notifyListeners();
  }

  // 공유 태블릿에서 다음 학생을 위해 모든 기록을 비운다
  Future<void> resetAll() async {
    for (final e in _diaryEntries) {
      await _deletePhoto(e.imageUrl);
      await _deletePhoto(e.aiImageUrl);
    }
    _diaryEntries.clear();
    _collection.clear();
    _studentName = '';
    _currentPlant = Plant(
        type: PlantType.appleTree,
        growthLevel: 0,
        plantedAt: DateTime.now(),
        seed: _newSeed());
    _onboarded = false;
    _isRaining = false;
    _rainTimer?.cancel();
    await _save();
    notifyListeners();
  }

  // ── 일기 추가 ───────────────────────────────────────────────────────────
  Future<EmotionEntry> addDiaryEntry(String emotion, String text,
      {String? sourcePhotoPath}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final savedPath = await _persistPhoto(sourcePhotoPath, id);

    final entry = EmotionEntry(
      id: id,
      date: DateTime.now(),
      emotion: emotion,
      diaryText: text.trim(),
      imageUrl: savedPath,
    );
    _diaryEntries.add(entry);
    _growFromEmotion(emotion);
    await _save();
    notifyListeners();
    return entry;
  }

  // AI 생성 결과(서술/공감 답글, 생성 그림)를 기존 일기에 연결
  Future<void> attachAiResult(String id,
      {String? narration, Uint8List? imageBytes}) async {
    final idx = _diaryEntries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    String? aiImagePath;
    if (imageBytes != null) {
      aiImagePath = await _saveAiImage(imageBytes, id);
    }
    _diaryEntries[idx] = _diaryEntries[idx]
        .copyWith(aiNarration: narration, aiImageUrl: aiImagePath);
    await _save();
    notifyListeners();
  }

  Future<String?> _saveAiImage(Uint8List bytes, String id) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final aiDir = Directory('${dir.path}/ai_images');
      if (!await aiDir.exists()) await aiDir.create(recursive: true);
      final dest = '${aiDir.path}/$id.png';
      await File(dest).writeAsBytes(bytes);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteEntry(String id) async {
    final idx = _diaryEntries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final removed = _diaryEntries.removeAt(idx);
    await _deletePhoto(removed.imageUrl);
    await _deletePhoto(removed.aiImageUrl);
    await _save();
    notifyListeners();
  }

  void _growFromEmotion(String emotion) {
    if (Emotions.isComforting(emotion)) {
      _isRaining = true;
      _rainTimer?.cancel();
      _rainTimer = Timer(const Duration(seconds: 6), () {
        _isRaining = false;
        notifyListeners();
      });
    }

    // 모든 감정은 똑같이 정원을 자라게 한다 (어려운 감정도 소중한 거름)
    final newGrowth = (_currentPlant.growthLevel + growthPerEntry).clamp(0, 100);
    _currentPlant = _currentPlant.copyWith(growthLevel: newGrowth);
  }

  // 개발용: 성장 단계를 빠르게 확인 (10%씩 증가, 100% 다음엔 0으로 순환)
  Future<void> devAdvanceGrowth() async {
    final cur = _currentPlant.growthLevel;
    final next = cur >= 100 ? 0 : (cur + 10).clamp(0, 100);
    _currentPlant = _currentPlant.copyWith(growthLevel: next);
    notifyListeners();
    await _save();
  }

  // ── 수확 후 새 씨앗 심기 ─────────────────────────────────────────────────
  Future<void> harvestAndPlant(PlantType newType) async {
    if (_currentPlant.isFullyGrown) {
      _collection.add(HarvestedPlant(
        type: _currentPlant.type,
        harvestedAt: DateTime.now(),
      ));
    }
    _currentPlant = Plant(
        type: newType,
        growthLevel: 0,
        plantedAt: DateTime.now(),
        seed: _newSeed());
    await _save();
    notifyListeners();
  }

  // ── 사진 영구 저장 ──────────────────────────────────────────────────────
  Future<String?> _persistPhoto(String? srcPath, String id) async {
    if (srcPath == null) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/diary_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final dot = srcPath.lastIndexOf('.');
      final ext = (dot != -1 && dot > srcPath.length - 6)
          ? srcPath.substring(dot)
          : '.jpg';
      final dest = '${photosDir.path}/$id$ext';
      await File(srcPath).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deletePhoto(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ── 통계 ────────────────────────────────────────────────────────────────
  int get totalEntries => _diaryEntries.length;

  // 연속 기록 일수 (오늘 또는 어제부터 거꾸로)
  int get streakDays {
    if (_diaryEntries.isEmpty) return 0;
    final days = _diaryEntries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    int streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // 최근 [days]일간 감정별 횟수
  Map<String, int> emotionCounts({int days = 30}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final counts = <String, int>{};
    for (final e in _diaryEntries) {
      if (e.date.isAfter(since)) {
        counts[e.emotion] = (counts[e.emotion] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  void dispose() {
    _rainTimer?.cancel();
    super.dispose();
  }
}

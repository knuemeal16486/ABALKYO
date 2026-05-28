import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class AppProvider with ChangeNotifier {
  static const _kOnboarded     = 'onboarded';
  static const _kName          = 'studentName';
  static const _kPlant         = 'currentPlant';
  static const _kEntries       = 'diaryEntries';
  static const _kCollection    = 'collection';
  static const _kApiKey        = 'geminiApiKey';
  static const _kClassCode     = 'classCode';
  static const _kStudentUid    = 'studentUid';

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  bool _onboarded = false;
  bool get onboarded => _onboarded;

  String _studentName = '';
  String get studentName => _studentName;

  String _classCode = '';
  String get classCode => _classCode;
  bool get inClass => _classCode.isNotEmpty;

  String _studentUid = '';
  String get studentUid => _studentUid;

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

  // 날씨 (기상청 KMA 실측 데이터)
  WeatherData? _weather;
  WeatherData? get weather => _weather;

  // isRaining: 감정 일기 → 위로의 비 OR 실제 기상청 강수
  bool _emotionRain = false;
  bool get isRaining => _emotionRain || (_weather?.isRainy ?? false);
  Timer? _rainTimer;

  String _apiKey = '';
  String get apiKey => _apiKey;
  bool get aiEnabled => _apiKey.trim().isNotEmpty;

  // ── 로딩 ────────────────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;

    _onboarded   = prefs.getBool(_kOnboarded) ?? false;
    _studentName = prefs.getString(_kName) ?? '';
    _apiKey      = prefs.getString(_kApiKey) ?? 'AIzaSyBc6OkXIhqKwN_6X5nn1Uh6kgmFjIBe_k8';
    _classCode   = prefs.getString(_kClassCode) ?? '';

    // 기기마다 고유한 studentUid 보장
    var uid = prefs.getString(_kStudentUid) ?? '';
    if (uid.isEmpty) {
      uid = const Uuid().v4();
      await prefs.setString(_kStudentUid, uid);
    }
    _studentUid = uid;

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

    _checkWilting();
    _loaded = true;
    notifyListeners();
    // 날씨는 비동기로 로드 (앱 시작을 막지 않음)
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.fetchData();
    if (data != null) {
      _weather = data;
      notifyListeners();
    }
  }

  // 수동 새로고침 (설정 화면 등에서 호출)
  Future<void> refreshWeather() async {
    final prefs = _prefs;
    if (prefs != null) await prefs.remove('kma_weather_v2');
    await _fetchWeather();
  }

  // ── 시들기 체크 — 앱 열 때마다 호출 ──────────────────────────────────────
  void _checkWilting() {
    final missed = _currentPlant.daysSinceWatered;
    if (missed >= 2) {
      final penalty = (missed - 1) * 4;
      final newHealth = (_currentPlant.health - penalty).clamp(0, 100);
      _currentPlant = _currentPlant.copyWith(health: newHealth);
    }
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
    await prefs.setString(_kClassCode, _classCode);
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

  // ── 학급 코드 관리 ───────────────────────────────────────────────────────
  /// 학생이 학급 코드를 입력해 수업에 참여한다. 코드가 유효하면 true 반환.
  Future<bool> joinClass(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(trimmed)
          .get();
      if (!doc.exists) return false;
      _classCode = trimmed;
      await _save();
      await _uploadStudentProfile();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> leaveClass() async {
    _classCode = '';
    await _save();
    notifyListeners();
  }

  Future<void> _uploadStudentProfile() async {
    if (_classCode.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(_classCode)
          .collection('students')
          .doc(_studentUid)
          .set({
        'name': _studentName,
        'growthLevel': _currentPlant.growthLevel,
        'health': _currentPlant.health,
        'plantType': _currentPlant.type.name,
        'streakDays': streakDays,
        'totalEntries': totalEntries,
        'wroteTodayDiary': _wroteToday,
        'lastWateredDate': _currentPlant.lastWateredDate.toIso8601String(),
        'latestEmotion':
            _diaryEntries.isNotEmpty ? _diaryEntries.last.emotion : null,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  bool get _wroteToday {
    final today = DateTime.now();
    return _diaryEntries.any((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day);
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
    _classCode   = '';
    _currentPlant = Plant(
        type: PlantType.appleTree,
        growthLevel: 0,
        plantedAt: DateTime.now(),
        seed: _newSeed());
    _onboarded = false;
    _emotionRain = false;
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
    _growFromDiary(emotion, text);
    await _save();
    _syncToFirestore(entry); // fire-and-forget; Firestore SDK handles offline
    notifyListeners();
    return entry;
  }

  // ── 실제 식물 케어 알고리즘 ─────────────────────────────────────────────
  void _growFromDiary(String emotion, String text) {
    if (Emotions.isComforting(emotion)) {
      _emotionRain = true;
      _rainTimer?.cancel();
      _rainTimer = Timer(const Duration(seconds: 6), () {
        _emotionRain = false;
        notifyListeners();
      });
    }

    // 수분 회복 (+40%)
    final newHealth = (_currentPlant.health + 40).clamp(0, 100);

    // 기본 성장 5%
    double growth = 5.0;

    // 비료 보너스 (일기 길이)
    if (text.length > 30) growth += 1.5;
    if (text.length > 80) growth += 1.5;

    // 햇빛 보너스 (연속 작성 스트릭)
    final streak = streakDays;
    if (streak >= 3) growth += 1.0;
    if (streak >= 7) growth += 2.0;

    // 시들었을 때 회복 속도 절반
    if (_currentPlant.health < 30) growth *= 0.5;

    final newGrowth =
        (_currentPlant.growthLevel + growth.round()).clamp(0, 100);

    _currentPlant = _currentPlant.copyWith(
      growthLevel: newGrowth,
      health: newHealth,
      lastWateredDate: DateTime.now(),
    );
  }

  // ── Firestore 동기화 ─────────────────────────────────────────────────────
  Future<void> _syncToFirestore(EmotionEntry entry) async {
    if (_classCode.isEmpty) return;
    try {
      final db = FirebaseFirestore.instance;
      final studentRef = db
          .collection('classes')
          .doc(_classCode)
          .collection('students')
          .doc(_studentUid);

      final recentEntries =
          _diaryEntries.reversed.take(5).map((e) => e.toJson()).toList();

      await studentRef.set({
        'name': _studentName,
        'growthLevel': _currentPlant.growthLevel,
        'health': _currentPlant.health,
        'plantType': _currentPlant.type.name,
        'streakDays': streakDays,
        'totalEntries': totalEntries,
        'wroteTodayDiary': true,
        'lastWateredDate': _currentPlant.lastWateredDate.toIso8601String(),
        'latestEmotion': entry.emotion,
        'recentEntries': recentEntries,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await studentRef.collection('entries').doc(entry.id).set(entry.toJson());
    } catch (_) {
      // 오프라인 — Firestore SDK가 온라인 복귀 시 재시도
    }
  }

  // AI 생성 결과를 기존 일기에 연결
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

  // 개발용: 성장 단계를 10%씩 순환
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

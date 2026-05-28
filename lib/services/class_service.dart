// FILE: lib/services/class_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';
import '../models/class_models.dart';

/// Firestore 기반 학급 관리 서비스.
/// 교사용 대시보드·상세 화면에서 실시간 스트림을 제공한다.
class ClassService {
  static final _db = FirebaseFirestore.instance;

  // ── 학급 전체 학생 목록 실시간 스트림 ─────────────────────────────────────
  /// [classCode] 학급에 속한 모든 학생의 요약 정보를 실시간으로 반환한다.
  static Stream<List<StudentSummary>> watchStudents(String classCode) {
    return _db
        .collection('classes')
        .doc(classCode)
        .collection('students')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => StudentSummary.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  // ── 학생 개별 상세 정보 실시간 스트림 ────────────────────────────────────
  /// [classCode] 학급의 [studentUid] 학생의 모든 일기 + 요약 정보를 반환한다.
  static Stream<StudentDetailData> watchStudentDetail(
    String classCode,
    String studentUid,
  ) {
    // 요약 문서와 일기 컬렉션을 병합해 반환
    final summaryStream = _db
        .collection('classes')
        .doc(classCode)
        .collection('students')
        .doc(studentUid)
        .snapshots();

    final entriesStream = _db
        .collection('classes')
        .doc(classCode)
        .collection('students')
        .doc(studentUid)
        .collection('entries')
        .orderBy('date', descending: true)
        .snapshots();

    return summaryStream.asyncExpand((summarySnap) {
      if (!summarySnap.exists) {
        return const Stream.empty();
      }
      final summary = StudentSummary.fromMap(
        summarySnap.id,
        summarySnap.data() ?? {},
      );
      return entriesStream.map((entriesSnap) {
        final entries = entriesSnap.docs
            .map((d) => EmotionEntry.fromJson(d.data()))
            .toList();
        return StudentDetailData(summary: summary, allEntries: entries);
      });
    });
  }

  // ── 학급 코드 생성 ────────────────────────────────────────────────────────
  /// 새 학급을 Firestore에 생성하고 6자리 코드를 반환한다.
  static Future<String> createClass({
    required String teacherUid,
    required String className,
  }) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now();
    String code;
    do {
      final rng = now.millisecondsSinceEpoch;
      code = String.fromCharCodes(
        List.generate(6, (i) => chars.codeUnitAt((rng >> i) % chars.length)),
      );
    } while (false);

    await _db.collection('classes').doc(code).set({
      'teacherUid': teacherUid,
      'className': className,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  // ── 학생 학급 참여 ────────────────────────────────────────────────────────
  /// 학생이 [classCode] 학급에 참여 등록한다.
  static Future<void> joinClass({
    required String classCode,
    required String studentUid,
    required String studentName,
  }) async {
    await _db
        .collection('classes')
        .doc(classCode)
        .collection('students')
        .doc(studentUid)
        .set({
      'name': studentName,
      'growthLevel': 0,
      'health': 100,
      'streakDays': 0,
      'totalEntries': 0,
      'wroteTodayDiary': false,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

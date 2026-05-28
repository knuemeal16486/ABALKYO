import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/class_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

/// 교사가 새 학급을 만들고 학급 코드를 받는 화면
class ClassCreationScreen extends StatefulWidget {
  const ClassCreationScreen({super.key});

  @override
  State<ClassCreationScreen> createState() => _ClassCreationScreenState();
}

class _ClassCreationScreenState extends State<ClassCreationScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _createdCode;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final code = await ClassService.createClass(
        teacherUid: 'teacher_${DateTime.now().millisecondsSinceEpoch}',
        className: name,
      );
      setState(() { _createdCode = code; });
    } catch (e) {
      setState(() { _error = 'Firebase 연결 오류: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppTheme.dawnGlow, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('새 학급 만들기',
                        style: TextStyle(
                            color: AppTheme.dawnGlow,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: _createdCode != null
                    ? _SuccessView(code: _createdCode!)
                    : _CreateForm(
                        nameCtrl: _nameCtrl,
                        loading: _loading,
                        error: _error,
                        onSubmit: _create,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  const _CreateForm({
    required this.nameCtrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧑‍🏫',
              style: TextStyle(fontSize: 52)),
          const SizedBox(height: 20),
          const Text(
            '학급을 만들면 6자리 코드를\n학생들과 공유하세요.',
            style: TextStyle(
                color: AppTheme.dawnGlow, fontSize: 17, height: 1.5),
          ),
          const SizedBox(height: 36),
          Text('학급 이름',
              style: TextStyle(
                  color: AppTheme.textSubtle,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: TextField(
              controller: nameCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style:
                  const TextStyle(color: AppTheme.dawnGlow, fontSize: 16),
              decoration: const InputDecoration(
                hintText: '예) 3학년 2반',
                hintStyle: TextStyle(color: AppTheme.textSubtle),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!,
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13)),
          ],
          const Spacer(),
          GestureDetector(
            onTap: loading ? null : onSubmit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.softMoss, AppTheme.lightForest]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.softMoss.withValues(alpha: 0.45),
                      blurRadius: 18),
                ],
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppTheme.softCloud)),
                      )
                    : const Text('학급 코드 생성',
                        style: TextStyle(
                            color: AppTheme.softCloud,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String code;
  const _SuccessView({required this.code});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Center(
              child: Text('🎉', style: TextStyle(fontSize: 64))),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '학급 코드가 생성되었어요!',
              style: TextStyle(
                  color: AppTheme.dawnGlow,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              '학생들에게 아래 코드를 알려주세요.',
              style: TextStyle(color: AppTheme.textSubtle, fontSize: 14),
            ),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.softMoss.withValues(alpha: 0.4), width: 2),
            ),
            child: Column(
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    color: AppTheme.dawnGlow,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('코드 $code 를 복사했어요'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppTheme.softMoss,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.softMoss.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.softMoss.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded,
                            color: AppTheme.softMoss, size: 16),
                        SizedBox(width: 8),
                        Text('코드 복사',
                            style: TextStyle(
                                color: AppTheme.softMoss,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.softMoss, AppTheme.lightForest]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text('완료',
                    style: TextStyle(
                        color: AppTheme.softCloud,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

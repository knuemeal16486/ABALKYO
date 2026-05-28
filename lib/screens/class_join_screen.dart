import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

/// 학생이 교사로부터 받은 6자리 학급 코드를 입력해 수업에 참여하는 화면
class ClassJoinScreen extends StatefulWidget {
  /// true이면 온보딩 플로우 안에서 사용 — 완료 시 pop 대신 아무것도 하지 않음
  final bool fromOnboarding;
  const ClassJoinScreen({super.key, this.fromOnboarding = false});

  @override
  State<ClassJoinScreen> createState() => _ClassJoinScreenState();
}

class _ClassJoinScreenState extends State<ClassJoinScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = '코드를 입력해주세요 (4-6자리)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await context.read<AppProvider>().joinClass(code);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 $code 학급에 참여했어요!'),
          backgroundColor: AppTheme.softMoss,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() {
        _error = '학급 코드를 찾을 수 없어요. 교사에게 다시 확인해보세요.';
        _loading = false;
      });
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppTheme.dawnGlow, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('수업 참여',
                        style: TextStyle(
                            color: AppTheme.dawnGlow,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🏫',
                          style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 20),
                      const Text(
                        '선생님께 받은 학급 코드를\n입력하면 수업에 참여할 수 있어요.',
                        style: TextStyle(
                            color: AppTheme.dawnGlow,
                            fontSize: 17,
                            height: 1.5),
                      ),
                      const SizedBox(height: 36),
                      Text('학급 코드',
                          style: TextStyle(
                              color: AppTheme.textSubtle,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20)),
                        ),
                        child: TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          onSubmitted: (_) => _join(),
                          onChanged: (_) => setState(() => _error = null),
                          style: const TextStyle(
                            color: AppTheme.dawnGlow,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: 'ABC123',
                            hintStyle: TextStyle(
                                color: AppTheme.textSubtle,
                                fontSize: 24,
                                letterSpacing: 4),
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(
                                color: Color(0xFFE57373), fontSize: 13)),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: _loading ? null : _join,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [
                                  AppTheme.softMoss,
                                  AppTheme.lightForest
                                ]),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppTheme.softMoss.withValues(alpha: 0.45),
                                  blurRadius: 18),
                            ],
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            AppTheme.softCloud)),
                                  )
                                : const Text('수업 참여',
                                    style: TextStyle(
                                        color: AppTheme.softCloud,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!widget.fromOnboarding)
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              '나중에 참여할게요',
                              style: TextStyle(
                                  color: AppTheme.textSubtle, fontSize: 13),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

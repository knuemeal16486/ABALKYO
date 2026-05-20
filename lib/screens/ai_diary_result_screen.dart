import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

/// 일기 제출 직후 AI가 만든 그림일기(그림 + 서술/공감 답글)를 보여준다.
class AiDiaryResultScreen extends StatefulWidget {
  final String entryId;
  final String childName;
  final String emotionLabel;
  final String diaryText;
  final String? childPhotoPath;

  const AiDiaryResultScreen({
    super.key,
    required this.entryId,
    required this.childName,
    required this.emotionLabel,
    required this.diaryText,
    this.childPhotoPath,
  });

  @override
  State<AiDiaryResultScreen> createState() => _AiDiaryResultScreenState();
}

class _AiDiaryResultScreenState extends State<AiDiaryResultScreen> {
  bool _loading = true;
  String? _narration;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final provider = context.read<AppProvider>();
    final svc = AiService(provider.apiKey);
    try {
      final narrationFuture = svc.generateDiaryNarration(
        childName: widget.childName,
        emotionLabel: widget.emotionLabel,
        diaryText: widget.diaryText,
      );
      final imageFuture = svc.generateIllustration(
        emotionLabel: widget.emotionLabel,
        diaryText: widget.diaryText,
      );
      final narration = await narrationFuture;
      final img = await imageFuture;
      await provider.attachAiResult(widget.entryId,
          narration: narration, imageBytes: img);
      if (!mounted) return;
      setState(() {
        _narration = narration;
        _imageBytes = img;
        _loading = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1F14), Color(0xFF1B3A2D)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      const Text('🎨', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      const Text('오늘의 그림일기',
                          style: TextStyle(
                              color: AppTheme.dawnGlow,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? _buildLoading()
                      : (_error != null ? _buildError() : _buildResult()),
                ),
                _buildBottomButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.15, duration: 900.ms),
          const SizedBox(height: 20),
          const Text('정원지기가 너의 하루를\n그림일기로 담고 있어요...',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.dawnGlow, fontSize: 16, height: 1.6)),
          const SizedBox(height: 20),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppTheme.softMoss)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌧', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.dawnGlow, fontSize: 15, height: 1.6)),
            const SizedBox(height: 8),
            Text('일기는 잘 저장되었고 식물도 무럭무럭 자랐어요 🌱',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final aiImage = _imageBytes;
    final childPhoto = widget.childPhotoPath;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (aiImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(aiImage, fit: BoxFit.cover),
            ).animate().fadeIn(duration: 500.ms).scale(
                begin: const Offset(0.95, 0.95), duration: 500.ms)
          else if (childPhoto != null && File(childPhoto).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(childPhoto), fit: BoxFit.cover),
            )
          else
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.softMoss.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                  child: Text('🌼', style: TextStyle(fontSize: 48))),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: AppTheme.softMoss.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text('정원지기의 한마디',
                        style: TextStyle(
                            color: AppTheme.textSubtle,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_narration ?? '',
                    style: const TextStyle(
                        color: AppTheme.dawnGlow, fontSize: 15, height: 1.8)),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: GestureDetector(
        onTap: _loading ? null : () => Navigator.pop(context),
        child: Opacity(
          opacity: _loading ? 0.4 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.softMoss, AppTheme.lightForest]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(
              child: Text('정원으로 돌아가기',
                  style: TextStyle(
                      color: AppTheme.softCloud,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

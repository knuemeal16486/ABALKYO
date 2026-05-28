import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../widgets/diary_wizard.dart';
import 'ai_diary_result_screen.dart';

class DiaryScreen extends StatefulWidget {
  final VoidCallback? onSubmit;
  const DiaryScreen({super.key, this.onSubmit});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool _saving = false;

  Future<void> _handleComplete(
      String emotion, String text, String? photoPath) async {
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<AppProvider>();
    final entry = await provider.addDiaryEntry(
      emotion,
      text,
      sourcePhotoPath: photoPath,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (provider.aiEnabled) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AiDiaryResultScreen(
          entryId: entry.id,
          childName: provider.studentName,
          emotionLabel: Emotions.labelOf(emotion),
          diaryText: text,
          childPhotoPath: entry.imageUrl,
        ),
      ));
    }

    widget.onSubmit?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1F14),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF81C784)),
          ),
        ),
      );
    }

    return DiaryWizard(
      onComplete: _handleComplete,
      onCancel: () => widget.onSubmit?.call(),
    );
  }
}

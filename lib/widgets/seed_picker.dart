import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

/// 5종 식물 씨앗 중 하나를 고르는 카드 그리드. 온보딩·수확 후 재사용.
class SeedPicker extends StatelessWidget {
  final PlantType? selected;
  final ValueChanged<PlantType> onSelect;
  const SeedPicker({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final types = PlantType.values;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: types.map((type) {
        final sp  = PlantDictionary.of(type);
        final sel = selected == type;
        return GestureDetector(
          onTap: () => onSelect(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: sel
                  ? AppTheme.softMoss.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: sel
                    ? AppTheme.softMoss
                    : Colors.white.withValues(alpha: 0.12),
                width: sel ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이모지 + 이름 + 체크
                Row(
                  children: [
                    Text(sp.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        sp.name,
                        style: TextStyle(
                          color: sel ? AppTheme.dawnGlow : AppTheme.textOnDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sel)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.softMoss, size: 17),
                  ],
                ),
                const SizedBox(height: 5),
                // 설명
                Text(
                  sp.description,
                  style: TextStyle(
                      color: AppTheme.textSubtle, fontSize: 10.5, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                // 해시태그
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: sp.tags.map((tag) => _TagChip(tag: tag, active: sel)).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final bool active;
  const _TagChip({required this.tag, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.softMoss.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? AppTheme.softMoss.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: active
              ? AppTheme.softMoss
              : AppTheme.textSubtle.withValues(alpha: 0.85),
          fontSize: 9.5,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

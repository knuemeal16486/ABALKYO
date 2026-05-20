import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

/// 4종 식물 씨앗 중 하나를 고르는 카드 그리드. 온보딩·수확 후 재사용.
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
      childAspectRatio: 1.45,
      children: types.map((type) {
        final sp = PlantDictionary.of(type);
        final sel = selected == type;
        return GestureDetector(
          onTap: () => onSelect(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
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
                Row(
                  children: [
                    Text(sp.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sp.name,
                        style: TextStyle(
                          color: sel ? AppTheme.dawnGlow : AppTheme.textOnDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (sel)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.softMoss, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    sp.description,
                    style: TextStyle(
                        color: AppTheme.textSubtle,
                        fontSize: 11,
                        height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

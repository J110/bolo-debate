import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/home/presentation/providers/data_providers.dart';

class RegionChips extends ConsumerWidget {
  const RegionChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(regionsProvider);
    final selectedRegion = ref.watch(selectedRegionProvider);

    return regionsAsync.when(
      data: (regions) {
        return SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: regions.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // All regions chip
                final isSelected = selectedRegion == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.public,
                          size: 16,
                          color: isSelected ? AppColors.primary : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        const Text('All'),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(selectedRegionProvider.notifier).setRegion(null);
                    },
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }

              final region = regions[index - 1];
              final isSelected = selectedRegion == region.id;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: isSelected ? AppColors.primary : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(region.name),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(selectedRegionProvider.notifier).setRegion(
                        isSelected ? null : region.id);
                  },
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox(height: 36),
    );
  }
}

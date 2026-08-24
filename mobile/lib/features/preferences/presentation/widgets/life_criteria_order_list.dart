import 'package:flutter/material.dart';

import '../../domain/life_criteria.dart';

class LifeCriteriaOrderList extends StatelessWidget {
  const LifeCriteriaOrderList({
    required this.categoryOrder,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<String> categoryOrder;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (categoryOrder.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Bu persona için yaşam kriterleri yüklenemedi.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Yaşam kriterleri ve önem sırası',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Seçtiğin profile göre başlangıç sırası hazırlandı. '
          'En önemli kriteri yukarı taşı.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: categoryOrder.length,
          onReorderItem:
              enabled
                  ? (oldIndex, newIndex) {
                    final reordered = List<String>.of(categoryOrder);
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    onChanged(List.unmodifiable(reordered));
                  }
                  : (_, _) {},
          itemBuilder: (context, index) {
            final code = categoryOrder[index];
            final importance = lifeCriterionImportancePercent(
              index,
              categoryOrder.length,
            );

            return Card(
              key: ValueKey('life-criterion-$code'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(radius: 18, child: Text('${index + 1}')),
                title: Text(
                  lifeCriterionLabel(code),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Göreli önem: %$importance'),
                trailing: ReorderableDragStartListener(
                  key: ValueKey('life-criterion-drag-$code'),
                  index: index,
                  enabled: enabled,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../core/models/models.dart';
import '../../../auth/application/session_controller.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';

class AnchorManagerPage extends StatefulWidget {
  const AnchorManagerPage({
    required this.controller,
    this.onFinished,
    this.embedded = false,
    super.key,
  });

  final SessionController controller;
  final VoidCallback? onFinished;
  final bool embedded;

  @override
  State<AnchorManagerPage> createState() => _AnchorManagerPageState();
}

class _AnchorManagerPageState extends State<AnchorManagerPage> {
  late List<Anchor> _anchors;
  Geographic? _pendingPoint;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anchors = [...?widget.controller.profile?.anchors];
  }

  Future<void> _selectPoint(double lat, double lon) async {
    if (_anchors.length >= 3 || _busy) return;
    final point = Geographic(lon: lon, lat: lat);
    setState(() => _pendingPoint = point);

    final draft = await showModalBottomSheet<_AnchorDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AnchorFormSheet(),
    );
    if (!mounted) return;
    if (draft == null) {
      setState(() => _pendingPoint = null);
      return;
    }

    await _run(() async {
      await widget.controller.createAnchor(
        label: draft.label,
        lat: lat,
        lon: lon,
        mode: draft.mode,
      );
      _syncFromProfile();
      _pendingPoint = null;
    });
  }

  Future<void> _delete(Anchor anchor) async {
    await _run(() async {
      await widget.controller.deleteAnchor(anchor.id);
      _syncFromProfile();
    });
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_busy) return;
    final previous = [..._anchors];
    final next = [..._anchors];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    next.replaceRange(
      0,
      next.length,
      next.indexed.map((item) => item.$2.copyWith(priority: item.$1 + 1)),
    );
    setState(() => _anchors = next);

    await _run(() async {
      _anchors = await widget.controller.reorderAnchors(
        next.map((anchor) => anchor.id).toList(),
      );
    }, onError: () => _anchors = previous);
  }

  Future<void> _run(
    Future<void> Function() operation, {
    VoidCallback? onError,
  }) async {
    setState(() => _busy = true);
    try {
      await operation();
    } on Object catch (error) {
      onError?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.controller.describeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _syncFromProfile() {
    _anchors = [...?widget.controller.profile?.anchors];
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: !widget.embedded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedded) ...[
              Text(
                'Önemli konumların',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Haritaya dokunup en fazla 3 yer ekle. Listeyi sürükleyerek '
                'önem sırasını değiştirebilirsin.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CankayaMap(
                      anchors: _anchors,
                      pendingPoint: _pendingPoint,
                      onMapTap: _anchors.length >= 3 ? null : _selectPoint,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          _anchors.length >= 3
                              ? '3/3 konum · listeyi sıralayabilirsin'
                              : '${_anchors.length}/3 konum · eklemek için haritaya dokun',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  if (_busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x33000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 4,
              child: _anchors.isEmpty
                  ? const _EmptyAnchors()
                  : ReorderableListView.builder(
                      itemCount: _anchors.length,
                      onReorderItem: _reorder,
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, index) {
                        final anchor = _anchors[index];
                        return _AnchorTile(
                          key: ValueKey(anchor.id),
                          anchor: anchor,
                          weight: _anchorWeights(_anchors.length)[index],
                          index: index,
                          onDelete: _busy ? null : () => _delete(anchor),
                        );
                      },
                    ),
            ),
            if (widget.onFinished != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : widget.onFinished,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_anchors.isEmpty ? 'Şimdilik geç' : 'Haritaya geç'),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Önemli konumlar')),
      body: content,
    );
  }
}

class _AnchorFormSheet extends StatefulWidget {
  const _AnchorFormSheet();

  @override
  State<_AnchorFormSheet> createState() => _AnchorFormSheetState();
}

class _AnchorFormSheetState extends State<_AnchorFormSheet> {
  final _labelController = TextEditingController();
  String _mode = 'car';

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    Navigator.of(context).pop(_AnchorDraft(label: label, mode: _mode));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bu konum nedir?',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Etiket',
              hintText: 'Örn. Ofis, okul, spor salonu',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'car',
                icon: Icon(Icons.directions_car_outlined),
                label: Text('Araçla'),
              ),
              ButtonSegment(
                value: 'foot',
                icon: Icon(Icons.directions_walk),
                label: Text('Yürüyerek'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _submit, child: const Text('Konumu ekle')),
        ],
      ),
    );
  }
}

class _AnchorTile extends StatelessWidget {
  const _AnchorTile({
    required this.anchor,
    required this.weight,
    required this.index,
    required this.onDelete,
    super.key,
  });

  final Anchor anchor;
  final double weight;
  final int index;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            '${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          anchor.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${anchor.mode == 'car' ? 'Araçla' : 'Yürüyerek'} · ağırlık ${weight.toStringAsFixed(3)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Sil',
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAnchors extends StatelessWidget {
  const _EmptyAnchors();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_location_alt_outlined,
          size: 42,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        const Text(
          'Henüz konum eklemedin.\nHaritada bir noktaya dokun.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _AnchorDraft {
  const _AnchorDraft({required this.label, required this.mode});

  final String label;
  final String mode;
}

List<double> _anchorWeights(int count) {
  if (count <= 0) return const [];
  final raw = List<double>.generate(count, (index) => 1 / (1 << index));
  final sum = raw.fold<double>(0, (total, item) => total + item);
  return raw.map((item) => item / sum).toList();
}

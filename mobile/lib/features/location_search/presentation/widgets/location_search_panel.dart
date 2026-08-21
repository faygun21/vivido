import 'package:flutter/material.dart';

import '../../application/location_search_controller.dart';
import '../../domain/location_search_models.dart';

class LocationSearchPanel extends StatefulWidget {
  const LocationSearchPanel({
    required this.controller,
    required this.onSelected,
    required this.onCleared,
    super.key,
  });

  final LocationSearchController controller;
  final ValueChanged<LocationSearchResult> onSelected;
  final VoidCallback onCleared;

  @override
  State<LocationSearchPanel> createState() => _LocationSearchPanelState();
}

class _LocationSearchPanelState extends State<LocationSearchPanel> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _textController.clear();
    _focusNode.unfocus();
    widget.controller.clear();
    widget.onCleared();
  }

  void _select(LocationSearchResult result) {
    _focusNode.unfocus();
    widget.controller.select(result);
    widget.onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !state.loading,
                textInputAction: TextInputAction.search,
                maxLength: 200,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onSubmitted: state.search,
                decoration: InputDecoration(
                  hintText: 'Mahalle, adres veya konum ara',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_textController.text.isNotEmpty ||
                          state.selected != null)
                        IconButton(
                          tooltip: 'Aramayı temizle',
                          onPressed: _clear,
                          icon: const Icon(Icons.close),
                        ),
                      IconButton.filled(
                        tooltip: 'Ara',
                        onPressed: state.loading
                            ? null
                            : () => state.search(_textController.text),
                        icon: state.loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (state.errorMessage != null)
              _MessageCard(
                message: state.errorMessage!,
                color: Theme.of(context).colorScheme.errorContainer,
              ),
            if (state.searched &&
                state.results.isEmpty &&
                state.errorMessage == null)
              const _MessageCard(
                message: 'Çankaya sınırları içinde sonuç bulunamadı.',
              ),
            if (state.results.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 6),
                elevation: 5,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: state.results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = state.results[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(_kindIcon(result.kind)),
                        title: Text(
                          result.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_sourceLabel(result.source)),
                        onTap: () => _select(result),
                      );
                    },
                  ),
                ),
              ),
            if (state.selected != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InputChip(
                    avatar: const Icon(Icons.my_location, size: 18),
                    label: Text(
                      state.selected!.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: _clear,
                  ),
                ),
              ),
            if (state.results.isNotEmpty && state.attribution.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 4),
                child: Text(
                  state.attribution,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.color});

  final String message;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 6),
    color: color,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(message),
    ),
  );
}

IconData _kindIcon(String kind) => switch (kind) {
  'neighborhood' => Icons.holiday_village_outlined,
  'address' => Icons.location_on_outlined,
  _ => Icons.place_outlined,
};

String _sourceLabel(String source) => switch (source) {
  'local' => 'Vivido mahalle verisi',
  'photon' => 'Photon · OpenStreetMap',
  'nominatim' => 'Nominatim · OpenStreetMap',
  _ => 'OpenStreetMap',
};

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../application/location_search_controller.dart';
import '../../domain/location_search_models.dart';

/// Harita üstündeki adres/mahalle arama çubuğu (R-20).
///
/// ⚠️ NELER DEĞİŞTİ
///
/// 1. **Yüzey camlaştı.** Opak beyaz bir `Material(elevation: 5)` idi ve
///    haritaya yapıştırılmış gibi duruyordu.
///
/// 2. **İki düğme bire indi.** Sağda hem "temizle" (✕) hem "ara" (→ dolu
///    yuvarlak) vardı: 52 px'lik bir çubuğun sağ yarısı düğmeydi ve
///    yazılan metin sıkışıyordu. Arama zaten klavyenin "ara" tuşuyla ve
///    yazmayı bırakınca tetikleniyor; ayrı bir düğme gereksiz.
///
/// 3. **Sonuç listesi yüzen bir panel oldu.** `Card` olarak çubuğun altına
///    yapışıyordu; artık kendi gölgesiyle onun ÜSTÜNDE duruyor.
///
/// 4. **Sabit yükseklik.** Çubuk artık [AppSpacing.mapSearchHeight]
///    kadar — altındaki kontrol sırası bu ölçüye göre iniyor. Eskiden
///    yüksekliği içeriğe göre değişiyor ve altındaki düğmeler kimi zaman
///    üstüne biniyordu.
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
    _focusNode = FocusNode()..addListener(() => setState(() {}));
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
    setState(() {});
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
        final hasText = _textController.text.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: AppSpacing.mapSearchHeight,
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.sm),
                    // Yükleme göstergesi büyütecin YERİNE geçiyor, yanına
                    // değil: aynı yerde değişen bir simge, genişliği
                    // sabit tutuyor ve metin kaymıyor.
                    SizedBox.square(
                      dimension: 20,
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child:
                            state.loading
                                ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                )
                                : Icon(
                                  Icons.search,
                                  size: 20,
                                  color:
                                      _focusNode.hasFocus
                                          ? AppColors.accent
                                          : AppColors.inkMuted,
                                ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: !state.loading,
                        textInputAction: TextInputAction.search,
                        maxLength: 200,
                        style: AppType.sm,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        onSubmitted: state.search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Mahalle, cadde veya adres ara',
                          hintStyle: AppType.muted(AppType.sm),
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    if (hasText || state.selected != null)
                      IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: _clear,
                        icon: const Icon(Icons.close, size: 19),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      const SizedBox(width: AppSpacing.xs),
                  ],
                ),
              ),
            ),

            if (state.errorMessage case final message?)
              _Notice(message: message, error: true),

            if (state.searched &&
                state.results.isEmpty &&
                state.errorMessage == null)
              const _Notice(
                message: 'Çankaya sınırları içinde sonuç bulunamadı.',
              ),

            if (state.results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: state.results.length,
                      separatorBuilder:
                          (_, _) => const Divider(height: 1, indent: 44),
                      itemBuilder: (context, index) {
                        final result = state.results[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(_kindIcon(result.kind), size: 20),
                          title: Text(
                            result.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sm,
                          ),
                          subtitle: Text(
                            _sourceLabel(result.source),
                            style: AppType.muted(AppType.micro).copyWith(
                              letterSpacing: 0,
                            ),
                          ),
                          onTap: () => _select(result),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Seçili yer çipi ve kaynak atıfı YAN YANA: ikisi de birer
            // dipnot, alt alta iki satır olarak haritanın üstünde
            // gereksiz yer kaplıyordu.
            if (state.selected != null || state.attribution.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (state.selected case final selected?)
                      Flexible(
                        child: _SelectedChip(
                          label: selected.label,
                          onClear: _clear,
                        ),
                      ),
                    const Spacer(),
                    if (state.results.isNotEmpty &&
                        state.attribution.isNotEmpty)
                      Text(
                        state.attribution,
                        style: AppType.muted(AppType.micro).copyWith(
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => GlassSurface.thin(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    shadow: AppShadows.xs,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 14, color: AppColors.accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.xs.copyWith(fontWeight: AppType.medium),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close, size: 13, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.md),
      shadow: AppShadows.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.search_off,
              size: 17,
              color: error ? AppColors.bad : AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(message, style: AppType.xs)),
          ],
        ),
      ),
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

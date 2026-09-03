import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../auth/application/session_controller.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/data/api_location_search_gateway.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../location_search/presentation/widgets/location_search_panel.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/application/map_data_controller.dart';
import '../../../map_data/data/api_map_data_gateway.dart';
import '../../../map_data/presentation/widgets/map_layer_button.dart';

/// Önemli konum (anchor) yönetimi — R-19, R-20, R-21.
///
/// ⚠️ NELER DÜZELDİ
///
/// 1. **Sayaç şeridi arama sonuçlarının ALTINDA kalıyordu.** `left: 12,
///    top: 74` konumundaki beyaz kutu, arama açılır listesinin tam
///    üstüne denk geliyor ve dokunuşları yakalıyordu. Artık haritanın
///    ALTINDA, listenin başlığı olarak.
///
/// 2. **Harita yüksekliği ekranın %56'sıydı ve `clamp(280, 560)`.** Küçük
///    telefonlarda liste görünmüyor, büyük telefonlarda harita ekranın
///    çoğunu yiyordu. Artık boş/dolu duruma göre: konum yokken harita
///    büyük (seçim yapılacak), konumlar eklendikçe küçülüyor (liste
///    öne çıkıyor).
///
/// 3. **Her anchor'ın yanında uydurma bir "ağırlık" yüzdesi vardı**
///    ("%57" — "skorun %57'si buraya bakıyor" izlenimi veriyordu).
///    Backend anchor'ları hiç puanlamıyor, yalnızca coğrafi bir koridor
///    filtresi olarak kullanıyor (bkz. K-18, docs/02-KARARLAR.md) — bu
///    yüzde tamamen yerel/kurgusal bir hesaptı, kaldırıldı. Aynı sebeple
///    "nasıl gidiyorsun?" (araçla/yürüyerek) sorusu da kayıt formundan
///    kaldırıldı — koridor hesabı her bacak için bunu gerçek yol
///    tarifiyle kendisi belirliyor.
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

  /// ⚠️ Bu harita eskiden BOMBOŞTU: ne konut ne POI ne arama vardı.
  /// Kullanıcı, hiçbir referans noktası olmayan gri bir yüzeyde rastgele
  /// bir yere dokunuyormuş gibi hissediyordu. Oysa "önemli konum" seçmek
  /// tam olarak çevreye bakarak yapılan bir iş.
  late final MapDataController _mapData;
  late final LocationSearchController _search;
  LocationSearchResult? _focus;

  static const _maxAnchors = 3;

  @override
  void initState() {
    super.initState();
    _anchors = [...?widget.controller.profile?.anchors];
    _mapData = MapDataController(
      gateway: ApiMapDataGateway(widget.controller.client),
      authenticated: true,
    );
    _mapData.initialize();
    _search = LocationSearchController(
      ApiLocationSearchGateway(widget.controller.client),
    );
  }

  @override
  void dispose() {
    _mapData.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _isFull => _anchors.length >= _maxAnchors;

  Future<void> _selectPoint(double lat, double lon) async {
    if (_isFull || _busy) return;
    final point = Geographic(lon: lon, lat: lat);
    setState(() => _pendingPoint = point);

    final draft = await showAppSheet<_AnchorDraft>(
      context,
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
        showAppSnack(
          context,
          widget.controller.describeError(error),
          tone: SnackTone.error,
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
    // Harita yüksekliği duruma göre: hiç konum yokken seçim yapılacak, o
    // yüzden büyük; konumlar eklendikçe liste öne çıkıyor.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final mapHeight = (screenHeight * (_anchors.isEmpty ? 0.52 : 0.40)).clamp(
      260.0,
      460.0,
    );

    final content = SafeArea(
      top: !widget.embedded,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Düzenli gittiğin yerler', style: AppType.h1),
                  const SizedBox(height: 4),
                  Text(
                    'İş, okul, spor salonu… En fazla üç yer ekle. En üste '
                    'koyduğun en önemlisi olur — gösterilen evler öncelikle '
                    'oraya gerçekten ulaşılabilir olup olmadığına göre '
                    'daraltılır.',
                    style: AppType.muted(AppType.sm),
                  ),
                ],
              ),
            ),

          // ── Harita ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: SizedBox(
              height: mapHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _mapData,
                      builder:
                          (context, _) => CankayaMap(
                            rounded: true,
                            anchors: _anchors,
                            pendingPoint: _pendingPoint,
                            focus: _focus,
                            // Konut ve POI'ler burada da çiziliyor:
                            // kullanıcı önemli konumu ÇEVRESİNİ görerek
                            // seçsin.
                            pois: _mapData.pois,
                            properties: _mapData.properties,
                            onBoundsChanged: _mapData.updateViewport,
                            onMapTap: _isFull ? null : _selectPoint,
                          ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.mapGutter,
                    right: AppSpacing.mapGutter,
                    top: AppSpacing.mapGutter,
                    child: LocationSearchPanel(
                      controller: _search,
                      onSelected: (result) => setState(() => _focus = result),
                      onCleared: () => setState(() => _focus = null),
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.mapGutter,
                    top:
                        AppSpacing.mapGutter +
                        AppSpacing.mapSearchHeight +
                        AppSpacing.mapStack,
                    child: MapLayerButton(controller: _mapData),
                  ),
                  if (_busy)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: ColoredBox(
                          color: AppMaterials.scrim,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Durum + liste ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AnchorCounter(count: _anchors.length, max: _maxAnchors),
                const SizedBox(height: AppSpacing.sm),

                if (_anchors.isEmpty)
                  const EmptyState(
                    icon: Icons.add_location_alt_outlined,
                    title: 'Henüz konum eklemedin',
                    message:
                        'Haritada düzenli gittiğin bir noktaya dokun — '
                        'işin, okulun ya da spor salonun.',
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    // Sayfa zaten kayıyor; iki kaydırma iç içe geçseydi
                    // sürükleyerek sıralama ile sayfa kaydırma birbirine
                    // karışırdı.
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _anchors.length,
                    onReorderItem: _reorder,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final anchor = _anchors[index];
                      return _AnchorTile(
                        key: ValueKey(anchor.id),
                        anchor: anchor,
                        index: index,
                        onDelete: _busy ? null : () => _delete(anchor),
                      );
                    },
                  ),

                if (widget.onFinished != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _busy ? null : widget.onFinished,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(
                      _anchors.isEmpty ? 'Şimdilik geç' : 'Haritaya geç',
                    ),
                  ),
                  if (_anchors.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Konum eklemeden de devam edebilirsin; skorlar '
                        'yalnızca personana göre hesaplanır.',
                        textAlign: TextAlign.center,
                        style: AppType.muted(AppType.micro).copyWith(
                          letterSpacing: 0,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Önemli konumlar')),
      body: content,
    );
  }
}

/// "2 / 3 konum" sayacı — dolulukla birlikte ne yapılacağını da söyler.
class _AnchorCounter extends StatelessWidget {
  const _AnchorCounter({required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final full = count >= max;
    return Row(
      children: [
        for (var index = 0; index < max; index++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.easeOut,
              width: index < count ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index < count ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            full
                ? '$count/$max konum · sırayı sürükleyerek değiştir'
                : '$count/$max konum · eklemek için haritaya dokun',
            style: AppType.muted(AppType.xs),
          ),
        ),
      ],
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
  // Kullanıcıya artık ulaşım şekli sorulmuyor — koridor hesabı her bacak
  // için gerçek yol tarifiyle bunu kendisi belirliyor (bkz. backend
  // PropertiesController.BuildCorridorLegsAsync: önce yaya, olmazsa araç).
  // Backend sözleşmesi değişmedi (`mode` hâlâ zorunlu alan), bu yüzden
  // sabit bir değer gönderiliyor.
  static const _mode = 'car';

  /// Hazır etiketler — kullanıcıların %90'ı bu üçünden birini yazıyor ve
  /// klavye açıp yazmak, haritada nokta seçmekten daha uzun sürüyordu.
  static const _suggestions = ['İş yerim', 'Okul', 'Spor salonu', 'Aile evi'];

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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              title: 'Bu konum nedir?',
              subtitle: 'Adı yalnızca sana görünür; skor hesabında kullanılmaz.',
            ),
            TextField(
              controller: _labelController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Etiket',
                prefixIcon: Icon(Icons.place_outlined, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () {
                      _labelController.text = suggestion;
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              // Etiket boşken kapalı: boş bir etiketle kaydedip sonra
              // "İsimsiz konum" göstermek yerine, kaydı engelliyoruz.
              onPressed:
                  _labelController.text.trim().isEmpty ? null : _submit,
              child: const Text('Konumu ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorTile extends StatelessWidget {
  const _AnchorTile({
    required this.anchor,
    required this.index,
    required this.onDelete,
    super.key,
  });

  final Anchor anchor;
  final int index;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 10, 4, 10),
          child: Row(
            children: [
              // Numara haritadaki pinle AYNI: kullanıcı listedeki 1'in
              // haritadaki hangi pin olduğunu eşleştirebiliyor.
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '${index + 1}',
                  style: AppType.micro.copyWith(
                    color: Colors.white,
                    letterSpacing: 0,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anchor.label,
                      style: AppType.sm.copyWith(fontWeight: AppType.semibold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 19),
                tooltip: 'Sil',
                visualDensity: VisualDensity.compact,
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: AppColors.line,
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

class _AnchorDraft {
  const _AnchorDraft({required this.label, required this.mode});

  final String label;
  final String mode;
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';

/// Maskotun duruşu — web'deki üç görselin karşılığı.
///
/// Duruş, maskotun yaslanacak bir KENARI olup olmadığına göre seçiliyor.
/// Web'de bu "panel açık mı" sorusuydu; mobilde "bir yüzeyin üstünde mi
/// duruyor" sorusu. Duvara tutunan görseli boşlukta göstermek, maskotu
/// görünmez bir duvara asılı bırakıyor.
enum MascotPose {
  /// Ayakta — boş durumlar, karşılama.
  standing,

  /// Yüzeyden sarkan — alt sayfanın/şeridin üst kenarında.
  peeking,

  /// Duvara tutunan — geniş bir panelin kenarında.
  wall,
}

/// Vivido maskotu. `web/public/mascot*.png`'nin kopyaları.
class MascotFigure extends StatefulWidget {
  const MascotFigure({
    this.height = 76,
    this.pose = MascotPose.standing,
    this.onTap,
    super.key,
  });

  final double height;
  final MascotPose pose;
  final VoidCallback? onTap;

  @override
  State<MascotFigure> createState() => _MascotFigureState();
}

class _MascotFigureState extends State<MascotFigure> {
  bool _pressed = false;

  String get _asset => switch (widget.pose) {
    MascotPose.standing => 'assets/mascot/mascot.png',
    MascotPose.peeking => 'assets/mascot/mascot_2.png',
    MascotPose.wall => 'assets/mascot/mascot_on_the_wall.png',
  };

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      height: widget.height,
      fit: BoxFit.contain,
      semanticLabel: 'Vivido rehberi',
    );

    if (widget.onTap == null) return image;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        // Maskot dokunulabilir olduğunu HAREKETLE söyler.
        scale: _pressed ? 0.94 : 1,
        duration: AppMotion.instant,
        curve: AppMotion.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppShadows.tint.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: image,
        ),
      ),
    );
  }
}

/// Rehber turunun tek adımı.
class TourStep {
  const TourStep({
    required this.text,
    this.title,
    this.targetKey,
    this.onEnter,
  });

  final String? title;
  final String text;

  /// Vurgulanacak arayüz öğesi. Verilmezse adım ekranın ortasında,
  /// vurgu deliği olmadan gösterilir (giriş ve kapanış adımları böyle).
  final GlobalKey? targetKey;

  /// Adım gösterilmeden hemen önce çalışır — hedef öğenin görünür olması
  /// için bir sekme açmak ya da bir paneli genişletmek gerekiyorsa.
  final VoidCallback? onEnter;
}

/// Maskotlu rehber turu.
///
/// Web'deki `GuideMascot` bileşeninin mobil karşılığı; aynı adım yapısı,
/// aynı ilerleme çubuğu, aynı "geç / geri / ileri" davranışı.
///
/// ⚠️ WEBDEN AYRILDIĞI YER: VURGU
///
/// Web, hedef öğenin DOM stilini geçici olarak değiştirip turuncu bir
/// `outline` basıyor ve bittiğinde eski değerleri geri yazıyor. Flutter'da
/// bir widget'ın stiline dışarıdan dokunulamaz — ve dokunulabilseydi de
/// istemezdik: geri yazma mantığı web tarafında zaten kırılgan (altı ayrı
/// stil özelliğini elle saklıyor).
///
/// Bunun yerine hedefin EKRANDAKİ DİKDÖRTGENİ ölçülüp karartma katmanında
/// bir DELİK açılıyor. Hedef kendi çizimiyle görünür kalıyor, gerisi
/// kararıyor — hem daha okunur hem hedef widget'a hiç dokunmuyor.
class GuideTour extends StatefulWidget {
  const GuideTour({
    required this.steps,
    required this.onFinished,
    this.mascotPose = MascotPose.peeking,
    this.bottomInset = 0,
    super.key,
  });

  final List<TourStep> steps;

  /// Tur tamamlandığında ya da atlandığında — çağıran taraf bayrağı yazar.
  final VoidCallback onFinished;

  final MascotPose mascotPose;

  /// Alt menü/şeridin yüksekliği: maskot onun üstünde dursun.
  final double bottomInset;

  @override
  State<GuideTour> createState() => _GuideTourState();
}

class _GuideTourState extends State<GuideTour> {
  int _index = 0;
  Rect? _targetRect;

  /// Ölçüm gecikmesi. ALAN olarak tutuluyor ki `dispose`'da iptal
  /// edilebilsin: `Future.delayed` iptal edilemiyor ve tur kapandıktan
  /// sonra bekleyen bir zamanlayıcı bırakıyordu.
  Timer? _measureTimer;

  TourStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _enterStep();
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    super.dispose();
  }

  /// Hedefin ekrandaki yerini ölçer.
  ///
  /// Ölçüm bir kare SONRA yapılmak zorunda: `onEnter` bir sekme değiştirmiş
  /// olabilir ve hedef widget henüz yerleşmemiştir. İki kare bekleniyor —
  /// sekme geçişi kendi animasyonunu başlatıyor ve ilk karede hedef hâlâ
  /// eski yerinde.
  void _enterStep() {
    final entered = _index;
    _step.onEnter?.call();

    // ⚠️ ESKİ DİKDÖRTGEN SİLİNMİYOR. Bir zamanlar burada
    // `_targetRect = null` vardı ve iki sorun üretiyordu: (1) her adımın
    // ilk karesinde delik kapanıp yeniden açılıyordu — göz hedefi
    // kaybediyordu, (2) `RectTween(end: null)` assert'i patlıyordu.
    // Delik eskisinden yenisine KAYARAK gidiyor.
    _measureTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureTimer = Timer(AppMotion.base, () {
        // Kullanıcı ölçüm beklenirken bir sonraki adıma geçmiş olabilir;
        // geç gelen ölçüm yeni adımın deliğini ezmesin.
        if (!mounted || _index != entered) return;
        setState(() => _targetRect = _measure(_step.targetKey));
      });
    });
  }

  Rect? _measure(GlobalKey? key) {
    final context = key?.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  void _next() {
    if (_isLast) {
      widget.onFinished();
      return;
    }
    setState(() => _index++);
    _enterStep();
  }

  void _back() {
    if (_index == 0) return;
    setState(() => _index--);
    _enterStep();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final rect = _targetRect;

    // Balon hedefin ALTINDA mı ÜSTÜNDE mi: hedef ekranın üst yarısındaysa
    // altına, alt yarısındaysa üstüne. Hedefin üstünü kapatan bir balon,
    // "şuraya bak" derken tam da orayı gizlemiş olurdu.
    //
    // Hedefi olmayan adımlarda (giriş/kapanış) balon ekranın ortasına yakın
    // duruyor — maskotun hemen üstünde, sanki o konuşuyormuş gibi.
    final double? anchorTop;
    final double? anchorBottom;
    if (rect == null) {
      anchorTop = size.height * 0.34;
      anchorBottom = null;
    } else if (rect.center.dy < size.height * 0.46) {
      anchorTop = rect.bottom;
      anchorBottom = null;
    } else {
      anchorTop = null;
      anchorBottom = size.height - rect.top;
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Karartma + hedef deliği. Dokunuşları YUTUYOR: tur sırasında
          // arkadaki haritayı kaydırmak, kullanıcının anlatılan şeyi
          // kaybetmesine yol açardı.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: AnimatedSpotlight(rect: rect),
            ),
          ),

          // Balon.
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: anchorTop == null ? null : anchorTop + AppSpacing.sm,
            bottom: anchorBottom == null ? null : anchorBottom + AppSpacing.sm,
            child: _TourBubble(
              step: _step,
              index: _index,
              total: widget.steps.length,
              onNext: _next,
              onBack: _back,
              onSkip: widget.onFinished,
            ),
          ),

          // Maskot — her zaman sol altta, alt menünün üstünde. Sabit
          // durması bilinçli: turun "konuşan" tarafı yer değiştirirse
          // kullanıcı her adımda onu yeniden aramak zorunda kalır.
          Positioned(
            left: AppSpacing.md,
            bottom: widget.bottomInset + media.padding.bottom + AppSpacing.sm,
            child: IgnorePointer(
              child: MascotFigure(height: 86, pose: widget.mascotPose),
            ),
          ),
        ],
      ),
    );
  }
}

/// Karartma katmanı ve içindeki hedef deliği.
///
/// Delik bir adımdan diğerine KAYARAK gidiyor: iki ayrı yerde bir açılıp
/// bir kapanan delik, kullanıcının gözünü kaybettiriyor. Kayan delik,
/// dikkati bir hedeften diğerine taşıyor.
class AnimatedSpotlight extends StatelessWidget {
  const AnimatedSpotlight({required this.rect, super.key});

  final Rect? rect;

  @override
  Widget build(BuildContext context) {
    // ⚠️ `rect` NULL OLABİLİR ve `TweenAnimationBuilder` bunu kabul etmez:
    // `RectTween(end: null)` → *"Tween provided to TweenAnimationBuilder
    // must have non-null Tween.end value"* assert'i.
    //
    // Null iki yerde geçerli bir durum: (1) hedefi olmayan adımlar
    // (giriş/kapanış), (2) her adımın ilk karesi — hedef ölçülene kadar
    // `_targetRect` bilerek sıfırlanıyor. Yani tur AÇILIR AÇILMAZ
    // patlıyordu.
    //
    // Delik yokken canlandıracak bir şey de yok: tam karartma doğrudan
    // çiziliyor.
    if (rect == null || MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(painter: _SpotlightPainter(rect), size: Size.infinite);
    }
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: rect),
      duration: AppMotion.slow,
      curve: AppMotion.easeOut,
      builder:
          (context, value, _) => CustomPaint(
            painter: _SpotlightPainter(value),
            size: Size.infinite,
          ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.rect);

  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = AppMaterials.scrim.withValues(alpha: 0.72);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final target = rect;

    if (target == null) {
      canvas.drawRect(full, scrim);
      return;
    }

    // Delik hedeften 6 px büyük: tam sınırında biten bir delik, hedefin
    // kenarını karartıya yapıştırıyor ve öğe kesilmiş gibi duruyor.
    final hole = RRect.fromRectAndRadius(
      target.inflate(6),
      const Radius.circular(AppRadius.md),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(hole),
      ),
      scrim,
    );

    // Deliğin kenarındaki vurgu halkası — hedefin sınırını çiziyor.
    canvas.drawRRect(
      hole,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.rect != rect;
}

class _TourBubble extends StatelessWidget {
  const _TourBubble({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Her adımda yeniden çalışsın diye anahtar adım numarasında.
      key: ValueKey(index),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      curve: AppMotion.spring,
      builder:
          (context, value, child) => Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.scale(
              // Balon SOL ALTTAN büyüyor — maskotun durduğu köşeden.
              // Merkezden büyüyen bir balon kimin konuştuğunu anlatmaz.
              alignment: Alignment.bottomLeft,
              scale: 0.9 + 0.1 * value,
              child: child,
            ),
          ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.lineSoft),
          boxShadow: AppShadows.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1} / $total',
                  style: AppType.micro.copyWith(
                    color: AppColors.accent,
                    fontFeatures: AppType.tabularFigures,
                  ),
                ),
                const Spacer(),
                InkResponse(
                  onTap: onSkip,
                  radius: 18,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (step.title != null) ...[
              Text(step.title!, style: AppType.h3),
              const SizedBox(height: 2),
            ],
            Text(step.text, style: AppType.muted(AppType.sm)),
            const SizedBox(height: AppSpacing.sm),

            // İlerleme çizgisi — kaç adım kaldığını "3 / 7" metnini
            // okumadan gösterir.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (index + 1) / total),
                duration: AppMotion.base,
                curve: AppMotion.easeOut,
                builder:
                    (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: AppColors.inputBg,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            Row(
              children: [
                if (index > 0)
                  TextButton(
                    onPressed: onBack,
                    child: const Text('Geri'),
                  )
                else
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkMuted,
                    ),
                    child: const Text('Geç'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  child: Text(index == total - 1 ? 'Tamamla' : 'İleri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

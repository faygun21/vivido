import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Basma anında hafifçe küçülen dokunma sarmalı.
///
/// ⚠️ GERİ BİLDİRİM BASMADA, BIRAKMADA DEĞİL
///
/// Material'ın dalgalanması (`InkWell`) bir kartın üstünde neredeyse
/// görünmez: dalgalanma yayılana kadar ~200 ms geçiyor ve kullanıcı o süre
/// boyunca dokunuşunun kaydedilip kaydedilmediğini bilmiyor. Ölçek
/// değişimi ANINDA (110 ms, `--dur-instant`) ve kartın tamamını kapsıyor.
///
/// Kaydırılabilir bir listenin içinde çalışması için `onTapDown` yerine
/// dikey sürüklemeye izin veren bir davranış gerekiyordu; `GestureDetector`
/// varsayılan olarak kaydırmayı üst kaydırıcıya bırakıyor, `onTapCancel`
/// da kaydırma başlayınca tetikleniyor — yani kullanıcı listeyi kaydırmaya
/// başladığında kart eski boyutuna dönüyor.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.975,
    this.enabled = true,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Basılıyken uygulanan ölçek. Büyük yüzey DAHA AZ küçülür: bir kartın
  /// %8 küçülmesi sıçrama gibi durur, bir çipin %8'i doğru hissettirir.
  final double scale;

  final bool enabled;

  /// Verilirse dokunma alanı bu yarıçapla kırpılır (odak halkası için).
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // "Hareketi azalt" açıkken ölçek yerine hafif bir opaklık değişimi:
    // geri bildirim KALKMIYOR, sadece vestibüler olmayan bir biçime
    // dönüşüyor (bkz. AppMotion / erişilebilirlik notu).
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget content = AnimatedScale(
      scale: _pressed && !reduceMotion ? widget.scale : 1,
      duration: AppMotion.instant,
      curve: AppMotion.easeOut,
      child: AnimatedOpacity(
        opacity: _pressed && reduceMotion ? 0.7 : 1,
        duration: AppMotion.instant,
        child: widget.child,
      ),
    );

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _active ? (_) => _set(true) : null,
      onTapUp: _active ? (_) => _set(false) : null,
      onTapCancel: _active ? () => _set(false) : null,
      onTap: _active ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: content,
    );
  }
}

/// Listeye giren öğeleri sırayla belirtir.
///
/// Hepsi aynı anda belirirse liste "patlıyor"; sırayla gelince göz en
/// üstteki öğeden başlayarak aşağı iniyor ve listenin bir SIRASI olduğu
/// anlaşılıyor (skora göre sıralı bir konut listesinde bu bilgi taşıyor).
///
/// Gecikme sekizinci öğeden sonra sabitleniyor — bkz. [AppMotion.stagger].
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    required this.index,
    required this.child,
    super.key,
  });

  final int index;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(AppMotion.stagger(widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.easeOut,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        // 10 px'lik kısa bir yol — daha uzunu, listeyi kaydırırken
        // öğelerin "uçuştuğu" hissini verir.
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

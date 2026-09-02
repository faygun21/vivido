import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';

/// Favori düğmesi — **kalp**.
///
/// ⚠️ İKİ FARKLI İŞARET, İKİSİ DE DOĞRU
///
/// Favoriye EKLEME eylemi kalp (bu düğme); HARİTADA favori evi işaretleyen
/// simge yıldız (bkz. `cankaya_map.dart` `favori-ikon` katmanı). Kasıtlı:
/// kalp bir eylem düğmesi ve alışılmış işareti bu; harita üstünde ise
/// kalp, kırmızı-turuncu konut pinleriyle aynı renk ailesine düşüyor ve
/// ayrışmıyor — altın bir yıldız uzaktan bile okunuyor.
///
/// ⚠️ İYİMSER GÜNCELLEME
///
/// Kalp, sunucu cevabını BEKLEMEDEN doluyor. Ağ turu 200–400 ms sürüyor ve
/// o süre boyunca boş bir kalbe bakmak dokunuşun kaydedilmediğini
/// düşündürüyor. İstek başarısız olursa kalp geri boşalıyor ve mesaj
/// gösteriliyor — çağıran taraf bunu `onChanged`'in dönüşüyle bildiriyor.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    required this.isFavorite,
    required this.onPressed,
    this.busy = false,
    this.size = 22,
    this.tooltip,
    super.key,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;
  final bool busy;
  final double size;
  final String? tooltip;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    // Önce hafif ÇÖKÜYOR (basma), sonra hedefin üstüne taşıyor, sonra
    // oturuyor. Taşma burada doğru: kullanıcının kendi dokunuşundan gelen
    // bir momentum var (bkz. AppMotion.spring notu).
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 18),
    TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.22), weight: 42),
    TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.linear));

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sıçrama yalnızca EKLERKEN. Çıkarma bir kayıp; kutlanacak bir şey yok
    // ve aynı canlandırma iki zıt anlamı taşıyamaz.
    if (!oldWidget.isFavorite && widget.isFavorite) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Dokunsal geri bildirim görsel değişimle AYNI karede: aralarındaki
    // gecikme, ikisinin aynı olaydan geldiği yanılsamasını bozar.
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.tooltip ??
        (widget.isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle');

    return IconButton(
      onPressed: widget.busy ? null : _handleTap,
      tooltip: label,
      iconSize: widget.size,
      icon:
          widget.busy
              ? SizedBox.square(
                dimension: widget.size * 0.8,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
              : ScaleTransition(
                scale: _scale,
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  transitionBuilder:
                      (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                  child: Icon(
                    widget.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    key: ValueKey(widget.isFavorite),
                    size: widget.size,
                    color:
                        widget.isFavorite
                            ? AppColors.accent
                            : AppColors.inkMuted,
                  ),
                ),
              ),
    );
  }
}

/// Detay sayfasındaki geniş favori düğmesi — ikon + metin.
///
/// Webdeki `.favorite-btn` ile aynı fikir: haritadaki küçük ikon düğmesi
/// bir eylemi ima ediyor, detay sayfasındaki tam genişlikte düğme onu
/// AÇIKÇA söylüyor ("Favorilerimde" / "Favorilere ekle").
class FavoriteWideButton extends StatelessWidget {
  const FavoriteWideButton({
    required this.isFavorite,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      decoration: BoxDecoration(
        color: isFavorite ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isFavorite ? AppColors.accentEdge : AppColors.border,
          width: isFavorite ? 1.5 : 1.25,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              busy
                  ? null
                  : () {
                    HapticFeedback.lightImpact();
                    onPressed?.call();
                  },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isFavorite ? AppColors.accent : AppColors.inkMuted,
                  ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  isFavorite ? 'Favorilerimde' : 'Favorilere ekle',
                  style: AppType.sm.copyWith(
                    fontWeight: AppType.semibold,
                    color: isFavorite ? AppColors.accent : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

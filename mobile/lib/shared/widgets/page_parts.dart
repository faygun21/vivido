import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import 'mascot.dart';

/// Sayfanın başındaki tek satırlık açıklama.
///
/// ⚠️ BAŞLIK TEKRAR ETMİYOR
///
/// Ekranlar `AppBar`da "Favorilerim" yazıp gövdenin ilk satırında yine
/// "Favorilerim" başlığı basıyordu — aynı kelime iki kez, üst üste, iki
/// farklı boyutta. Konutlar ("En uygun evler"), Rotalar ("Ziyaret rotası")
/// ve Favoriler'de aynı hata vardı ve ekranın ilk ekran boyu bir işe
/// yaramıyordu. Başlık artık YALNIZCA `AppBar`da; gövde doğrudan açıklamayla
/// başlıyor.
class PageIntro extends StatelessWidget {
  const PageIntro(this.text, {this.trailing, super.key});

  final String text;

  /// Açıklamanın sağında duran küçük eylem (ör. "Yenile").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(text, style: AppType.muted(AppType.sm))),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.xs), trailing!],
      ],
    ),
  );
}

/// Sayfa içi bölüm başlığı — büyük harfli mikro etiket + isteğe bağlı eylem.
///
/// Bölümler `titleLarge`/`headlineSmall` gibi yuvalara elle yazılıyordu ve
/// her ekranda farklı bir boyuttaydı. Versal mikro etiket, gövde metninden
/// BOYUTLA değil KARAKTERLE ayrışıyor: bölüm başlığı içeriğin önüne geçmiyor.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.action, this.count, super.key});

  final String title;
  final Widget? action;

  /// Başlığın yanındaki sayı (ör. kaç kayıtlı rota var).
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.lg,
      bottom: AppSpacing.xs,
    ),
    child: Row(
      children: [
        Text(title.toUpperCase(), style: AppType.micro),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              style: AppType.micro.copyWith(
                letterSpacing: 0,
                fontFeatures: AppType.tabularFigures,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (action != null) action!,
      ],
    ),
  );
}

/// Alt sayfa başlığı — ad, açıklama ve **kapatma düğmesi**.
///
/// ⚠️ ALT SAYFALARIN KAPATMA DÜĞMESİ YOKTU
///
/// Tek çıkış yolu sürükleme tutamacıydı. Katman paneli gibi uzun bir
/// sayfada tutamaç ekranın tepesine yakın duruyor ve oradan aşağı çekmek
/// telefonun BİLDİRİM PANELİNİ açıyordu — kullanıcı sayfayı kapatamıyordu.
///
/// Tutamaç duruyor (alışılmış hareket), yanına açık bir düğme eklendi.
class SheetHeader extends StatelessWidget {
  const SheetHeader({required this.title, this.subtitle, this.icon, super.key});

  final String title;
  final String? subtitle;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: AppSpacing.sm)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.h3),
              if (subtitle != null)
                Text(subtitle!, style: AppType.muted(AppType.xs)),
            ],
          ),
        ),
        // Dokunma hedefi tam 40 px: `visualDensity.compact` ile 32'ye
        // düşüyordu ve başlığın sağ üstündeki küçük bir ✕ ıskalanıyordu.
        SizedBox.square(
          dimension: 40,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Kapat',
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.inputBg,
              foregroundColor: AppColors.ink,
              shape: const CircleBorder(),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Uygulamadaki tüm alt sayfaların ortak açılışı.
///
/// ⚠️ `isScrollControlled: true` TEK BAŞINA TEHLİKELİ: içerik uzunsa sayfa
/// ekranın tepesine kadar çıkıyor, sürükleme tutamacı durum çubuğunun
/// dibine dayanıyor ve aşağı çekmek bildirim panelini açıyor. Tavan
/// %88'de: üstte kalan şerit hem "bu bir katman" diyor hem tutamacı
/// güvenli bir yükseklikte tutuyor.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxHeightFactor = 0.88,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
  ),
  builder: builder,
);

/// Boş durum.
///
/// ⚠️ BOŞ BİR LİSTE HATA DEĞİL
///
/// Ekranlar boş durumu gri bir `Icon` + tek cümleyle geçiştiriyordu
/// ("Henüz favori konutun yok."). Cümle doğru ama kullanıcıya NE YAPACAĞINI
/// söylemiyor. Boş durum bir çıkmaz değil, bir davet: her zaman bir sonraki
/// adımı gösteriyor.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.icon,
    this.action,
    this.showMascot = false,
    super.key,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Widget? action;

  /// Maskot yalnızca ürünün "sıcak" anlarında (ilk favori, ilk rota) —
  /// bir hata ekranında değil.
  final bool showMascot;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xxl,
    ),
    child: Column(
      children: [
        if (showMascot)
          const MascotFigure(height: 120, pose: MascotPose.standing)
        else if (icon != null)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.accent),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppType.h3, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          message,
          style: AppType.muted(AppType.sm),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[
          const SizedBox(height: AppSpacing.md),
          action!,
        ],
      ],
    ),
  );
}

/// Hata durumu — her zaman bir çıkış yolu ("Tekrar dene") ile.
///
/// Beş ekranda beş ayrı hata bloğu vardı (`_LoadError`, satır içi
/// `Center(Column(Text, FilledButton.tonal))`, düz `Text`…). Hepsi aynı işi
/// yapıyor, hiçbiri aynı görünmüyordu.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    required this.onRetry,
    this.title = 'Bir şeyler ters gitti',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.bad.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 26,
              color: AppColors.bad,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppType.h3, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppType.muted(AppType.sm),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tekrar dene'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Yükleniyor iskeleti.
///
/// ⚠️ DÖNEN ÇARK YERİNE İSKELET
///
/// Ekranların hepsi `CircularProgressIndicator` ile bekliyordu: ekran
/// bomboş, ortada bir çark, sonra içerik bir anda "patlıyor". İskelet
/// gelecek içeriğin ÖLÇÜSÜNÜ önceden gösteriyor — yükleme bitince sayfa
/// zıplamıyor ve bekleme daha kısa hissediliyor.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 4, this.itemHeight = 132, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.xs,
      AppSpacing.page,
      AppSpacing.xl,
    ),
    itemCount: itemCount,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, index) => _Shimmer(height: itemHeight),
  );
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.height});

  final double height;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Hareketi azalt" açıkken nabız durur — ekranda saniyede bir yanıp
    // sönen büyük yüzeyler tam olarak kaçınılması istenen şey.
    if (MediaQuery.disableAnimationsOf(context)) {
      return _box(0.5);
    }
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.85).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.easeInOut),
      ),
      child: _box(1),
    );
  }

  Widget _box(double opacity) => Opacity(
    opacity: opacity,
    child: Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
  );
}

/// Uygulama genelinde tek bir bildirim biçimi.
///
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`
/// otuz yerde tekrar ediyordu ve hiçbiri öncekini kapatmıyordu — arka arkaya
/// iki hata olduğunda ikincisi birincinin kuyruğuna giriyor, kullanıcı
/// saniyelerce eski mesaja bakıyordu.
enum SnackTone { neutral, success, error }

void showAppSnack(
  BuildContext context,
  String message, {
  SnackTone tone = SnackTone.neutral,
  SnackBarAction? action,
}) {
  final (icon, color) = switch (tone) {
    SnackTone.success => (Icons.check_circle_outline, AppColors.ok),
    SnackTone.error => (Icons.error_outline, AppColors.accentSecondary),
    SnackTone.neutral => (null, null),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(
                message,
                style: AppType.sm.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        action: action,
        duration: Duration(seconds: tone == SnackTone.error ? 5 : 3),
      ),
    );
}

// `CupertinoPageTransitionsBuilder` Flutter 3.47'de cupertino altında —
// material.dart onu dışa aktarmıyor.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_typography.dart';

/// Uygulama teması — renkler [AppColors], tipografi [AppType], hareket
/// [AppMotion]; hepsi `web/src/styles/tokens.css` üzerinden.
///
/// ⚠️ ÜÇ ÖNEMLİ KARAR (eski hâline dönmeden önce okuyun):
///
/// 1. `ColorScheme.fromSeed` KULLANILMIYOR. Tohumdan üretilen palet, verilen
///    rengin etrafında Material'ın kendi ton eğrisini kuruyordu; sonuç webdeki
///    terracotta değil, ona "yakın" bir dizi mor/kahve tonuydu. Renkler tek
///    tek yazılıyor ki webde ne görünüyorsa mobilde de o görünsün.
///
/// 2. `fontFamily` BURADA tanımlı. Poppins `pubspec.yaml`'da kayıtlıydı ama
///    yalnızca giriş/kayıt ekranlarında `fontFamily: 'Poppins'` diye ELLE
///    yazılmıştı; harita, rota, profil ve konut ekranları Android'in
///    varsayılan yazı tipiyle çiziliyordu.
///
/// 3. `pageTransitionsTheme` AÇIKÇA tanımlı. Varsayılan Android geçişi
///    (`ZoomPageTransitionsBuilder`) Material'ın kendi hareket dilini
///    getiriyor ve `--ease-out` ile kurduğumuz ölçekle çelişiyordu. Artık
///    her platformda AYNI yatay kayma — web'deki sayfa geçişiyle aynı fikir.
abstract final class AppTheme {
  /// Geriye dönük uyumluluk: dışarıdan `AppTheme.primaryColor` çağıran
  /// yerler kırılmasın diye duruyor. Yeni kodda [AppColors.accent] kullanın.
  static const Color primaryColor = AppColors.accent;

  /// Durum çubuğu — harita ekranı tepeye kadar uzandığı için ikonlar KOYU
  /// olmak zorunda; açık krem/harita zemini üzerinde beyaz ikon kaybolur.
  static const SystemUiOverlayStyle systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// Webin tek bir açık teması var — koyu tema BİLEREK yok. Mobil de aynı
  /// davranıyor; yarım bir koyu tema iki üründe iki farklı görünüm demek
  /// olurdu.
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.accentInk,
      primaryContainer: Color(0xFFFBE7E0),
      onPrimaryContainer: AppColors.accentActive,
      secondary: AppColors.accentSecondary,
      onSecondary: AppColors.accentInk,
      secondaryContainer: Color(0xFFF7E4DC),
      onSecondaryContainer: AppColors.accentActive,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.bg,
      surfaceContainer: AppColors.bg,
      surfaceContainerHigh: AppColors.inputBg,
      surfaceContainerHighest: AppColors.inputBg,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.line,
      outlineVariant: AppColors.border,
      error: AppColors.bad,
      onError: AppColors.accentInk,
      errorContainer: Color(0xFFFBE4DC),
      onErrorContainer: Color(0xFF6B2109),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppType.fontFamily,
      textTheme: AppType.textTheme,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,

      // Her sayfa geçişi aynı eğriyi kullanıyor — bkz. sınıf notu §3.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SlidePageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Başlık çubuğu zeminle aynı: webdeki gibi sayfa tek parça görünsün,
      // araya gri bir şerit girmesin. `scrolledUnderElevation: 0` ÖNEMLİ —
      // varsayılanı, liste kaydırılınca çubuğa gri bir dolgu basıyor ve
      // krem zeminde kirli bir bant gibi duruyordu.
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: AppType.h2,
        toolbarHeight: 56,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        hintStyle: AppType.muted(AppType.body),
        labelStyle: AppType.muted(AppType.sm),
        floatingLabelStyle: AppType.sm.copyWith(color: AppColors.accent),
        errorStyle: AppType.xs.copyWith(color: AppColors.bad),
        prefixIconColor: AppColors.inkMuted,
        suffixIconColor: AppColors.inkMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        // Odak halkası TEK yerden: eskiden kimi alanda vardı, kimi alanda
        // yoktu ve klavyeyle gezinen kullanıcı nerede olduğunu göremiyordu.
        focusedBorder: _inputBorder(AppColors.accent, width: 1.6),
        errorBorder: _inputBorder(AppColors.bad),
        focusedErrorBorder: _inputBorder(AppColors.bad, width: 1.6),
        disabledBorder: _inputBorder(Colors.transparent),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          disabledBackgroundColor: const Color(0xFFE0D9D1),
          disabledForegroundColor: AppColors.inkMuted,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: AppType.h3.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          animationDuration: AppMotion.instant,
        ).copyWith(
          // Dokunma anında zemin koyulaşıyor. Material'ın varsayılan
          // dalgalanması dolu bir düğmede neredeyse görünmez — basma geri
          // bildirimi, hareketin temeli (bkz. AppMotion notu).
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFE0D9D1);
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accentActive;
            }
            return AppColors.accent;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: const BorderSide(color: AppColors.border, width: 1.25),
          textStyle: AppType.h3.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          animationDuration: AppMotion.instant,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppType.sm.copyWith(fontWeight: AppType.semibold),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          highlightColor: AppColors.accentSoft,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.inputBg,
          foregroundColor: AppColors.inkMuted,
          selectedBackgroundColor: AppColors.accent,
          selectedForegroundColor: AppColors.accentInk,
          side: BorderSide.none,
          textStyle: AppType.sm.copyWith(fontWeight: AppType.semibold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      // Alt menü: yüzen, yarı saydam bir malzeme değil — altındaki içerik
      // onun arkasından geçmiyor, kabuk parçası. Ama üstündeki ince çizgi
      // `--line-faint`: kalın bir ayraç, çubuğu ekrandan koparıyordu.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentSoftStrong,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color:
                states.contains(WidgetState.selected)
                    ? AppColors.accent
                    : AppColors.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppType.xs.copyWith(
            fontSize: 11.5,
            letterSpacing: 0.05,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? AppType.semibold
                    : AppType.medium,
            color:
                states.contains(WidgetState.selected)
                    ? AppColors.accent
                    : AppColors.inkMuted,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.inputBg,
        selectedColor: AppColors.accentSoftStrong,
        checkmarkColor: AppColors.accent,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: AppType.xs.copyWith(fontWeight: AppType.medium),
        secondaryLabelStyle: AppType.xs.copyWith(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppType.h2,
        contentTextStyle: AppType.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        dragHandleSize: Size(40, 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkMuted,
        titleTextStyle: AppType.h3,
        subtitleTextStyle: TextStyle(
          fontFamily: AppType.fontFamily,
          fontSize: 13.5,
          height: 1.4,
          color: AppColors.inkMuted,
        ),
        minVerticalPadding: 10,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accentInk
                  : AppColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.inputBg,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Colors.transparent
                  : AppColors.border,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.accentInk),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.inputBg,
        circularTrackColor: Colors.transparent,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppType.sm.copyWith(color: Colors.white),
        actionTextColor: AppColors.accentSecondary,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: AppType.xs.copyWith(color: Colors.white),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide:
            color == Colors.transparent
                ? BorderSide.none
                : BorderSide(color: color, width: width),
      );
}

/// Yatay kayma sayfa geçişi — `--ease-out` / `--ease-in` çiftiyle.
///
/// Giren sayfa sağdan gelir, çıkan sayfa sola doğru AZ bir miktar kayıp
/// soluklaşır. Çıkışın da kayması, iki sayfanın birbirine bağlı olduğunu
/// söylüyor: üstteki kapandığında alttaki "geri geliyor" gibi okunur.
/// Web'deki sayfa geçişiyle aynı fikir.
class _SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Erişilebilirlik: sistemde "hareketi azalt" açıksa kayma yerine
    // çapraz geçiş. Vestibüler rahatsızlığı olan kullanıcı için kayan
    // yüzeyler sorun, opaklık değişimi değil.
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final enter = CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.easeIn,
    );

    return SlideTransition(
      position: Tween(
        begin: const Offset(0.22, 0),
        end: Offset.zero,
      ).animate(enter),
      child: FadeTransition(
        opacity: Tween(begin: 0.0, end: 1.0).animate(enter),
        child: SlideTransition(
          position: Tween(
            begin: Offset.zero,
            end: const Offset(-0.10, 0),
          ).animate(exit),
          child: child,
        ),
      ),
    );
  }
}

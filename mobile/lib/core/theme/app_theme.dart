import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Uygulama teması — renkler [AppColors], yani `web/src/index.css` üzerinden.
///
/// ⚠️ İKİ ÖNEMLİ DEĞİŞİKLİK (eski hâline dönmeden önce okuyun):
///
/// 1. `ColorScheme.fromSeed` KULLANILMIYOR. Tohumdan üretilen palet, verilen
///    rengin etrafında Material'ın kendi ton eğrisini kuruyordu; sonuç webdeki
///    terracotta değil, ona "yakın" bir dizi mor/kahve tonuydu. Renkler artık
///    tek tek yazılıyor ki webde ne görünüyorsa mobilde de o görünsün.
///
/// 2. `fontFamily` BURADA tanımlı. Poppins `pubspec.yaml`'da kayıtlıydı ama
///    yalnızca giriş/kayıt ekranlarında `fontFamily: 'Poppins'` diye ELLE
///    yazılmıştı; harita, rota, profil ve konut ekranları Android'in
///    varsayılan yazı tipiyle çiziliyordu. "Auth ekranları tasarlanmış, gerisi
///    ham Material" görüntüsünün sebebi buydu.
abstract final class AppTheme {
  /// Geriye dönük uyumluluk: dışarıdan `AppTheme.primaryColor` çağıran
  /// yerler kırılmasın diye duruyor. Yeni kodda [AppColors.accent] kullanın.
  static const Color primaryColor = AppColors.accent;

  static const String _fontFamily = 'Poppins';

  /// Webin tek bir açık teması var — `@media (prefers-color-scheme: dark)`
  /// bloğu aynı değerleri tekrarlıyor, yani koyu tema BİLEREK yok. Mobil de
  /// aynı davranıyor; yarım bir koyu tema iki üründe iki farklı görünüm
  /// demek olurdu.
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.accentInk,
      primaryContainer: AppColors.accentSecondary,
      onPrimaryContainer: AppColors.accentInk,
      secondary: AppColors.accentSecondary,
      onSecondary: AppColors.accentInk,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.inputBg,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.line,
      outlineVariant: Color(0xFFD9D2CA),
      error: AppColors.bandPoor,
      onError: AppColors.accentInk,
    );

    final textTheme = Typography.material2021().black.apply(
      fontFamily: _fontFamily,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bg,

      // Başlık çubuğu zeminle aynı: webdeki gibi sayfa tek parça görünsün,
      // araya gri bir şerit girmesin.
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.ink,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0xFFE3DDD5)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        hintStyle: const TextStyle(color: AppColors.inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          disabledBackgroundColor: const Color(0xFFE0D9D1),
          disabledForegroundColor: AppColors.inkMuted,
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: Color(0xFFD9D2CA)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Alt menü: seçili sekme vurgu renginin çok açık bir zeminiyle
      // işaretleniyor (webdeki `.nav-btn--active` ile aynı fikir).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.inkMuted,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.inputBg,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE3DDD5),
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

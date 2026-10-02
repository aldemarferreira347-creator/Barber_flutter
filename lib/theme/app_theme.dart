import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  /// Reconstruye el ThemeData a partir del [AppColors] vigente (claro u
  /// oscuro). Debe recalcularse cada vez que cambia [AppColors.isDark].
  static ThemeData get current {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.action,
      onPrimary: AppColors.onAction,
      secondary: AppColors.accent,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
      brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
    );

    // Plus Jakarta Sans: geométrica, moderna y ligeramente distintiva —
    // reemplaza la Roboto por defecto para que la app no se sienta genérica,
    // manteniendo excelente legibilidad en textos largos.
    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: colorScheme.brightness).textTheme,
    );

    // Escala tipográfica única de la app. Las vistas usan estos estilos
    // (`Theme.of(context).textTheme.x`) en vez de armar TextStyle sueltos.
    final textTheme = base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );

    final navActive = AppColors.isDark ? AppColors.gold : AppColors.accent;

    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: AppColors.textSecondary),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: fieldBorder(AppColors.border),
        enabledBorder: fieldBorder(AppColors.border),
        focusedBorder: fieldBorder(AppColors.accent, 1.5),
        errorBorder: fieldBorder(AppColors.error),
        focusedErrorBorder: fieldBorder(AppColors.error, 1.5),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.onAction,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(52),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
          elevation: 0,
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: AppColors.border),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(48, 48),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        shape: roundedMd,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg + 4),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.isDark
            ? AppColors.surfaceRaised
            : AppColors.primary,
        contentTextStyle: TextStyle(
          color: AppColors.isDark ? AppColors.textPrimary : AppColors.onColor,
          fontSize: 14,
        ),
        shape: roundedMd,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.tint(AppColors.accent, alpha: 0.18),
        side: BorderSide(color: AppColors.border),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onAction
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.border,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.isDark
            ? AppColors.gold
            : AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.tint(navActive, alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? navActive
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? navActive
                : AppColors.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: navActive),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: navActive,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium,
        indicatorColor: AppColors.tint(AppColors.accent, alpha: 0.12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.action,
        foregroundColor: AppColors.onAction,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

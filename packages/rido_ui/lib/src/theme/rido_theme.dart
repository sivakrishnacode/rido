import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rido_colors.dart';
import 'rido_tokens.dart';

/// Builds the Rido Material 3 light theme.
abstract final class RidoTheme {
  /// Set to false in tests so no font is fetched over the network.
  static bool useGoogleFonts = true;

  static TextStyle _poppins(double size, double height, FontWeight weight) {
    final base = TextStyle(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      color: RidoColors.navy900,
      letterSpacing: -0.2,
    );
    return useGoogleFonts ? GoogleFonts.poppins(textStyle: base) : base;
  }

  static TextStyle _inter(double size, double height, FontWeight weight) {
    final base = TextStyle(fontSize: size, height: height / size, fontWeight: weight, color: RidoColors.navy900);
    return useGoogleFonts ? GoogleFonts.inter(textStyle: base) : base;
  }

  static RidoTextStyles textStyles() => RidoTextStyles(
        display: _poppins(28, 36, FontWeight.w700),
        h1: _poppins(22, 30, FontWeight.w600),
        h2: _poppins(18, 26, FontWeight.w600),
        body: _inter(16, 24, FontWeight.w400),
        bodyMedium: _inter(16, 24, FontWeight.w500),
        bodySemibold: _inter(16, 24, FontWeight.w600),
        bodySmall: _inter(14, 20, FontWeight.w400).copyWith(color: RidoColors.navy700),
        bodySmallMedium: _inter(14, 20, FontWeight.w500),
        caption: _inter(12, 16, FontWeight.w400).copyWith(color: RidoColors.navy500),
        button: _inter(16, 24, FontWeight.w600),
        overline: _inter(12, 16, FontWeight.w600).copyWith(color: RidoColors.navy500, letterSpacing: 1.2),
        hero: RidoTextStyles.tabular(_poppins(56, 64, FontWeight.w700)),
        heroSmall: RidoTextStyles.tabular(_poppins(40, 48, FontWeight.w700)),
        otp: RidoTextStyles.tabular(_poppins(28, 34, FontWeight.w600)),
      );

  static ThemeData light() {
    // Fonts ship in rido_ui/assets/google_fonts, so never fetch them at runtime.
    GoogleFonts.config.allowRuntimeFetching = false;
    final t = textStyles();
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: RidoColors.coral600,
      onPrimary: Colors.white,
      primaryContainer: RidoColors.coral50,
      onPrimaryContainer: RidoColors.coral600,
      secondary: RidoColors.navy900,
      onSecondary: Colors.white,
      secondaryContainer: RidoColors.inputBg,
      onSecondaryContainer: RidoColors.navy900,
      tertiary: RidoColors.coral500,
      onTertiary: Colors.white,
      error: RidoColors.error,
      onError: Colors.white,
      errorContainer: RidoColors.errorTint,
      onErrorContainer: RidoColors.error,
      surface: RidoColors.surface,
      onSurface: RidoColors.navy900,
      onSurfaceVariant: RidoColors.navy500,
      surfaceContainerLowest: RidoColors.surface,
      surfaceContainerLow: RidoColors.background,
      surfaceContainer: RidoColors.background,
      surfaceContainerHigh: RidoColors.inputBg,
      surfaceContainerHighest: RidoColors.inputBg,
      outline: RidoColors.divider,
      outlineVariant: RidoColors.divider,
      shadow: RidoColors.navy900,
      scrim: RidoColors.navy900,
      inverseSurface: RidoColors.navy900,
      onInverseSurface: Colors.white,
      inversePrimary: RidoColors.coral100,
    );

    final textTheme = TextTheme(
      displayLarge: t.display,
      displayMedium: t.display,
      displaySmall: t.display,
      headlineLarge: t.display,
      headlineMedium: t.h1,
      headlineSmall: t.h1,
      titleLarge: t.h2,
      titleMedium: t.bodySemibold,
      titleSmall: t.bodySmallMedium,
      bodyLarge: t.body,
      bodyMedium: t.bodySmall.copyWith(color: RidoColors.navy900),
      bodySmall: t.caption,
      labelLarge: t.button,
      labelMedium: t.bodySmallMedium,
      labelSmall: t.caption.copyWith(fontWeight: FontWeight.w500),
    );

    const pill = StadiumBorder();
    const inputBorder = OutlineInputBorder(borderRadius: RidoRadii.cardRadius, borderSide: BorderSide.none);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: RidoColors.background,
      canvasColor: RidoColors.surface,
      dividerColor: RidoColors.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [RidoTokens(text: t)],
      appBarTheme: AppBarTheme(
        backgroundColor: RidoColors.surface,
        foregroundColor: RidoColors.navy900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: t.h2,
        toolbarHeight: 64,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(color: RidoColors.divider, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RidoColors.coral600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RidoColors.divider,
          disabledForegroundColor: RidoColors.navy500,
          minimumSize: const Size(64, 52),
          shape: pill,
          textStyle: t.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RidoColors.navy900,
          minimumSize: const Size(64, 52),
          shape: pill,
          side: const BorderSide(color: RidoColors.navy900, width: 1.5),
          textStyle: t.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RidoColors.coral600,
          minimumSize: const Size(48, 48),
          shape: pill,
          textStyle: t.button,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: RidoColors.navy900),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RidoColors.inputBg,
        hintStyle: t.body.copyWith(color: RidoColors.navy500),
        labelStyle: t.bodySmall,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: const OutlineInputBorder(
          borderRadius: RidoRadii.cardRadius,
          borderSide: BorderSide(color: RidoColors.coral600, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: RidoRadii.cardRadius,
          borderSide: BorderSide(color: RidoColors.error, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: RidoRadii.cardRadius,
          borderSide: BorderSide(color: RidoColors.error, width: 2),
        ),
        errorStyle: t.caption.copyWith(color: RidoColors.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: RidoColors.surface,
        selectedColor: RidoColors.coral50,
        side: const BorderSide(color: RidoColors.divider),
        shape: pill,
        labelStyle: t.bodySmallMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : RidoColors.navy500),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? RidoColors.coral600 : RidoColors.inputBg),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? RidoColors.coral600 : RidoColors.navy500),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? RidoColors.coral600 : Colors.transparent),
        side: const BorderSide(color: RidoColors.navy500, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? RidoColors.coral600 : RidoColors.navy500),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RidoColors.coral600,
        linearTrackColor: RidoColors.coral100,
        circularTrackColor: RidoColors.coral100,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RidoColors.navy900,
        contentTextStyle: t.bodySmallMedium.copyWith(color: Colors.white),
        actionTextColor: RidoColors.coral100,
        shape: RoundedRectangleBorder(borderRadius: RidoRadii.cardRadius),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: RidoColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: t.h2,
        contentTextStyle: t.bodySmall,
        barrierColor: const Color(0x801E293B),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: RidoColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: RidoColors.scrim,
        shape: RoundedRectangleBorder(borderRadius: RidoRadii.sheetTop),
        showDragHandle: false,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: RidoColors.coral600,
        unselectedLabelColor: RidoColors.navy500,
        indicatorColor: RidoColors.coral600,
        labelStyle: t.bodySmallMedium.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: t.bodySmallMedium,
        dividerColor: RidoColors.divider,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: RidoColors.navy700,
        titleTextStyle: t.bodyMedium,
        subtitleTextStyle: t.bodySmall.copyWith(color: RidoColors.navy500),
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: RidoColors.navy900, borderRadius: BorderRadius.circular(8)),
        textStyle: t.caption.copyWith(color: Colors.white),
      ),
    );
  }
}

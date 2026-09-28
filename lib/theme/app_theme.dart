import 'package:flutter/material.dart';

/// SignSuara design tokens: ALL colours, gradients, fonts, spacing, radii, shadows and motion live
/// here (from the design file styles.css). Widgets never hard-code their own.
/// Deaf-flag palette: turquoise (sign language & community), yellow (hope), dark blue (humanity).
abstract final class AppColors {
  // Brand
  static const blue = Color(0xFF002B66);
  static const blue700 = Color(0xFF033B86);
  static const blue600 = Color(0xFF0A4BA3);
  static const royal = Color(0xFF3B6FD1);
  static const turq = Color(0xFF00A4B4);
  static const turqBright = Color(0xFF13C6D6);
  static const turqDeep = Color(0xFF007E8C);
  static const yellow = Color(0xFFFFC82D);
  static const yellowSoft = Color(0xFFFFD861);
  static const onYellow = Color(0xFF3A2C00); // text on yellow
  static const onYellowInk = Color(0xFFB07F00); // yellow-ish text on white

  // Light app surfaces
  static const bg = Color(0xFFF3F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFEEF3FA);
  static const ink = Color(0xFF0D1F3C);
  static const inkSoft = Color(0xFF4A5B78);
  static const inkFaint = Color(0xFF8493AC);
  static const line = Color(0xFFE4EBF5);

  // Text on the dark-blue panels
  static const onDark = Color(0xFFFFFFFF);
  static const onDarkSoft = Color(0xFFA9BCE0);
  static const onDarkFaint = Color(0xFF8FA6CF);
  static const glass = Color(0x14FFFFFF); // white 8 %
  static const glassBorder = Color(0x24FFFFFF); // white 14 %
  static const well = Color(0x59000F28); // dark inset box on a dark panel

  // States
  static const live = Color(0xFF43E08A);
  static const liveText = Color(0xFF6FF0A6);
  static const danger = Color(0xFFE8485F);
  static const warning = Color(0xFFEF6C00);
  static const offline = Color(0xFF6F86B6);
  static const recDot = Color(0xFFFF5A72); // "LIVE" dot
  static const recText = Color(0xFFFF8A9A);
  static const chipOnStage = Color(0x8C04183A); // dark chip over the signer stage
}

abstract final class AppGradients {
  /// Deep blue panel behind heroes (radial, lighter top-left).
  static const deep = RadialGradient(
    center: Alignment(-0.6, -1),
    radius: 1.4,
    colors: [Color(0xFF03489B), AppColors.blue, Color(0xFF001B44)],
    stops: [0, 0.45, 1],
  );
  static const turq = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.turqBright, AppColors.turq, AppColors.turqDeep],
    stops: [0, 0.55, 1],
  );
  static const sun = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.yellowSoft, AppColors.yellow, Color(0xFFF2A900)],
    stops: [0, 0.6, 1],
  );
  static const blueTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.royal, AppColors.blue],
  );
  static const cta = LinearGradient(
    begin: Alignment(-1, -0.6),
    end: Alignment(1, 0.6),
    colors: [Color(0xFF19D0DF), AppColors.turq, AppColors.turqDeep],
    stops: [0, 0.45, 1],
  );
  static const night = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.blue700, AppColors.blue],
    stops: [0, 0.7],
  );
  static const avatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.turqBright, AppColors.blue600],
  );
  static const bubbleMe = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF19D0DF), AppColors.turq, Color(0xFF008896)],
    stops: [0, 0.55, 1],
  );
  static const draft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.blue600, AppColors.blue],
  );
  static const stage = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A3A86), Color(0xFF03224F)],
  );
  static const stageGlow = RadialGradient(
    center: Alignment(0, -0.28),
    radius: 0.75,
    colors: [Color(0x6113C6D6), Color(0x0013C6D6)],
  );
  /// Border that slowly turns around the Hearing stage and the mic ring (design: conic border).
  static const stageBorder = SweepGradient(colors: [
    Color(0xF213C6D6),
    Color(0xD9FFC82D),
    Color(0x663B6FD1),
    Color(0xF213C6D6),
  ]);
  static const micRing = SweepGradient(colors: [
    AppColors.yellow,
    Color(0x00FFC82D),
    AppColors.turqBright,
    Color(0x0013C6D6),
    AppColors.yellow,
  ], stops: [0, 0.35, 0.55, 0.8, 1]);
  static const finger = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [AppColors.turq, Color(0xFF5FE6F0)],
  );
  static const navCapsule = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xF00C2E68), Color(0xF5001B44)],
  );
  static const navBlobTurq = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2FD6E4), AppColors.turq, Color(0xFF00808D)],
    stops: [0, 0.55, 1],
  );
  static const navBlobSun = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE07A), AppColors.yellow, Color(0xFFF0A500)],
    stops: [0, 0.55, 1],
  );
}

abstract final class AppFonts {
  static const display = 'Sora'; // headings
  static const ui = 'PlusJakartaSans'; // everything else
}

abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const gutter = 18.0; // page side margin
  static const xl = 20.0;
  static const xxl = 24.0;
  static const navHeight = 66.0;
  static const navMargin = 14.0;

  /// Space to leave at the bottom of a tab so the floating capsule nav never hides content.
  static double navClearance(BuildContext context) =>
      navHeight + navMargin * 2 + MediaQuery.paddingOf(context).bottom;
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 26.0;
  static const xl = 34.0;
  static const hero = 38.0; // bottom corners of the dark hero panels
  static const pill = 999.0;
}

abstract final class AppShadows {
  static const card = [BoxShadow(color: Color(0x73002B66), blurRadius: 40, spreadRadius: -22, offset: Offset(0, 18))];
  static const pop = [BoxShadow(color: Color(0x8C002B66), blurRadius: 60, spreadRadius: -20, offset: Offset(0, 26))];
  static const turqGlow = [BoxShadow(color: Color(0xE600A4B4), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 24))];
  static const sunGlow = [BoxShadow(color: Color(0xE6FFC82D), blurRadius: 16, spreadRadius: -8, offset: Offset(0, 8))];
  static const turqTile = [BoxShadow(color: Color(0xE600A4B4), blurRadius: 16, spreadRadius: -8, offset: Offset(0, 8))];
  static const blueTile = [BoxShadow(color: Color(0xE6002B66), blurRadius: 16, spreadRadius: -8, offset: Offset(0, 8))];
  static const nav = [BoxShadow(color: Color(0xA6001440), blurRadius: 40, spreadRadius: -14, offset: Offset(0, 22))];
  static const bubbleMe = [BoxShadow(color: Color(0xE600A4B4), blurRadius: 24, spreadRadius: -14, offset: Offset(0, 12))];
  static const dock = [BoxShadow(color: Color(0xCC002B66), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 20))];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 250);
  static const medium = Duration(milliseconds: 450);
  static const slow = Duration(milliseconds: 600);
  static const outCurve = Cubic(0.16, 1, 0.3, 1); // --ease-out
  static const springCurve = Cubic(0.34, 1.56, 0.64, 1); // --ease-spring
  static const navCurve = Cubic(0.34, 1.45, 0.5, 1);

  /// True when the phone asks for less motion: decorative animations must stop.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Text styles used by the screens (sizes from the design).
abstract final class AppText {
  static const _display = TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700, letterSpacing: -0.4);
  static const _ui = TextStyle(fontFamily: AppFonts.ui);

  static final heroTitle = _display.copyWith(fontSize: 26, height: 1.15, color: AppColors.onDark);
  static final screenTitle = _display.copyWith(fontSize: 24, color: AppColors.onDark);
  static final section = _display.copyWith(fontSize: 17, color: AppColors.ink);
  static final cardTitle = _display.copyWith(fontSize: 18, color: AppColors.onDark);
  static final bigWord = _display.copyWith(fontSize: 19);

  static final eyebrow = _ui.copyWith(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7);
  static final label = _ui.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700);
  static final body = _ui.copyWith(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5);
  static final strong = _ui.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static final small = _ui.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
  static final tiny = _ui.copyWith(fontSize: 9.5, fontWeight: FontWeight.w800);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.turq,
    primary: AppColors.turq,
    secondary: AppColors.yellow,
    onSecondary: AppColors.onYellow,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: AppFonts.ui);
  TextStyle? display(TextStyle? s) => s?.copyWith(fontFamily: AppFonts.display, color: AppColors.ink);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: base.textTheme.copyWith(
      displayLarge: display(base.textTheme.displayLarge),
      displayMedium: display(base.textTheme.displayMedium),
      displaySmall: display(base.textTheme.displaySmall),
      headlineLarge: display(base.textTheme.headlineLarge),
      headlineMedium: display(base.textTheme.headlineMedium),
      headlineSmall: display(base.textTheme.headlineSmall),
      titleLarge: display(base.textTheme.titleLarge),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.ink),
    ),
    cardTheme: const CardThemeData(color: AppColors.surface, surfaceTintColor: Colors.transparent),
  );
}

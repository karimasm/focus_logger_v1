import 'package:flutter/material.dart';

/// Centralized color constants for the Citrus Orange theme.
/// 
/// Design system:
/// - Orange canvas background for the app
/// - Dark panels for all content blocks (cards, containers, etc.)
/// - Proper contrast: dark text on orange, light text on dark panels
class AppColors {
  AppColors._();

  // ==================== CANVAS (Orange Background) ====================
  
  /// Primary canvas color - bright citrus orange
  static const Color canvasPrimary = Color(0xFFFFC470);
  
  /// Secondary canvas color - deeper orange for gradients
  static const Color canvasSecondary = Color(0xFFFF9C2A);
  
  /// Canvas gradient for scaffold backgrounds
  static const LinearGradient canvasGradient = LinearGradient(
    colors: [canvasPrimary, canvasSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ==================== PANELS (Dark Content Blocks) ====================
  
  /// Dark panel background - main content blocks
  static const Color panelBackground = Color(0xFF2B261F);
  
  /// Panel surface - slightly lighter for nested elements
  static const Color panelSurface = Color(0xFF3A3328);
  
  /// Panel border - subtle definition
  static const Color panelBorder = Color(0xFF4A4336);
  
  /// Panel shadow color
  static Color panelShadow = Colors.black.withOpacity(0.15);

  // ==================== TEXT COLORS ====================
  
  /// Text on orange canvas - dark for readability
  static const Color textOnCanvas = Color(0xFF2B261F);
  
  /// Secondary text on canvas
  static const Color textOnCanvasSecondary = Color(0xFF4A4336);
  
  /// Text on dark panels - warm white
  static const Color textOnPanel = Color(0xFFFFF8F0);
  
  /// Secondary text on panels
  static const Color textOnPanelSecondary = Color(0xFFBDB5A8);
  
  /// Muted text on panels
  static const Color textOnPanelMuted = Color(0xFF8A8278);

  // ==================== ACCENT COLORS ====================
  
  /// Primary accent - vibrant orange
  static const Color accent = Color(0xFFFF9C2A);
  
  /// Accent light - for highlights
  static const Color accentLight = Color(0xFFFFB85C);
  
  /// Accent on dark - for panel accents
  static const Color accentOnDark = Color(0xFFFFB347);

  // ==================== STATUS COLORS ====================
  
  /// Success green (adapted for theme)
  static const Color success = Color(0xFF7CB342);
  
  /// Warning orange
  static const Color warning = Color(0xFFFFB74D);
  
  /// Error red
  static const Color error = Color(0xFFE57373);
  
  /// Info blue
  static const Color info = Color(0xFF64B5F6);

  // ==================== BUTTON COLORS ====================
  
  /// Primary button background
  static const Color buttonPrimary = Color(0xFFFF9C2A);
  
  /// Primary button text
  static const Color buttonPrimaryText = Colors.white;
  
  /// Outline button border (on orange canvas)
  static const Color buttonOutlineBorder = Color(0xFF2B261F);
  
  /// Outline button text (on orange canvas)
  static const Color buttonOutlineText = Color(0xFF2B261F);

  // ==================== NAVIGATION ====================
  
  /// Navigation bar background
  static const Color navBackground = Color(0xFF2B261F);
  
  /// Navigation selected icon
  static const Color navSelected = Color(0xFFFF9C2A);
  
  /// Navigation unselected icon
  static const Color navUnselected = Color(0xFF8A8278);

  // ==================== SPECIAL STATES ====================
  
  /// Running activity indicator
  static const Color activityRunning = Color(0xFF7CB342);
  
  /// Paused activity indicator
  static const Color activityPaused = Color(0xFFFFB74D);
  
  /// Sync success
  static const Color syncSuccess = Color(0xFF7CB342);
  
  /// Sync error
  static const Color syncError = Color(0xFFE57373);
  
  /// Sync offline
  static const Color syncOffline = Color(0xFFFFB74D);

  // ==================== HELPER METHODS ====================
  
  /// Get panel decoration with standard styling
  static BoxDecoration panelDecoration({
    double borderRadius = 16,
    bool hasBorder = true,
    bool hasShadow = true,
    Color? backgroundColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? panelBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(color: panelBorder, width: 1) : null,
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: panelShadow,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
  
  /// Get surface panel decoration (lighter, for nested elements)
  static BoxDecoration surfaceDecoration({
    double borderRadius = 12,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: panelSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(color: panelBorder, width: 1) : null,
    );
  }
  
  // ==================== AUTO CONTRAST HELPERS ====================
  
  /// Get appropriate text color for any background
  /// Dark backgrounds → light text, Light backgrounds → dark text
  static Color textColorFor(Color background) {
    return background.computeLuminance() > 0.5 
        ? textOnCanvas  // dark text for light backgrounds
        : textOnPanel;  // light text for dark backgrounds
  }
  
  /// Get secondary text color for any background
  static Color secondaryTextColorFor(Color background) {
    return background.computeLuminance() > 0.5 
        ? textOnCanvasSecondary
        : textOnPanelSecondary;
  }
  
  /// Get muted text color for any background
  static Color mutedTextColorFor(Color background) {
    return background.computeLuminance() > 0.5 
        ? textOnCanvasSecondary
        : textOnPanelMuted;
  }
  
  /// Check if a color is considered "dark"
  static bool isDark(Color color) => color.computeLuminance() < 0.5;
  
  /// Check if a color is considered "light"
  static bool isLight(Color color) => color.computeLuminance() >= 0.5;
}

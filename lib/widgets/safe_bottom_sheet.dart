import 'package:flutter/material.dart';

/// Reusable scroll-safe bottom sheet wrapper.
/// 
/// Solves popup overflow issues by:
/// 1. Wrapping content in SingleChildScrollView
/// 2. Proper keyboard inset handling
/// 3. Max height constraint for small screens
/// 4. Safe area padding
/// 
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (context) => SafeBottomSheet(
///     title: 'My Sheet',
///     child: MyContent(),
///   ),
/// );
/// ```
class SafeBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final bool showCloseButton;
  final EdgeInsets? padding;
  final double? maxHeightFraction;

  const SafeBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.showCloseButton = true,
    this.padding,
    this.maxHeightFraction = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    
    // Calculate max height (85% of screen by default)
    final maxHeight = mediaQuery.size.height * (maxHeightFraction ?? 0.85);
    
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: mediaQuery.viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header with title and close button
              if (title != null || showCloseButton)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
                  child: Row(
                    children: [
                      if (title != null)
                        Expanded(
                          child: Text(
                            title!,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (showCloseButton)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: padding ?? const EdgeInsets.all(24),
                  child: child,
                ),
              ),
              
              // Actions at bottom (outside scroll)
              if (actions != null && actions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper to show a safe bottom sheet
Future<T?> showSafeBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

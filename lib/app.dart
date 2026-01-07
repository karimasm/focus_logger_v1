import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'theme/theme.dart';

class FocusLoggerApp extends StatelessWidget {
  const FocusLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => GuidedFlowProvider()),
        ChangeNotifierProvider(create: (_) => MemoProvider()),
        ChangeNotifierProvider(create: (_) => FlowActionProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: MaterialApp(
        title: 'Focus Logger',
        debugShowCheckedModeBanner: false,
        theme: _buildCitrusTheme(),
        // Wrap main navigation with guided flow overlay and app lifecycle observer
        home: const AppLifecycleHandler(
          child: GuidedFlowOverlay(
            child: MainNavigation(),
          ),
        ),
      ),
    );
  }

  ThemeData _buildCitrusTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Primary color scheme based on orange accent
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        primaryContainer: AppColors.panelSurface,
        onPrimaryContainer: AppColors.textOnPanel,
        secondary: AppColors.accentLight,
        onSecondary: AppColors.textOnCanvas,
        secondaryContainer: AppColors.panelSurface,
        onSecondaryContainer: AppColors.textOnPanel,
        tertiary: AppColors.warning,
        onTertiary: AppColors.textOnCanvas,
        tertiaryContainer: AppColors.panelSurface,
        onTertiaryContainer: AppColors.textOnPanel,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.panelBackground,
        onSurface: AppColors.textOnPanel,
        onSurfaceVariant: AppColors.textOnPanelSecondary,
        surfaceContainerHighest: AppColors.panelSurface,
        outline: AppColors.panelBorder,
        outlineVariant: AppColors.panelBorder,
      ),
      
      // Orange canvas background
      scaffoldBackgroundColor: AppColors.canvasPrimary,
      
      // App bar with transparent background (shows canvas)
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textOnCanvas,
        titleTextStyle: const TextStyle(
          color: AppColors.textOnCanvas,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnCanvas),
      ),
      
      // Dark panel card theme
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.panelBorder, width: 1),
        ),
      ),
      
      // Input decoration for text fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panelSurface,
        hintStyle: const TextStyle(color: AppColors.textOnPanelMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      
      // Primary filled button - orange with white text
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: AppColors.buttonPrimaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      
      // Outlined button - dark border on orange canvas
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.buttonOutlineText,
          side: const BorderSide(color: AppColors.buttonOutlineBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      
      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
        ),
      ),
      
      // Elevated button (fallback)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: AppColors.buttonPrimaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Chip theme for dark panels
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.panelSurface,
        labelStyle: const TextStyle(color: AppColors.textOnPanel),
        side: const BorderSide(color: AppColors.panelBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Navigation bar at bottom
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navBackground,
        indicatorColor: AppColors.accent.withOpacity(0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.navSelected);
          }
          return const IconThemeData(color: AppColors.navUnselected);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.navSelected,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: AppColors.navUnselected,
            fontSize: 12,
          );
        }),
      ),
      
      // Navigation rail for wide screens
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.navBackground,
        selectedIconTheme: const IconThemeData(color: AppColors.navSelected),
        unselectedIconTheme: const IconThemeData(color: AppColors.navUnselected),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.navSelected,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: AppColors.navUnselected,
        ),
        indicatorColor: AppColors.accent.withOpacity(0.2),
      ),
      
      // Tab bar theme
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textOnPanelSecondary,
        indicatorColor: AppColors.accent,
        dividerColor: Colors.transparent,
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.panelBorder),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textOnPanel,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textOnPanelSecondary,
          fontSize: 14,
        ),
      ),
      
      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      
      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.panelBackground,
        contentTextStyle: const TextStyle(color: AppColors.textOnPanel),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.panelBorder,
        thickness: 1,
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.textOnPanel,
      ),
      
      // List tile theme
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textOnPanel,
        iconColor: AppColors.textOnPanelSecondary,
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.textOnCanvas),
        displayMedium: TextStyle(color: AppColors.textOnCanvas),
        displaySmall: TextStyle(color: AppColors.textOnCanvas),
        headlineLarge: TextStyle(color: AppColors.textOnCanvas),
        headlineMedium: TextStyle(color: AppColors.textOnCanvas),
        headlineSmall: TextStyle(color: AppColors.textOnCanvas),
        titleLarge: TextStyle(color: AppColors.textOnCanvas),
        titleMedium: TextStyle(color: AppColors.textOnCanvas),
        titleSmall: TextStyle(color: AppColors.textOnCanvas),
        bodyLarge: TextStyle(color: AppColors.textOnCanvas),
        bodyMedium: TextStyle(color: AppColors.textOnCanvas),
        bodySmall: TextStyle(color: AppColors.textOnCanvasSecondary),
        labelLarge: TextStyle(color: AppColors.textOnCanvas),
        labelMedium: TextStyle(color: AppColors.textOnCanvas),
        labelSmall: TextStyle(color: AppColors.textOnCanvasSecondary),
      ),
    );
  }
}

/// Handles app lifecycle events for sync and flow window checks
/// LATE-OPEN SUPPORT: When app is opened/resumed, check for active flow windows
class AppLifecycleHandler extends StatefulWidget {
  final Widget child;
  
  const AppLifecycleHandler({super.key, required this.child});

  @override
  State<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<AppLifecycleHandler> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initial sync when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAppResumed();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - sync and check for active flow windows
      _onAppResumed();
    }
  }
  
  void _onAppResumed() {
    // Trigger sync
    final syncProvider = context.read<SyncProvider>();
    syncProvider.onAppResumed();
    
    // Check for active flow windows (LATE-OPEN SUPPORT)
    final guidedFlowProvider = context.read<GuidedFlowProvider>();
    guidedFlowProvider.onAppResumed();
    
    // Reload activity state
    final activityProvider = context.read<ActivityProvider>();
    activityProvider.onAppResumed();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    TimelineScreen(),
    TasksScreen(),
  ];

  final _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.timeline_outlined),
      selectedIcon: Icon(Icons.timeline_rounded),
      label: 'Timeline',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome_rounded),
      label: 'Actions',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Use NavigationRail for wider screens (desktop/tablet)
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          // Current activity indicator in app bar
          Consumer<ActivityProvider>(
            builder: (context, provider, _) {
              if (!provider.hasRunningActivity) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: provider.isPaused
                      ? Colors.orange.withOpacity(0.2)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isPaused ? Colors.orange : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.currentActivity!.formattedDuration,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: provider.isPaused
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: isWideScreen
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map((d) => NavigationRailDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon,
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _screens[_currentIndex]),
              ],
            )
          : _screens[_currentIndex],
      bottomNavigationBar: isWideScreen
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              destinations: _destinations,
            ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Focus Logger';
      case 1:
        return 'Timeline';
      case 2:
        return 'Flow & Actions';
      default:
        return 'Focus Logger';
    }
  }
}

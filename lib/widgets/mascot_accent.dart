import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/mascot_service.dart';

/// Widget for displaying mascot accent images based on activity state.
/// 
/// Uses MascotService to determine which mascot asset to show.
class MascotAccent extends StatelessWidget {
  final Activity? activity;
  final double size;
  final bool showTooltip;
  
  const MascotAccent({
    super.key,
    this.activity,
    this.size = 48,
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    if (activity == null) {
      return const SizedBox.shrink();
    }
    
    final assetPath = MascotService.getMascotAsset(activity!);
    if (assetPath == null) {
      return const SizedBox.shrink();
    }
    
    Widget mascotImage = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Failed to load mascot: $assetPath - $error');
        return const SizedBox.shrink();
      },
    );
    
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: mascotImage,
      ),
    );
  }
}

/// Animated mascot that can fade in/out
class AnimatedMascotAccent extends StatefulWidget {
  final Activity? activity;
  final double size;
  
  const AnimatedMascotAccent({
    super.key,
    this.activity,
    this.size = 48,
  });

  @override
  State<AnimatedMascotAccent> createState() => _AnimatedMascotAccentState();
}

class _AnimatedMascotAccentState extends State<AnimatedMascotAccent> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String? _currentAsset;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _updateAsset();
    if (_currentAsset != null) {
      _controller.forward();
    }
  }
  
  void _updateAsset() {
    if (widget.activity != null) {
      _currentAsset = MascotService.getMascotAsset(widget.activity!);
    } else {
      _currentAsset = null;
    }
  }
  
  @override
  void didUpdateWidget(AnimatedMascotAccent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldAsset = oldWidget.activity != null 
        ? MascotService.getMascotAsset(oldWidget.activity!) 
        : null;
    _updateAsset();
    
    if (_currentAsset != oldAsset) {
      if (_currentAsset == null) {
        _controller.reverse();
      } else if (oldAsset == null) {
        _controller.forward();
      } else {
        _controller.reverse().then((_) {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAsset == null) {
      return const SizedBox.shrink();
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: MascotAccent(
        activity: widget.activity,
        size: widget.size,
      ),
    );
  }
}

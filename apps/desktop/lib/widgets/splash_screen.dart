import 'dart:async';

import 'package:flutter/material.dart';

/// A brief Flutter-branded screen shown before the initial app page.
/// Works on Windows, Android and iOS.
class TruckLinkSplash extends StatefulWidget {
  const TruckLinkSplash({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1100),
  });

  final Widget child;
  final Duration duration;

  @override
  State<TruckLinkSplash> createState() => _TruckLinkSplashState();
}

class _TruckLinkSplashState extends State<TruckLinkSplash> {
  Timer? _timer;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) {
        setState(() => _complete = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: _complete
          ? KeyedSubtree(
              key: const ValueKey('app'),
              child: widget.child,
            )
          : Scaffold(
              key: const ValueKey('splash'),
              backgroundColor: const Color(0xFF091018),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Image.asset(
                      'assets/branding/splash_logo.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

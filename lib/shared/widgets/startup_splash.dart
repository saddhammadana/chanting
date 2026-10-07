import 'dart:async';

import 'package:flutter/material.dart';

import 'loading_indicator.dart';

/// The lotus loader over the whole app while it starts, from
/// `design/mobile/serene/21`: the lotus, the app's name, the loading line and
/// the dots.
///
/// It sits between the platform's launch screen — which can only show a still
/// lotus — and the first page, so the picture the user sees does not change
/// until there is a page to show. The lotus is at the centre of the screen,
/// where Android's launch screen draws it, so the hand-over does not move.
///
/// Held for [hold] so a fast start does not flash it, then faded out. The app
/// builds underneath the whole time; nothing waits on this.
class StartupSplash extends StatefulWidget {
  const StartupSplash({
    super.key,
    required this.child,
    this.hold = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final Duration hold;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> {
  static const _fade = Duration(milliseconds: 400);

  bool _visible = true;
  bool _gone = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.hold, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _fade,
            onEnd: () => setState(() => _gone = true),
            child: ColoredBox(
              key: const ValueKey('startup_splash'),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const LoadingIndicator(appName: true),
            ),
          ),
        ),
      ],
    );
  }
}

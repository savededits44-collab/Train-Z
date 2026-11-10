import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Staggered Fade & Slide-Up entrance animation.
/// Gives screens a luxury, flagship feel as elements glide into place.
class TrainerFadeSlide extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;
  final double offsetDistance;
  final Curve curve;

  const TrainerFadeSlide({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 550),
    this.offsetDistance = 24.0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<TrainerFadeSlide> createState() => _TrainerFadeSlideState();
}

class _TrainerFadeSlideState extends State<TrainerFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _offset = Tween<Offset>(
      begin: Offset(0, widget.offsetDistance),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: _offset.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Tactile spring-scale bounce on touch.
/// Shrinks to [scaleDown] when pressed and springs back on release with haptic feedback.
class TrainerPressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final bool enableHaptics;

  const TrainerPressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
    this.duration = const Duration(milliseconds: 140),
    this.enableHaptics = true,
  });

  @override
  State<TrainerPressScale> createState() => _TrainerPressScaleState();
}

class _TrainerPressScaleState extends State<TrainerPressScale> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (_pressed) setState(() => _pressed = false);
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Animated numeric rolling counter.
/// Smoothly counts up from 0 to [value] with formatted output.
class TrainerCountUp extends StatelessWidget {
  final num value;
  final String prefix;
  final String suffix;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  const TrainerCountUp({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    required this.style,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutExpo,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animatedVal, _) {
        final formatted = (value is int)
            ? animatedVal.round().toString()
            : animatedVal.toStringAsFixed(1);

        return Text(
          '$prefix$formatted$suffix',
          style: style,
        );
      },
    );
  }
}

/// Radar-style expanding halo / pulsing live dot.
/// Captures attention for live syncing states.
class TrainerLivePulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const TrainerLivePulseDot({
    super.key,
    this.color = const Color(0xFF4CAF50),
    this.size = 8.0,
  });

  @override
  State<TrainerLivePulseDot> createState() => _TrainerLivePulseDotState();
}

class _TrainerLivePulseDotState extends State<TrainerLivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scale = 1.0 + (_controller.value * 1.2);
              final opacity = (1.0 - _controller.value).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: opacity * 0.45),
                  ),
                ),
              );
            },
          ),
          // Solid core dot
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Breathing ambient glow wrapper for high-priority cards.
/// Creates an eye-catching pulsating aura around cards or banners.
class TrainerBreathingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minBlur;
  final double maxBlur;
  final double borderRadius;
  final bool active;

  const TrainerBreathingGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.minBlur = 6.0,
    this.maxBlur = 18.0,
    this.borderRadius = 18.0,
    this.active = true,
  });

  @override
  State<TrainerBreathingGlow> createState() => _TrainerBreathingGlowState();
}

class _TrainerBreathingGlowState extends State<TrainerBreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TrainerBreathingGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final blur = widget.minBlur +
            (_controller.value * (widget.maxBlur - widget.minBlur));
        final alpha = 0.12 + (_controller.value * 0.18);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: alpha),
                blurRadius: blur,
                spreadRadius: 1.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Sweeping light shimmer effect for celebration or action buttons.
class TrainerShimmerSweep extends StatefulWidget {
  final Widget child;
  final Duration period;

  const TrainerShimmerSweep({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<TrainerShimmerSweep> createState() => _TrainerShimmerSweepState();
}

class _TrainerShimmerSweepState extends State<TrainerShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double width = bounds.width;
            final double offset = (width * 2) * _controller.value - width;

            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Colors.transparent,
                Colors.white38,
                Colors.white,
                Colors.white38,
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              transform: _SlidingGradientTransform(offset / width),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

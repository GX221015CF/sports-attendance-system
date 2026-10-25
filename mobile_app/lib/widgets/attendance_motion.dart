import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/interaction_audio.dart';
import 'adaptive_page_body.dart';
import 'form_surface.dart';

class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _down = false;
  void _press(bool value) {
    if (mounted && _down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled ? (_) => _press(true) : null,
    onPointerUp: (_) => _press(false),
    onPointerCancel: (_) => _press(false),
    child: AnimatedScale(
      scale: _down && widget.enabled && !reduceFormMotion(context) ? .965 : 1,
      duration: formMotionDuration(context, _down ? 85 : 240),
      curve: _down ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

/// Only transitions between recorded values; it never invents intermediate counts.
class RollingCount extends StatelessWidget {
  const RollingCount({super.key, required this.value, this.style});
  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '$value',
      key: ValueKey(value),
      style: style,
      maxLines: 1,
    );
    if (reduceFormMotion(context)) return text;
    return Semantics(
      label: '$value',
      child: ExcludeSemantics(
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .6), end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
            child: text,
          ),
        ),
      ),
    );
  }
}

/// A new sequence is issued only after a successful service write.
/// The feedback never takes focus, blocks another member, or delays saving.
class CheckinFeedback extends StatefulWidget {
  const CheckinFeedback({
    super.key,
    required this.sequence,
    required this.message,
    required this.child,
  });
  final int sequence;
  final String? message;
  final Widget child;

  @override
  State<CheckinFeedback> createState() => _CheckinFeedbackState();
}

class _CheckinFeedbackState extends State<CheckinFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismiss;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void didUpdateWidget(CheckinFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sequence == oldWidget.sequence || widget.message == null) return;
    InteractionAudio.instance.play(SoundCue.checkinSuccess);
    _dismiss?.cancel();
    _visible = true;
    if (reduceFormMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
    _dismiss = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceFormMotion(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_visible)
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: IgnorePointer(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => CustomPaint(
                    foregroundPainter: reduceFormMotion(context)
                        ? null
                        : _ParticlePainter(_controller.value),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: reduceFormMotion(context) ? 0 : 54,
                      ),
                      child: child,
                    ),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      elevation: 5,
                      color: const Color(0xFFEFFAF3),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: _SuccessMark(
                                key: ValueKey(widget.sequence),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.message!,
                                style: const TextStyle(
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _SuccessMark extends StatefulWidget {
  const _SuccessMark({super.key});
  @override
  State<_SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<_SuccessMark>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceFormMotion(context)) {
      _controller.value = 1;
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) => CustomPaint(painter: _CheckPainter(_controller.value)),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .16, size.height * .5)
      ..lineTo(size.width * .4, size.height * .73)
      ..lineTo(size.width * .85, size.height * .25);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = const Color(0xFF166534)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .095
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final random = math.Random(42);
    final scale = math.min(1.0, size.width / 320);
    for (var i = 0; i < 38; i++) {
      final angle = -math.pi + random.nextDouble() * math.pi;
      final speed = (90 + random.nextDouble() * 140) * scale;
      final x = size.width / 2 + math.cos(angle) * speed * progress;
      final y =
          size.height * .58 +
          math.sin(angle) * speed * progress +
          140 * progress * progress;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * (i.isEven ? 6 : -6));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -5, 6, 10),
          const Radius.circular(2),
        ),
        Paint()
          ..color = [
            AppTheme.primary,
            AppTheme.secondary,
            AppTheme.success,
          ][i % 3].withValues(alpha: 1 - progress),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Mirrors the existing page columns. Disappears as soon as data arrives.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.fullPage = false,
    this.statistics = false,
    this.cardHeight = 138,
    this.columns,
    this.count = 4,
    this.attendance = false,
  });
  final bool fullPage;
  final bool statistics;
  final double cardHeight;
  final int? columns;
  final int count;
  final bool attendance;
  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceFormMotion(context) || !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box(double height, {double? width}) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(12),
    ),
  );

  Widget _cards() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = widget.cardHeight < 110;
      final columns =
          widget.columns ??
          (widget.statistics
              ? (constraints.maxWidth >= 420 ? 2 : 1)
              : (constraints.maxWidth >= 720 &&
                        MediaQuery.textScalerOf(context).scale(16) <= 22
                    ? 2
                    : 1));
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(
          widget.count,
          (index) => SizedBox(
            width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
            child: Container(
              height: widget.cardHeight,
              padding: EdgeInsets.all(compact ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FractionallySizedBox(widthFactor: .55, child: _box(22)),
                  SizedBox(height: compact ? 8 : 12),
                  FractionallySizedBox(widthFactor: .8, child: _box(12)),
                  if (!widget.statistics) ...[
                    SizedBox(height: compact ? 8 : 12),
                    FractionallySizedBox(widthFactor: .4, child: _box(12)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final shapes = ExcludeSemantics(child: _cards());
    final content = widget.fullPage
        ? AdaptivePageBody(
            storageKey: 'loading-skeleton',
            toolbar: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 8),
                  const Text('正在加载…'),
                ],
              ),
            ),
            summary: ExcludeSemantics(
              child: widget.attendance
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _box(202),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _box(20, width: 100),
                        ),
                        const SizedBox(height: 8),
                        _box(6),
                        const SizedBox(height: 12),
                        for (var row = 0; row < 3; row++) ...[
                          Row(
                            children: [
                              Expanded(child: _box(72)),
                              const SizedBox(width: 8),
                              Expanded(child: _box(72)),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    )
                  : _box(180),
            ),
            filters: ExcludeSemantics(
              child: _box(widget.attendance ? 100 : 56),
            ),
            slivers: [SliverToBoxAdapter(child: shapes)],
          )
        : shapes;
    return Semantics(
      label: '正在加载',
      child: AnimatedBuilder(
        animation: _controller,
        child: content,
        builder: (context, child) => reduceFormMotion(context)
            ? child!
            : ShaderMask(
                blendMode: BlendMode.modulate,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(-2 + 4 * _controller.value, 0),
                  end: Alignment(-1 + 4 * _controller.value, 0),
                  colors: const [
                    Color(0xFFE2E8F0),
                    Color(0xFFF5F8FF),
                    Color(0xFFE2E8F0),
                  ],
                ).createShader(rect),
                child: child,
              ),
      ),
    );
  }
}

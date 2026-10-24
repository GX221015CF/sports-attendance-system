import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

bool reduceFormMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

Duration formMotionDuration(BuildContext context, int milliseconds) =>
    reduceFormMotion(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

AnimationStyle formSheetAnimationStyle(BuildContext context) =>
    reduceFormMotion(context)
    ? AnimationStyle.noAnimation
    : const AnimationStyle(
        duration: Duration(milliseconds: 220),
        reverseDuration: Duration(milliseconds: 160),
      );

/// Leaves the primary action above the keyboard while only fields scroll.
class FormSurface extends StatelessWidget {
  const FormSurface({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.busy,
    required this.onSubmit,
    required this.child,
    this.caption,
    this.errorMessage,
    this.maxWidth = 960,
  });

  final String title;
  final String submitLabel;
  final bool busy;
  final VoidCallback onSubmit;
  final Widget child;
  final String? caption;
  final String? errorMessage;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: AnimatedPadding(
      duration: formMotionDuration(context, 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textStrong,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: _KeyboardSelectionGuard(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (caption != null) ...[
                            Text(
                              caption!,
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                          ],
                          InlineFeedback(message: errorMessage),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            disabledForegroundColor: AppTheme.textMuted,
                            disabledBackgroundColor: AppTheme.background,
                            side: BorderSide(
                              color: busy
                                  ? const Color(0xFFE2E8F0)
                                  : AppTheme.primary,
                            ),
                          ),
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SubmissionButton(
                          label: submitLabel,
                          busy: busy,
                          onPressed: onSubmit,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Selection handles live in the route overlay. When the keyboard shrinks a
/// short sheet, dismiss them without dropping focus so they cannot cover Save.
class _KeyboardSelectionGuard extends StatefulWidget {
  const _KeyboardSelectionGuard({required this.child});
  final Widget child;
  @override
  State<_KeyboardSelectionGuard> createState() =>
      _KeyboardSelectionGuardState();
}

class _KeyboardSelectionGuardState extends State<_KeyboardSelectionGuard>
    with WidgetsBindingObserver {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      void hideSelection(Element element) {
        if (element is StatefulElement && element.state is EditableTextState) {
          final editor = element.state as EditableTextState;
          if (editor.widget.focusNode.hasFocus) editor.hideToolbar();
        } else {
          element.visitChildElements(hideSelection);
        }
      }

      context.visitChildElements(hideSelection);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ResponsiveFormFields extends StatelessWidget {
  const ResponsiveFormFields({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 680 &&
              MediaQuery.textScalerOf(context).scale(16) < 24
          ? 2
          : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 16) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class SubmissionButton extends StatelessWidget {
  const SubmissionButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.busyLabel = '保存中…',
    this.icon = Icons.check,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  final String busyLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.secondary,
          disabledForegroundColor: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: AnimatedSwitcher(
                duration: formMotionDuration(context, 120),
                child: busy
                    ? reduceFormMotion(context)
                          ? const Icon(
                              Icons.hourglass_top,
                              key: ValueKey('waiting'),
                              size: 20,
                            )
                          : const SizedBox(
                              key: ValueKey('progress'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                    : Icon(icon, key: const ValueKey('ready'), size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                busy ? busyLabel : label,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class InlineFeedback extends StatelessWidget {
  const InlineFeedback({super.key, required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final feedback = message == null
        ? const SizedBox.shrink(key: ValueKey('no-feedback'))
        : Padding(
            key: ValueKey(message),
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
    return Semantics(
      liveRegion: true,
      child: reduceFormMotion(context)
          ? feedback
          : AnimatedSize(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.topCenter,
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: feedback,
              ),
            ),
    );
  }
}

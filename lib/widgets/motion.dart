import 'package:flutter/material.dart';

import '../theme.dart';

/// Duration for a state-change transition (loading -> content, chart <->
/// table). Long enough to read as a fade, short enough not to slow down a
/// screen whose whole job is a quick look at a number.
const kStateChangeDuration = Duration(milliseconds: 220);

/// Duration for [ValuePulse]'s colour pulse when a displayed value changes.
const kValuePulseDuration = Duration(milliseconds: 600);

/// Whether the platform has reduce-motion enabled. A one-line wrapper over
/// [MediaQuery.disableAnimationsOf] so call sites read as intent, and so
/// there is a single place to change the policy later.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// A thin [AnimatedSwitcher] wrapper for state-change transitions.
///
/// [AnimatedSwitcher] never animates the entry of the very first child it
/// mounts — its `initState` sets that child's controller straight to its
/// end value rather than running it — so the only thing this needs to add
/// is reduce-motion: it collapses the transition to [Duration.zero] instead
/// of just shortening it, avoiding an 11ms flicker.
class MotionSwitcher extends StatelessWidget {
  final Widget child;

  const MotionSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: reduceMotion(context) ? Duration.zero : kStateChangeDuration,
    child: child,
  );
}

/// Wraps a single [Text] and pulses its colour from
/// [BrandColors.changeAccent] back to [color] when the formatted value
/// actually changes, so a value that changed on refresh reads differently
/// from one that didn't.
///
/// A pulse rather than a crossfade of the text: [AnimatedSwitcher] keeps
/// both children mounted mid-transition, which would put two values in a
/// screen reader's path inside a [MergeSemantics] row and could shift the
/// row's width. A colour pulse on one [Text] has neither problem.
class ValuePulse extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final String? semanticsLabel;

  const ValuePulse({
    super.key,
    required this.value,
    this.style,
    this.semanticsLabel,
  });

  @override
  State<ValuePulse> createState() => _ValuePulseState();
}

class _ValuePulseState extends State<ValuePulse> {
  int _pulseCount = 0;

  @override
  void didUpdateWidget(ValuePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() => _pulseCount++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restingColor = widget.style?.color;
    final pulseColor = Theme.of(context).extension<BrandColors>()!.changeAccent;
    final duration = reduceMotion(context)
        ? Duration.zero
        : kValuePulseDuration;

    return TweenAnimationBuilder<Color?>(
      key: ValueKey(_pulseCount),
      tween: ColorTween(
        begin: _pulseCount == 0 ? restingColor : pulseColor,
        end: restingColor,
      ),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, color, _) => Text(
        widget.value,
        style: widget.style?.copyWith(color: color),
        semanticsLabel: widget.semanticsLabel,
      ),
    );
  }
}

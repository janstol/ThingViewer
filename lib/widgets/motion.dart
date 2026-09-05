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

/// Tag identifying the [Hero] flight between a field row's label (channel
/// detail screen) and its chart's AppBar title.
///
/// `|` mirrors `FieldSettingsStorage`'s own key separator — safe because
/// RFC 3986 never permits it unencoded inside a URI, so it cannot occur
/// inside `Channel.serverUrl`.
String fieldLabelHeroTag(String serverUrl, int channelId, int fieldId) =>
    'field-label:$serverUrl|$channelId|$fieldId';

/// A field's label, shared via [Hero] between the channel detail screen's
/// field row and the field chart screen's AppBar title.
///
/// Renders a plain [Text] under reduce-motion, the same policy as
/// [MotionSwitcher] and [ValuePulse] — both ends read the same app-wide
/// [MediaQuery], so they agree, and an unmatched [Hero] simply doesn't fly.
class FieldLabelHero extends StatelessWidget {
  final String tag;
  final String label;
  final TextStyle style;
  final int maxLines;

  const FieldLabelHero({
    super.key,
    required this.tag,
    required this.label,
    required this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
    if (reduceMotion(context)) return text;

    return Hero(
      tag: tag,
      flightShuttleBuilder: _flightShuttleBuilder,
      child: Material(type: MaterialType.transparency, child: text),
    );
  }

  /// Renders the label mid-flight as a single line that never rewraps, so a
  /// long label doesn't reflow as its bounding box narrows from a two-line
  /// list tile into a single-line AppBar title. `centerLeft` keeps it from
  /// jumping vertically for the same reason — a `ListTile` title box can be
  /// two lines tall, an `AppBar` title is vertically centred.
  ///
  /// Colour is lerped through a late-weighted [Interval] rather than
  /// linearly: the row label is dark-on-white in light mode, the chart
  /// AppBar title is white-on-brandBlue, and a straight lerp puts
  /// near-white text over the white page for the back half of the flight.
  /// Holding the source colour until 40% and only whitening as the label
  /// settles onto the blue AppBar keeps it legible throughout.
  ///
  /// [fromHeroContext]/[toHeroContext] keep push semantics even on a pop
  /// (from = the row's Hero, to = the chart's Hero, regardless of
  /// direction), but `animation` does not: on a pop it runs from 1 down to
  /// 0 as the flight progresses, the reverse of push's 0 up to 1 — a
  /// mid-flight widget test is what caught this rather than reasoning
  /// about it, per the plan this shipped from. [flightDirection] corrects
  /// for it here.
  static Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromLabel = fromHeroContext
        .findAncestorWidgetOfExactType<FieldLabelHero>()!;
    final toLabel = toHeroContext
        .findAncestorWidgetOfExactType<FieldLabelHero>()!;
    const colorInterval = Interval(0.4, 1.0, curve: Curves.easeIn);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final raw = animation.value.clamp(0.0, 1.0);
        final t = flightDirection == HeroFlightDirection.pop ? 1.0 - raw : raw;
        final style = TextStyle.lerp(fromLabel.style, toLabel.style, t)!;
        final color = Color.lerp(
          fromLabel.style.color,
          toLabel.style.color,
          colorInterval.transform(t),
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              toLabel.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: color),
            ),
          ),
        );
      },
    );
  }
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

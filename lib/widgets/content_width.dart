import 'package:material_ui/material_ui.dart';

/// Caps the width of list-style content and centres it, so rows don't stretch edge to edge on tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  /// The upper end of Material's medium window size class.
  static const maxWidth = 840.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

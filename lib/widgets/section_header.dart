import 'package:flutter/material.dart';

import '../theme.dart';

/// Small labelled header used to group settings tiles into sections.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Semantics(
      headingLevel: 1,
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.extension<BrandColors>()!.dataAccent,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                trailing!,
              ],
            ),
    );
  }
}

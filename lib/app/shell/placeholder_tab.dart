import 'package:flutter/material.dart';

/// A minimal empty-state placeholder for a shell tab.
///
/// Real feature screens replace these in later milestones (F02+). Kept
/// intentionally bare — it exists only so the shell boots to a complete,
/// navigable 4-tab structure.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

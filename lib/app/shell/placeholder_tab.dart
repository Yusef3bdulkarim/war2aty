import 'package:flutter/material.dart';

/// A minimal empty-state placeholder for a screen that does not exist yet.
///
/// Real feature screens replace these in later milestones (F03+). Kept
/// intentionally bare — it exists only so the app is completely navigable:
/// every tab opens, and every action leads somewhere with a way back.
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

import 'package:flutter/material.dart';

import 'admin_theme.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AdminTheme.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class AdminOverviewCard extends StatelessWidget {
  const AdminOverviewCard({
    super.key,
    required this.label,
    required this.note,
    required this.count,
    required this.icon,
    required this.color,
    this.countColor,
  });

  final String label, note;
  final int? count;
  final IconData icon;
  final Color color;
  final Color? countColor;

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: color.withValues(alpha: .1),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 5),
                Text(
                  count?.toString() ?? '-',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: countColor ?? color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  note,
                  style: const TextStyle(fontSize: 10, color: AdminTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AdminOverviewGrid extends StatelessWidget {
  const AdminOverviewGrid({super.key, required this.cards});

  final List<AdminOverviewCard> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 850
          ? 4
          : constraints.maxWidth >= 450
          ? 2
          : 1;
      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}

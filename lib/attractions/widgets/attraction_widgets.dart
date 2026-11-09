import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../visitor/widgets/visitor_ui.dart';
import '../models/attraction.dart';

IconData parkPlaceIcon(ParkPlaceKind kind) => switch (kind) {
  ParkPlaceKind.attractions => Icons.attractions_outlined,
  ParkPlaceKind.dining => Icons.restaurant_outlined,
  ParkPlaceKind.facilities => Icons.wc_outlined,
  ParkPlaceKind.shops => Icons.shopping_bag_outlined,
};

String attractionStatusLabel(AttractionStatus status) => switch (status) {
  AttractionStatus.open => 'Open',
  AttractionStatus.closed => 'Closed',
  AttractionStatus.maintenance => 'Maintenance',
};

IconData attractionIcon(String category) => switch (category) {
  'Water rides' => Icons.water_drop_outlined,
  'Family rides' => Icons.family_restroom,
  'Shows' => Icons.theater_comedy_outlined,
  _ => Icons.attractions_outlined,
};

String attractionErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to access this information.',
      'unauthenticated' => 'Please sign in again to continue.',
      'unavailable' || 'deadline-exceeded' =>
        'Unable to reach the park service. Check your connection and try again.',
      _ => 'Unable to load attractions. Please try again.',
    };
  }
  return 'Unable to load attractions. Please try again.';
}

class AttractionStatusBadge extends StatelessWidget {
  const AttractionStatusBadge({super.key, required this.status});
  final AttractionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AttractionStatus.open => const Color(0xFF25623C),
      AttractionStatus.closed => const Color(0xFF8C3030),
      AttractionStatus.maintenance => const Color(0xFF805400),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        attractionStatusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class AttractionMessage extends StatelessWidget {
  const AttractionMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: visitorRose),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

class AttractionSummaryCard extends StatelessWidget {
  const AttractionSummaryCard({
    super.key,
    required this.attraction,
    required this.onTap,
    this.actionLabel = 'View details',
  });
  final Attraction attraction;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFECE8),
                  foregroundColor: visitorRose,
                  child: Icon(attractionIcon(attraction.category)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attraction.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        attraction.category,
                        style: const TextStyle(color: Color(0xFF635A58)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AttractionStatusBadge(status: attraction.status),
                Text(
                  attraction.minHeightCm == 0
                      ? 'No minimum height listed'
                      : 'Minimum height ${attraction.minHeightCm} cm',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    actionLabel,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: visitorRose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: visitorRose),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

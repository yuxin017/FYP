import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/attraction_slot.dart';
import '../models/park_time.dart';
import '../models/queue_policy.dart';
import 'attraction_cover.dart';
import 'attraction_widgets.dart';

const queueRose = Color(0xFFAB3F4E);
const queueInk = Color(0xFF142532);
const queueBackground = Color(0xFFFCF8F6);

Color crowdColor(AttractionCrowd? crowd) => switch (crowd) {
  AttractionCrowd.low => const Color(0xFF31974A),
  AttractionCrowd.moderate => const Color(0xFFDE8A00),
  AttractionCrowd.busy => const Color(0xFFCC3E47),
  null => const Color(0xFF8B9297),
};

class QueueAttractionCard extends StatelessWidget {
  const QueueAttractionCard({
    super.key,
    required this.attraction,
    required this.onDetails,
    required this.onTimes,
    this.nextSlot,
    this.timesLoading = false,
    this.timesUnavailable = false,
    this.queueCount,
    this.reservable = false,
  });
  final Attraction attraction;
  final AttractionSlot? nextSlot;
  final bool timesLoading;
  final bool timesUnavailable;
  final int? queueCount;
  final bool reservable;
  final VoidCallback onDetails;
  final VoidCallback onTimes;

  @override
  Widget build(BuildContext context) {
    final open = attraction.status == AttractionStatus.open;
    final crowd = queueCount == null ? null : QueuePolicy.crowd(queueCount!);
    final rated =
        attraction.ratingCount > 0 &&
        attraction.ratingAverage != null &&
        attraction.ratingAverage! >= 1 &&
        attraction.ratingAverage! <= 5;
    final available =
        open && nextSlot != null && nextSlot!.remainingCapacity > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1E9E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onDetails,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AttractionCover(encoded: attraction.coverImageBase64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                attraction.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: queueInk,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Color(0xFF84898C),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(Icons.star, size: 14, color: queueRose),
                            Text(
                              rated
                                  ? attraction.ratingAverage!.toStringAsFixed(1)
                                  : 'Not rated',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF555D63),
                              ),
                            ),
                            const Text(
                              '|',
                              style: TextStyle(
                                color: Color(0xFFE3DFDD),
                                fontSize: 11,
                              ),
                            ),
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: open
                                  ? const Color(0xFF339448)
                                  : const Color(0xFFAF6B51),
                            ),
                            Text(
                              attractionStatusLabel(attraction.status),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF48535A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 16,
                              color: crowdColor(crowd),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                crowd == null
                                    ? 'Crowd unavailable'
                                    : '${crowd.label} crowd',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: crowdColor(crowd),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (queueCount != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '$queueCount queuing · ${QueuePolicy.intervalMinutes(queueCount!)} min booking interval',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF777E82),
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Tooltip(
                              message: 'Walking time is not available yet.',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.directions_walk,
                                    size: 13,
                                    color: Color(0xFF85898B),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    '— min walk',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF85898B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              '|',
                              style: TextStyle(
                                color: Color(0xFFE3DFDD),
                                fontSize: 10,
                              ),
                            ),
                            const Icon(
                              Icons.schedule,
                              size: 12,
                              color: Color(0xFF85898B),
                            ),
                            Text(
                              attraction.standbyMinutes == null
                                  ? 'Wait not reported'
                                  : '${attraction.standbyMinutes} min standby',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF777E82),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final status = timesLoading
                    ? 'Loading times…'
                    : timesUnavailable
                    ? 'Times unavailable'
                    : nextSlot == null
                    ? 'No upcoming return times'
                    : ParkTime.time(nextSlot!.startsAt);
                final details = Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 12,
                      color: Color(0xFF7D8386),
                    ),
                    const Text(
                      'Next virtual queue slot',
                      style: TextStyle(fontSize: 9, color: Color(0xFF6E777D)),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: nextSlot == null
                            ? const Color(0xFF7D8386)
                            : queueRose,
                      ),
                    ),
                    if (available)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF7ED),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Slots available',
                          style: TextStyle(
                            fontSize: 8,
                            color: Color(0xFF308141),
                          ),
                        ),
                      ),
                  ],
                );
                final button = OutlinedButton(
                  onPressed: onTimes,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: available ? Colors.white : queueRose,
                    backgroundColor: available ? queueRose : Colors.white,
                    side: const BorderSide(color: queueRose),
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    available && reservable ? 'Reserve' : 'View Times',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
                if (constraints.maxWidth < 270 ||
                    MediaQuery.textScalerOf(context).scale(10) > 12) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: 7),
                      Align(alignment: Alignment.centerRight, child: button),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    button,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

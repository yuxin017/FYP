import 'package:flutter/material.dart';
import '../../photos/photo_repository.dart';
import '../admin_widgets.dart';
import '../admin_models.dart';
import 'park_admin_repository.dart';

class AnomalyReviewPage extends StatefulWidget {
  final ParkAdminRepository repository;
  final List<AdminVisitor> visitors;
  final ValueChanged<String> onVisitor;
  const AnomalyReviewPage({
    super.key,
    required this.repository,
    required this.visitors,
    required this.onVisitor,
  });
  @override
  State<AnomalyReviewPage> createState() => _AnomalyReviewPageState();
}

class _AnomalyReviewPageState extends State<AnomalyReviewPage> {
  int days = 30;
  String query = '';
  late Future<Map<String, dynamic>> report = load();
  Future<Map<String, dynamic>> load() =>
      widget.repository.request('anomalies', {'days': days});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminHeading(
        'Unusual Activity Review',
        'Review activity signals and open a visitor record before taking action.',
        action: AdminButton(
          'Refresh Analysis',
          icon: Icons.refresh,
          onPressed: () => setState(() => report = load()),
        ),
      ),
      const SizedBox(height: 22),
      AdminCard(
        child: Row(
          children: [
            const Icon(Icons.manage_search, color: adminRose, size: 38),
            const SizedBox(width: 18),
            const Expanded(
              child: Text(
                'Signals highlight patterns for staff review. Family bookings and busy visitors can produce unusual activity. Review the actual history before changing account access.',
                style: TextStyle(color: adminMuted, height: 1.6),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Wrap(
        spacing: 13,
        runSpacing: 13,
        children: [
          for (final period in [7, 30, 90])
            ChoiceChip(
              label: Text('Last $period Days'),
              selected: days == period,
              onSelected: (_) => setState(() {
                days = period;
                report = load();
              }),
            ),
        ],
      ),
      const SizedBox(height: 18),
      TextField(
        onChanged: (v) => setState(() => query = v),
        decoration: const InputDecoration(
          hintText: 'Search visitor name or email',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 22),
      FutureBuilder<Map<String, dynamic>>(
        future: report,
        builder: (context, s) {
          if (s.hasError) return AdminCard(child: Text(photoError(s.error!)));
          if (!s.hasData) {
            return const Padding(
              padding: EdgeInsets.all(45),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final d = s.data!, flags = (d['flags'] as List).cast<Map>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminStats(
                children: [
                  AdminStat(
                    'Visitors Analysed',
                    '${d['samples']}',
                    'With activity in this period',
                    Icons.groups_outlined,
                  ),
                  AdminStat(
                    'Review Signals',
                    '${flags.length}',
                    'Accounts to review',
                    Icons.policy_outlined,
                  ),
                  AdminStat(
                    'Review Window',
                    '$days days',
                    'Updated from Firebase activity',
                    Icons.history,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                d['method'] as String,
                style: const TextStyle(fontSize: 12, color: adminMuted),
              ),
              const SizedBox(height: 22),
              if (flags.isEmpty)
                const AdminEmpty(
                  'No unusual activity signals',
                  'No review rules or learned activity outliers were triggered for this period.',
                ),
              for (final flag in flags)
                Builder(
                  builder: (context) {
                    final uid = flag['uid'] as String,
                        visitor = widget.visitors
                            .where((v) => v.id == uid)
                            .firstOrNull,
                        name = visitor?.name ?? visitorReference(uid),
                        email = visitor?.email ?? '';
                    if (!'$name $email'.toLowerCase().contains(
                      query.toLowerCase(),
                    )) {
                      return const SizedBox.shrink();
                    }
                    final metrics = flag['metrics'] as Map;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 17),
                      child: AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AdminAvatar(name),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            color: adminMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const AdminBadge('Review', tone: 'review'),
                                AdminButton(
                                  'Open Visitor Record',
                                  outlined: true,
                                  onPressed: () => widget.onVisitor(uid),
                                ),
                              ],
                            ),
                            const Divider(height: 30),
                            for (final reason
                                in (flag['reasons'] as List).cast<String>())
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Text(
                                  '• $reason',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 20,
                              runSpacing: 10,
                              children: [
                                Text('${metrics['reservations']} reservations'),
                                Text(
                                  '${metrics['cancellations']} cancellations',
                                ),
                                Text('${metrics['missed']} missed visits'),
                                Text('${metrics['orders']} orders'),
                                Text('${metrics['sessions']} device sessions'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ],
  );
}

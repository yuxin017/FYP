import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/models/attraction_slot.dart';
import '../../park/park_map_canvas.dart';
import '../../park/park_visit.dart';
import '../../photos/photo_repository.dart';
import '../admin_widgets.dart';
import 'park_admin_repository.dart';
import 'live_crowd_panel.dart';

class CrowdMonitoringPage extends StatefulWidget {
  final ParkAdminRepository repository;
  final VoidCallback onManageFacilities;
  const CrowdMonitoringPage({
    super.key,
    required this.repository,
    required this.onManageFacilities,
  });
  @override
  State<CrowdMonitoringPage> createState() => _CrowdMonitoringPageState();
}

class _CrowdMonitoringPageState extends State<CrowdMonitoringPage> {
  int days = 1;
  bool automatic = true, fetching = false;
  String query = '';
  String? selected;
  late Future<Map<String, dynamic>> report = load();
  Timer? timer;
  Future<Map<String, dynamic>> load() async {
    fetching = true;
    try {
      return await widget.repository.request('crowd', {'days': days});
    } finally {
      fetching = false;
    }
  }

  void refresh() {
    if (!fetching && mounted) setState(() => report = load());
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (automatic) refresh();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Color levelColor(String level) => switch (level) {
    'busy' => const Color(0xFFD16959),
    'moderate' => const Color(0xFFC49A48),
    'low' => const Color(0xFF559477),
    _ => adminMuted,
  };
  String levelLabel(String level) => switch (level) {
    'busy' => 'Busy',
    'moderate' => 'Moderate',
    'low' => 'Low',
    'unavailable' => 'Unavailable',
    _ => 'Not reported',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminHeading(
        'Crowd Monitoring',
        'Queue demand, peak visiting hours and recorded attraction journeys.',
        action: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AdminButton(
              'Refresh',
              outlined: true,
              icon: Icons.refresh,
              onPressed: refresh,
            ),
            AdminButton(
              'Manage Facilities',
              icon: Icons.attractions_outlined,
              onPressed: widget.onManageFacilities,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final period in [1, 7, 30])
            ChoiceChip(
              label: Text(period == 1 ? 'Today' : 'Last $period Days'),
              selected: days == period,
              onSelected: (_) {
                if (fetching) return;
                setState(() {
                  days = period;
                  report = load();
                });
              },
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: automatic,
                onChanged: (v) => setState(() => automatic = v),
              ),
              const Text('Refresh every 30 seconds'),
            ],
          ),
        ],
      ),
      const SizedBox(height: 20),
      FutureBuilder<Map<String, dynamic>>(
        future: report,
        builder: (context, s) {
          if (s.hasError) {
            return AdminCard(
              child: Column(
                children: [
                  Text(photoError(s.error!)),
                  const SizedBox(height: 15),
                  AdminButton('Try Again', onPressed: refresh),
                ],
              ),
            );
          }
          if (!s.hasData) {
            return const Padding(
              padding: EdgeInsets.all(50),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final data = s.data!, summary = data['summary'] as Map;
          final rows = (data['attractions'] as List).cast<Map>();
          final filtered = rows
              .where(
                (r) =>
                    '${r['name']}'.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          final places = <Attraction>[];
          for (final raw in (data['places'] as List).cast<Map>()) {
            try {
              places.add(
                Attraction.fromMap(
                  raw['id'] as String,
                  Map<String, dynamic>.from(raw),
                ),
              );
            } on Object {
              /* Legacy incomplete locations are omitted from the map. */
            }
          }
          final slots = [
            for (final row in (data['slots'] as List).cast<Map>())
              AttractionSlot(
                id: row['id'],
                attractionId: row['attractionId'],
                startsAt: DateTime.parse(row['startsAt']),
                endsAt: DateTime.parse(row['endsAt']),
                capacity: row['capacity'],
                bookedCount: row['bookedCount'],
                confirmedCount: row['confirmedCount'],
              ),
          ];
          final visit = ParkVisit(
            places: places,
            slots: slots,
            now: DateTime.parse(data['updatedAt']),
          );
          final focus = rows.where((r) => r['id'] == selected).firstOrNull;
          final hourly = (data['hourly'] as List).cast<Map>(),
              flows = (data['flows'] as List).cast<Map>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminStats(
                children: [
                  AdminStat(
                    'Confirmed Queue Places',
                    '${summary['confirmed']}',
                    'Today’s remaining return windows',
                    Icons.groups_outlined,
                  ),
                  AdminStat(
                    'Busy Attractions',
                    '${summary['busy']}',
                    '80% queue load or 60+ min standby',
                    Icons.local_fire_department_outlined,
                  ),
                  AdminStat(
                    'Completed Ride Entries',
                    '${summary['visits']}',
                    days == 1 ? 'Today' : 'Last $days days',
                    Icons.sensor_door_outlined,
                  ),
                  AdminStat(
                    'Visitor Accounts',
                    '${summary['visitorAccounts']}',
                    'With recorded ride entries',
                    Icons.people_outline,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ExpansionTile(
                title: const Text('Live Movement and Visitor Locations'),
                subtitle: const Text(
                  'Voluntary positions, movement between zones and peak hours',
                ),
                children: [
                  LiveCrowdPanel(repository: widget.repository, places: places),
                ],
              ),
              const SizedBox(height: 22),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Queue Demand Heatmap',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Heat represents confirmed places in today’s remaining return windows. Select a location to review demand and manage its availability.',
                      style: TextStyle(color: adminMuted, height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 390,
                      child: places.isEmpty
                          ? const Center(
                              child: Text(
                                'Add park locations to display the map.',
                              ),
                            )
                          : ParkMapCanvas(
                              visit: visit,
                              visible: places,
                              heatmap: true,
                              density: Map<String, dynamic>.from(
                                data['density'],
                              ),
                              selectedId: selected,
                              onPlace: (p) => setState(() => selected = p.id),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        for (final level in ['low', 'moderate', 'busy'])
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 12,
                                color: levelColor(level),
                              ),
                              const SizedBox(width: 6),
                              Text(levelLabel(level)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (focus != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${focus['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${focus['confirmed']} confirmed places • ${focus['standbyMinutes'] == null ? 'Standby wait not reported' : '${focus['standbyMinutes']} min standby'}',
                        ),
                        trailing: Text(
                          levelLabel(focus['level']),
                          style: TextStyle(color: levelColor(focus['level'])),
                        ),
                      ),
                    Text(
                      'Updated ${DateTime.parse(data['updatedAt']).toUtc().add(const Duration(hours: 8)).toIso8601String().substring(0, 19).replaceFirst('T', ' ')} MYT',
                      style: const TextStyle(fontSize: 11, color: adminMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Attraction Demand',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search attraction',
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 15),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(25),
                        child: Text('No attractions match your search.'),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Attraction')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Confirmed / Capacity')),
                            DataColumn(label: Text('Queue Load')),
                            DataColumn(label: Text('Standby')),
                            DataColumn(label: Text('Ride Entries')),
                          ],
                          rows: [
                            for (final r in filtered)
                              DataRow(
                                selected: selected == r['id'],
                                onSelectChanged: (_) =>
                                    setState(() => selected = r['id']),
                                cells: [
                                  DataCell(Text('${r['name']}')),
                                  DataCell(Text('${r['status']}')),
                                  DataCell(
                                    Text(
                                      '${r['confirmed']} / ${r['capacity']}',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${r['capacity'] == 0 ? '—' : '${((r['load'] as num) * 100).round()}%'} • ${levelLabel(r['level'])}',
                                      style: TextStyle(
                                        color: levelColor(r['level']),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      r['standbyMinutes'] == null
                                          ? 'Not reported'
                                          : '${r['standbyMinutes']} min',
                                    ),
                                  ),
                                  DataCell(Text('${r['visits']}')),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Peak Visiting Hours',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Completed attraction check-ins by hour in Malaysia time.',
                      style: TextStyle(color: adminMuted),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      height: 205,
                      child: CustomPaint(
                        painter: CrowdHourChart(hourly),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hourly.every((h) => h['visits'] == 0)
                          ? 'No ride entries recorded in this period.'
                          : 'Peak hour: ${hourly.reduce((a, b) => a['visits'] >= b['visits'] ? a : b)['hour'].toString().padLeft(2, '0')}:00',
                      style: const TextStyle(color: adminMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Journeys Between Attractions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Successive check-ins on the same pass within three hours on the same day. Only entries that include a pass reference contribute to these totals.',
                      style: TextStyle(color: adminMuted, height: 1.6),
                    ),
                    const SizedBox(height: 15),
                    if (flows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(25),
                        child: Text(
                          'No linked attraction journeys recorded yet.',
                        ),
                      )
                    else
                      for (final flow in flows)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.route_outlined,
                            color: adminRose,
                          ),
                          title: Text('${flow['from']} → ${flow['to']}'),
                          trailing: Text('${flow['count']} journeys'),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class CrowdHourChart extends CustomPainter {
  final List<Map> hours;
  CrowdHourChart(this.hours);
  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = hours.fold<num>(
      1,
      (n, h) => math.max(n, h['visits'] as num),
    );
    final width = size.width / 24, height = size.height - 30;
    final paint = Paint()..color = adminBorder;
    canvas.drawLine(Offset(0, height), Offset(size.width, height), paint);
    for (final h in hours) {
      final x = (h['hour'] as int) * width,
          value = (h['visits'] as num) / maxCount;
      paint.color = adminRose.withValues(alpha: .85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + width * .16,
            height - height * value,
            width * .68,
            height * value,
          ),
          const Radius.circular(4),
        ),
        paint,
      );
      if ((h['hour'] as int) % 3 == 0) {
        final label = TextPainter(
          text: TextSpan(
            text: '${h['hour'].toString().padLeft(2, '0')}:00',
            style: const TextStyle(fontSize: 10, color: adminMuted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x, height + 10));
      }
    }
  }

  @override
  bool shouldRepaint(CrowdHourChart oldDelegate) => oldDelegate.hours != hours;
}

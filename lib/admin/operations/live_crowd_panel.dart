import 'dart:async';
import 'package:flutter/material.dart';
import '../../attractions/models/attraction.dart';
import '../../park/park_map_canvas.dart';
import '../../park/park_visit.dart';
import '../admin_widgets.dart';
import 'park_admin_repository.dart';

class LiveCrowdPanel extends StatefulWidget {
  final ParkAdminRepository repository;
  final List<Attraction> places;
  const LiveCrowdPanel({
    super.key,
    required this.repository,
    required this.places,
  });
  @override
  State<LiveCrowdPanel> createState() => _LiveCrowdPanelState();
}

class _LiveCrowdPanelState extends State<LiveCrowdPanel> {
  late Future<Map<String, dynamic>> result = load();
  Timer? timer;
  bool fetching = false;
  Future<Map<String, dynamic>> load() async {
    fetching = true;
    try {
      return await widget.repository.request('liveCrowd', {});
    } finally {
      fetching = false;
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !fetching) setState(() => result = load());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Live Visitor Distribution',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Refresh live visitors',
              onPressed: () => setState(() => result = load()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Recent voluntary locations form this heatmap. Positions expire after two minutes. Movement and hourly counts cover the last 24 hours; individuals are not identified.',
          style: TextStyle(color: adminMuted, height: 1.6),
        ),
        const SizedBox(height: 18),
        FutureBuilder<Map<String, dynamic>>(
          future: result,
          builder: (context, s) {
            if (s.hasError) {
              return const Text(
                'Live visitor information could not load. Please refresh.',
              );
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = s.data!,
                grid = Map<String, dynamic>.from(data['density'] as Map? ?? {}),
                count = grid['visitorCount'] ?? 0;
            final hours = (data['hourly'] as List? ?? []).cast<Map>(),
                flows = (data['flows'] as List? ?? []).cast<Map>();
            final peak = hours.fold<Map?>(
              null,
              (best, h) =>
                  best == null ||
                      (h['visitors'] as num) > (best['visitors'] as num)
                  ? h
                  : best,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    Chip(label: Text('$count visitors sharing now')),
                    Chip(
                      label: Text(
                        peak == null || peak['visitors'] == 0
                            ? 'No peak recorded yet'
                            : 'Peak hour: ${peak['hour']}:00 • ${peak['visitors']} visitors',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 360,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ParkMapCanvas(
                          visit: ParkVisit(
                            places: widget.places,
                            slots: const [],
                            now: DateTime.now(),
                          ),
                          visible: widget.places,
                          onPlace: (_) {},
                          heatmap: true,
                          density: grid,
                        ),
                      ),
                      if (count == 0)
                        const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(15),
                              child: Text(
                                'No recent visitor locations are being shared.',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Movement Between Campus Zones',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The map is divided into rows A–D from north to south and columns 1–4 from west to east.',
                  style: TextStyle(color: adminMuted),
                ),
                if (flows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text('No movement between zones has been recorded.'),
                  ),
                for (final flow in flows)
                  ListTile(
                    leading: const Icon(Icons.moving),
                    title: Text('Zone ${flow['from']} → Zone ${flow['to']}'),
                    trailing: Text('${flow['count']} movements'),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

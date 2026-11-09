import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/application_api.dart';
import '../photos/photo_repository.dart';
import '../photos/photo_widgets.dart';
import '../photos/photo_gallery_pages.dart';
import '../visitor/pages/rewards_page.dart';
import '../visitor/visitor_main_page.dart';

abstract class ParkOffersRepository {
  Stream<List<Map<String, dynamic>>> campaigns();
  Stream<Map<String, dynamic>?> weather();
  Future<void> claimWeather();
}

class FirebaseParkOffersRepository implements ParkOffersRepository {
  @override
  Stream<List<Map<String, dynamic>>> campaigns() => FirebaseFirestore.instance
      .collection('campaigns')
      .where('public', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'code': d.id}).toList());
  @override
  Stream<Map<String, dynamic>?> weather() {
    final today = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 8))
        .toIso8601String()
        .substring(0, 10);
    return FirebaseFirestore.instance
        .collection('parkWeather')
        .doc(today)
        .snapshots()
        .map((d) => d.data());
  }

  @override
  Future<void> claimWeather() async {
    await ApplicationApi().post('/v1/park/claimWeather');
  }
}

class ParkOffersPage extends StatefulWidget {
  final ParkOffersRepository repository;
  const ParkOffersPage({super.key, required this.repository});
  @override
  State<ParkOffersPage> createState() => _ParkOffersPageState();
}

class _ParkOffersPageState extends State<ParkOffersPage> {
  late final offers = widget.repository.campaigns(),
      weather = widget.repository.weather();
  String filter = 'All';
  bool busy = false;
  Future<void> claim() async {
    setState(() => busy = true);
    try {
      await widget.repository.claimWeather();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your benefit is ready'),
          content: const Text(
            'Your rainy-day voucher has been added to Points & Vouchers. Check its terms and expiry before using it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RewardsPage(initialSection: 'vouchers'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(photoError(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Park Offers',
    helpTitle: 'Using your park offers',
    helpText:
        'Open an offer to check its dates, eligible purchases and terms. Copy its promotion code and apply it at ticket or photo checkout. When a rainy-day benefit is available, collect it here and find the voucher in Points & Vouchers.',
    selectedIndex: 0,
    busy: busy,
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'A little more magic for your visit',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: photoInk,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Discover current offers and benefits. Each offer shows where it applies and how to use it.',
          style: TextStyle(height: 1.6, color: Color(0xFF7C8289)),
        ),
        const SizedBox(height: 23),
        StreamBuilder<Map<String, dynamic>?>(
          stream: weather,
          builder: (context, s) {
            final d = s.data;
            if (d == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: PhotoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (d['precipitationMm'] as num? ?? 0) > .1
                              ? Icons.umbrella_outlined
                              : Icons.wb_cloudy_outlined,
                          size: 43,
                          color: photoRose,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(d['temperature'] as num?)?.toStringAsFixed(1) ?? '—'}°C',
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Rain: ${d['precipitationMm']} mm • Open-Meteo',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF7C8289),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (d['rainQualified'] == true) ...[
                      const Divider(height: 30),
                      const Text(
                        'Your rainy-day benefit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        d['voucherBenefit'] as String? ??
                            'A benefit is available for eligible visitors.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 15),
                      PhotoButton(
                        'Collect My Benefit',
                        busy: busy,
                        onPressed: busy ? null : claim,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'One voucher per visitor with a valid park ticket for the affected day.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C8289),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        Row(
          children: [
            for (final v in ['All', 'Tickets', 'Photos'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(v),
                    selected: filter == v,
                    onSelected: (_) => setState(() => filter = v),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: offers,
          builder: (context, s) {
            if (s.hasError) {
              return const PhotoPanel(
                child: Text('Unable to load park offers. Please try again.'),
              );
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final now = DateTime.now(),
                rows =
                    s.data!
                        .where(
                          (o) =>
                              o['active'] == true &&
                              (o['startsAt'] as Timestamp).toDate().isBefore(
                                now,
                              ) &&
                              (o['endsAt'] as Timestamp).toDate().isAfter(
                                now,
                              ) &&
                              (filter == 'All' ||
                                  (o['scopes'] as List).contains(
                                    filter.toLowerCase(),
                                  )),
                        )
                        .toList()
                      ..sort(
                        (a, b) => (a['endsAt'] as Timestamp).compareTo(
                          b['endsAt'] as Timestamp,
                        ),
                      );
            if (rows.isEmpty) {
              return const PhotoPanel(
                child: Padding(
                  padding: EdgeInsets.all(25),
                  child: Column(
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 57,
                        color: photoRose,
                      ),
                      SizedBox(height: 17),
                      Text(
                        'More offers are on the way',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Visit again to discover new park benefits.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final o in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: PhotoPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [photoRose, Color(0xFFD7A295)],
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.redeem_outlined,
                                  size: 35,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  o['type'] == 'percent'
                                      ? '${o['value']}% OFF'
                                      : '${photoMoney(o['value'] as num)} OFF',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  o['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 17),
                          if ((o['description'] as String? ?? '').isNotEmpty)
                            Text(
                              o['description'] as String,
                              style: const TextStyle(height: 1.6),
                            ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o['code'] as String,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: photoRose,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: o['code'] as String),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Promotion code copied.'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy_outlined, size: 17),
                                label: const Text('Copy Code'),
                              ),
                            ],
                          ),
                          const Divider(height: 27),
                          Text(
                            'Applies to ${(o['scopes'] as List).join(' and ')} • Minimum ${photoMoney(o['minimumMinor'] as num? ?? 0)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Valid until ${(o['endsAt'] as Timestamp).toDate().toLocal().toString().substring(0, 10)} • ${o['perUserLimit']} use(s) per visitor',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C8289),
                            ),
                          ),
                          if (o['allowPoints'] == false)
                            const Padding(
                              padding: EdgeInsets.only(top: 7),
                              child: Text(
                                'Loyalty points cannot be combined with this offer.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7C8289),
                                ),
                              ),
                            ),
                          const SizedBox(height: 17),
                          PhotoButton(
                            'Use This Offer',
                            outlined: true,
                            onPressed: () {
                              if ((o['scopes'] as List).contains('tickets')) {
                                Navigator.of(
                                  context,
                                ).popUntil((r) => r.isFirst);
                                VisitorMainPage.openTickets(context, 'catalog');
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhotoHubPage(
                                      repository: FirebasePhotoRepository(),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

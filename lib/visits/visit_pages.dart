import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../device/nfc_pass.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import '../attractions/widgets/attraction_cover.dart';
import '../attractions/widgets/queue_attraction_card.dart';
import '../reservations/widgets/reservation_widgets.dart';
import '../visitor/pages/rewards_page.dart';
import 'visit_repository.dart';

class VisitHistoryPage extends StatefulWidget {
  final VisitRepository repository;
  const VisitHistoryPage({super.key, required this.repository});
  @override
  State<VisitHistoryPage> createState() => _VisitHistoryPageState();
}

class _VisitHistoryPageState extends State<VisitHistoryPage> {
  late final stream = widget.repository.visits();
  String filter = 'Upcoming';
  @override
  Widget build(BuildContext context) => ReservationFrame(
    title: 'Visited Attractions',
    navigationIndex: 4,
    body: StreamBuilder<List<AttractionVisit>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load your visits. Please reopen this page.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now(), all = snapshot.data!;
        final records = all
            .where(
              (v) =>
                  filter == 'All' ||
                  (filter == 'Upcoming'
                      ? v.status == 'confirmed' &&
                            (v.endsAt?.isAfter(now) ?? false)
                      : v.status == 'checked_in'),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your park adventures',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: queueInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Return to your attraction passes, relive your visits and share your experience.',
              style: TextStyle(color: Color(0xFF6D737A)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                for (final value in ['Upcoming', 'Visited', 'All'])
                  ChoiceChip(
                    label: Text(value),
                    selected: filter == value,
                    onSelected: (_) => setState(() => filter = value),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (records.isEmpty)
              ReservationPanel(
                child: Column(
                  children: [
                    const Icon(
                      Icons.attractions_outlined,
                      size: 56,
                      color: queueRose,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      filter == 'Upcoming'
                          ? 'Your next adventure awaits'
                          : 'Your visit history starts here',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reserve an attraction from Virtual Queue. Your confirmed passes and checked-in visits will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final visit in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttractionPassPage(
                        repository: widget.repository,
                        id: visit.id,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(15),
                  child: ReservationPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        VisitSummary(
                          repository: widget.repository,
                          visit: visit,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.circle, size: 9, color: queueRose),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                visit.stateAt(now),
                                style: const TextStyle(
                                  color: queueRose,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Text('View details'),
                            const Icon(Icons.chevron_right, size: 19),
                          ],
                        ),
                        if (visit.points > 0) ...[
                          const Divider(height: 25),
                          Text(
                            '+${visit.points} loyalty points earned',
                            style: const TextStyle(color: queueRose),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class VisitSummary extends StatelessWidget {
  final VisitRepository repository;
  final AttractionVisit visit;
  const VisitSummary({
    super.key,
    required this.repository,
    required this.visit,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StreamBuilder<Map<String, dynamic>>(
        stream: repository.attraction(visit.attractionId),
        builder: (context, snapshot) => AttractionCover(
          encoded: snapshot.data?['coverImageBase64'] as String?,
          width: 108,
          height: 135,
          radius: 13,
          placeholderIcon: Icons.attractions_outlined,
        ),
      ),
      const SizedBox(width: 17),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visit.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: queueInk,
              ),
            ),
            const SizedBox(height: 14),
            if (visit.startsAt != null)
              Text(
                '${reservationDayLabel(visit.startsAt!)}\n${returnWindow(visit.startsAt!, visit.endsAt!)}',
                style: const TextStyle(height: 1.8, color: Color(0xFF59636D)),
              ),
            if (visit.groupName != null) ...[
              const SizedBox(height: 9),
              Text(visit.groupName!, style: const TextStyle(color: queueRose)),
            ],
          ],
        ),
      ),
    ],
  );
}

class AttractionPassPage extends StatefulWidget {
  final VisitRepository repository;
  final String id;
  const AttractionPassPage({
    super.key,
    required this.repository,
    required this.id,
  });
  @override
  State<AttractionPassPage> createState() => _AttractionPassPageState();
}

class _AttractionPassPageState extends State<AttractionPassPage> {
  late final stream = widget.repository.visit(widget.id);
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void enlarge() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Attraction Entrance Pass',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1,
              child: QrImageView(
                data: 'RQ1:${widget.id}',
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close pass'),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ReservationFrame(
    title: 'Attraction Entrance Pass',
    body: StreamBuilder<AttractionVisit?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load this pass. Please try again.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == null) {
          return const Center(
            child: Text('This attraction pass could not be found.'),
          );
        }
        final visit = snapshot.data!;
        final state = visit.stateAt(DateTime.now()),
            active =
                visit.status == 'confirmed' &&
                (visit.endsAt?.isAfter(DateTime.now()) ?? false);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ReservationPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VisitSummary(repository: widget.repository, visit: visit),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(
                        visit.status == 'checked_in'
                            ? Icons.check_circle_outline
                            : Icons.event_available_outlined,
                        color: active || visit.status == 'checked_in'
                            ? Colors.green.shade700
                            : queueRose,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state,
                          style: TextStyle(
                            color: active || visit.status == 'checked_in'
                                ? Colors.green.shade700
                                : queueRose,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 36),
                  if (active) ...[
                    Center(
                      child: QrImageView(
                        data: 'RQ1:${widget.id}',
                        size: 224,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Show this QR code at the attraction entrance',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF59636D)),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: enlarge,
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('Enlarge entrance pass'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          NfcPassService.present(context, 'RQ1:${visit.id}'),
                      icon: const Icon(Icons.nfc),
                      label: const Text('Tap with NFC'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your pass is available during the displayed return window. Staff will scan it once to confirm entry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF7A7E85)),
                    ),
                  ],
                  if (visit.status == 'checked_in') ...[
                    const Icon(
                      Icons.verified_outlined,
                      size: 80,
                      color: queueRose,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Enjoy your adventure!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: queueInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Entry confirmed • +${visit.points} loyalty points',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ReservationButton(
                      label: 'View Points Earned',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VisitPointsPage(
                            repository: widget.repository,
                            visit: visit,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          visit.completedAt(DateTime.now()) && !visit.rated
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RateVisitPage(
                                  repository: widget.repository,
                                  visit: visit,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.star_outline),
                      label: Text(
                        visit.rated
                            ? 'Rating submitted'
                            : visit.completedAt(DateTime.now())
                            ? 'Rate Your Experience'
                            : 'Rating opens after your visit',
                      ),
                    ),
                  ],
                  if (!active && visit.status != 'checked_in')
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            size: 64,
                            color: queueRose,
                          ),
                          SizedBox(height: 15),
                          Text(
                            'This pass is no longer available for entry.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF6D737A)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Keep your admission ticket available. Each attraction pass can be checked in once.',
                    style: TextStyle(color: Color(0xFF6D737A), fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class RateVisitPage extends StatefulWidget {
  final VisitRepository repository;
  final AttractionVisit visit;
  const RateVisitPage({
    super.key,
    required this.repository,
    required this.visit,
  });
  @override
  State<RateVisitPage> createState() => _RateVisitPageState();
}

class _RateVisitPageState extends State<RateVisitPage> {
  int stars = 0;
  final categories = <String>{}, message = TextEditingController();
  bool anonymous = false, busy = false;
  Uint8List? photo;
  String? error;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> choosePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 75,
      );
      if (file == null) return;
      final source = await file.readAsBytes();
      if (source.length > 12000000) {
        throw StateError('Choose an image smaller than 12 MB.');
      }
      final decoded = img.decodeImage(source);
      if (decoded == null) throw StateError('Choose a readable photo.');
      final image = img.copyResize(
        decoded,
        width: decoded.width > 800 ? 800 : decoded.width,
      );
      final encoded = Uint8List.fromList(img.encodeJpg(image, quality: 65));
      if (encoded.length > 200000) throw StateError('Choose a smaller photo.');
      if (mounted) setState(() => photo = encoded);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> submit() async {
    if (stars == 0) {
      setState(() => error = 'Choose a star rating before submitting.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.rate(
        widget.visit.id,
        stars,
        categories.toList(),
        message.text.trim(),
        anonymous,
        photo == null ? null : base64Encode(photo!),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you. Your rating has been saved.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ReservationFrame(
    title: 'Rate ${widget.visit.name}',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ReservationPanel(
          child: VisitSummary(
            repository: widget.repository,
            visit: widget.visit,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'How was your experience?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: queueInk,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 1; i <= 5; i++)
              Flexible(
                child: IconButton(
                  tooltip: '$i stars',
                  onPressed: busy ? null : () => setState(() => stars = i),
                  icon: Icon(
                    i <= stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 48,
                    color: queueRose,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          stars == 0
              ? 'Select your rating'
              : [
                  '',
                  'Needs improvement',
                  'Fair',
                  'Good',
                  'Very Good',
                  'Excellent',
                ][stars],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, color: queueRose),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in [
              ('Queue experience', Icons.people_outline),
              ('Staff service', Icons.person_outline),
              ('Ride experience', Icons.attractions_outlined),
              ('Accessibility', Icons.accessible),
            ])
              FilterChip(
                avatar: Icon(item.$2, size: 22),
                label: Text(item.$1),
                selected: categories.contains(item.$1),
                onSelected: busy
                    ? null
                    : (selected) => setState(() {
                        if (selected) {
                          categories.add(item.$1);
                        } else {
                          categories.remove(item.$1);
                        }
                      }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Tell us more (optional)',
          style: TextStyle(fontSize: 16, color: queueInk),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: message,
          enabled: !busy,
          maxLength: 500,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'What made your visit memorable?',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share feedback anonymously'),
          subtitle: const Text(
            'Your name will be hidden from any published feedback.',
          ),
          value: anonymous,
          onChanged: busy ? null : (value) => setState(() => anonymous = value),
        ),
        if (photo != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  photo!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 5,
                top: 5,
                child: IconButton.filled(
                  tooltip: 'Remove photo',
                  onPressed: busy ? null : () => setState(() => photo = null),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : choosePhoto,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(
            photo == null ? 'Add a photo (optional)' : 'Change photo',
          ),
        ),
        const SizedBox(height: 18),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(error!, style: const TextStyle(color: queueRose)),
          ),
        ReservationButton(
          label: 'Submit Rating',
          onPressed: submit,
          busy: busy,
        ),
        const SizedBox(height: 20),
        const Text(
          'Your feedback helps us improve park experiences.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6D737A)),
        ),
      ],
    ),
  );
}

class VisitPointsPage extends StatelessWidget {
  final VisitRepository repository;
  final AttractionVisit visit;
  const VisitPointsPage({
    super.key,
    required this.repository,
    required this.visit,
  });
  @override
  Widget build(BuildContext context) => ReservationFrame(
    title: 'Points Earned',
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 10),
        const Center(
          child: CircleAvatar(
            radius: 64,
            backgroundColor: Color(0xFFEBD2CD),
            child: Icon(Icons.stars_rounded, size: 108, color: queueRose),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '+${visit.points}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 64,
            color: queueRose,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Text(
          'loyalty points',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, color: queueRose),
        ),
        const SizedBox(height: 18),
        Text(
          'Thanks for visiting ${visit.name}!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: queueInk,
          ),
        ),
        const SizedBox(height: 25),
        ReservationPanel(
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.star_outline, color: queueRose),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Attraction visit')),
                  Text('${visit.points} points'),
                ],
              ),
              const Divider(height: 30),
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: queueRose),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Total points earned',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${visit.points} points',
                    style: const TextStyle(
                      color: queueRose,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        StreamBuilder<int>(
          stream: repository.balance(),
          builder: (context, snapshot) => ReservationPanel(
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: queueRose, size: 40),
                const SizedBox(width: 17),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current balance'),
                      const SizedBox(height: 7),
                      Text(
                        snapshot.hasError
                            ? 'Unable to load balance'
                            : snapshot.hasData
                            ? '${snapshot.data} points'
                            : 'Loading…',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          color: queueRose,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ReservationButton(
          label: 'View Points History',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RewardsPage(initialSection: 'history'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: visit.completedAt(DateTime.now()) && !visit.rated
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RateVisitPage(repository: repository, visit: visit),
                  ),
                )
              : null,
          icon: const Icon(Icons.star_outline),
          label: Text(
            visit.rated ? 'Rating submitted' : 'Rate Your Experience',
          ),
        ),
      ],
    ),
  );
}

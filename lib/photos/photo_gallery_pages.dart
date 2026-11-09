import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image/image.dart' as img;
import '../attractions/models/park_time.dart';
import '../visitor/pages/face_recognition_settings_page.dart';
import 'photo_repository.dart';
import 'photo_widgets.dart';
import 'photo_editor.dart';
import 'photo_checkout_pages.dart';

Future<void> downloadParkPhoto(
  BuildContext context,
  PhotoRepository repo,
  String id, {
  Map<String, dynamic>? edits,
}) async {
  try {
    final result = await repo.request('download', {
      'photoId': id,
      'edits': ?edits,
    });
    await FilePicker.saveFile(
      fileName: result['fileName'] as String? ?? 'ThemePark-photo.jpg',
      type: FileType.custom,
      allowedExtensions: ['jpg'],
      bytes: base64Decode(result['imageBase64'] as String),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

void openPhotoHistory(BuildContext context, PhotoRepository repo) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoHistoryPage(repository: repo)),
    );
void openPhotoCart(BuildContext context, PhotoRepository repo) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoCartPage(repository: repo)),
    );

class PhotoHubPage extends StatefulWidget {
  final PhotoRepository repository;
  const PhotoHubPage({super.key, required this.repository});
  @override
  State<PhotoHubPage> createState() => _PhotoHubPageState();
}

class _PhotoHubPageState extends State<PhotoHubPage> {
  late final face = widget.repository.faceProfile(),
      matches = widget.repository.matches(),
      orders = widget.repository.orders();
  @override
  void initState() {
    super.initState();
    widget.repository.cart.ready;
  }

  void setup() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          FaceRecognitionSettingsPage(repository: widget.repository),
    ),
  );
  void gallery() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MatchedPhotosPage(repository: widget.repository),
    ),
  );
  void preview(ParkPhoto photo) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PhotoPreviewPage(repository: widget.repository, photo: photo),
    ),
  );
  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'My Park Photos',
    actions: [
      AnimatedBuilder(
        animation: widget.repository.cart,
        builder: (context, _) => IconButton(
          tooltip: 'Photo Cart',
          onPressed: () => openPhotoCart(context, widget.repository),
          icon: Badge(
            isLabelVisible: widget.repository.cart.items.isNotEmpty,
            label: Text('${widget.repository.cart.items.length}'),
            child: const Icon(Icons.shopping_cart_outlined, color: photoRose),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Photo Purchase History',
        onPressed: () => openPhotoHistory(context, widget.repository),
        icon: const Icon(Icons.history, color: photoRose),
      ),
    ],
    body: StreamBuilder<Map<String, dynamic>>(
      stream: face,
      builder: (context, status) => StreamBuilder<List<ParkPhoto>>(
        stream: matches,
        builder: (context, snapshot) {
          if (status.hasError || snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load your photos. Please reopen this page.',
              ),
            );
          }
          if (!status.hasData || !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final active = status.data!['enabled'] == true,
              photos = snapshot.data!,
              matching = [
                'queued',
                'running',
              ].contains(status.data!['matchingStatus']);
          final today = ParkTime.date(DateTime.now()),
              newToday = photos
                  .where(
                    (p) =>
                        p.takenAt != null && ParkTime.date(p.takenAt!) == today,
                  )
                  .length;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              InkWell(
                onTap: setup,
                borderRadius: BorderRadius.circular(15),
                child: PhotoPanel(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.face_retouching_natural,
                        color: photoRose,
                        size: 35,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              active
                                  ? 'Face matching active'
                                  : 'Face matching is off',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              active
                                  ? (matching
                                        ? 'Finding your park photos…'
                                        : 'New attraction photos are matched automatically.')
                                  : 'Set up an optional selfie to find your park photos.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7C8289),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: photoRose),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (photos.isNotEmpty) ...[
                InkWell(
                  onTap: gallery,
                  child: PhotoPanel(
                    child: Row(
                      children: [
                        const Icon(Icons.wb_sunny_outlined, color: photoRose),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$newToday new photos today',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'Check out your latest photos below!',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7C8289),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Matches',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: gallery,
                      child: const Text('See All'),
                    ),
                  ],
                ),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .82,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final photo in photos.take(4))
                      PhotoTile(photo: photo, onTap: () => preview(photo)),
                  ],
                ),
                const SizedBox(height: 16),
                PhotoButton('View All Matched Photos', onPressed: gallery),
              ] else ...[
                const SizedBox(height: 25),
                Image.asset(
                  'assets/images/rewards/photo.png',
                  height: 145,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  active
                      ? 'Your memories are on their way'
                      : 'Find your park photos automatically',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: photoInk,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  active
                      ? 'Photos taken by our photographers will appear here when a match is found. You can also enter a photo code.'
                      : 'Activate face matching to find photos taken during your visit, or use the photographer’s photo code.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7C8289),
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
                PhotoButton(
                  active ? 'Refresh Photo Matches' : 'Set Up Face Matching',
                  onPressed: active
                      ? () async {
                          try {
                            await widget.repository.request(
                              'refreshMatches',
                              {},
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Checking for your park photos.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        }
                      : setup,
                ),
              ],
              const SizedBox(height: 12),
              PhotoButton(
                'Browse with Photo Code',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PhotoCodePage(repository: widget.repository),
                  ),
                ),
                outlined: true,
              ),
              const SizedBox(height: 14),
              const Text(
                'Optional. Your face profile is used only for photo matching and can be removed at any time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7C8289),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'Photo Orders',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<ParkPhoto>>(
                stream: orders,
                builder: (context, history) => InkWell(
                  onTap: () => openPhotoHistory(context, widget.repository),
                  child: PhotoPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.photo_library_outlined,
                        color: photoRose,
                      ),
                      title: Text(
                        history.hasError
                            ? 'View photo orders'
                            : history.data?.isEmpty ?? true
                            ? 'No photo orders yet'
                            : '${history.data!.length} photo orders',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'View, download and collect your photos',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class MatchedPhotosPage extends StatefulWidget {
  final PhotoRepository repository;
  const MatchedPhotosPage({super.key, required this.repository});
  @override
  State<MatchedPhotosPage> createState() => _MatchedPhotosPageState();
}

class _MatchedPhotosPageState extends State<MatchedPhotosPage> {
  late final stream = widget.repository.matches();
  final search = TextEditingController();
  String filter = 'All', place = 'All attractions';
  String? selected;
  bool searching = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> favorite(ParkPhoto photo) async {
    try {
      await widget.repository.request('favorite', {
        'photoId': photo.photoId,
        'favorite': photo.data['favorite'] != true,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Matched Photos',
    actions: [
      IconButton(
        tooltip: 'Search photos',
        onPressed: () => setState(() => searching = !searching),
        icon: const Icon(Icons.search, color: photoRose),
      ),
      IconButton(
        tooltip: 'Photo Cart',
        onPressed: () => openPhotoCart(context, widget.repository),
        icon: const Icon(Icons.shopping_cart_outlined, color: photoRose),
      ),
    ],
    body: StreamBuilder<List<ParkPhoto>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load matched photos. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!,
            today = ParkTime.date(DateTime.now()),
            query = search.text.trim().toLowerCase();
        final photos = all
            .where(
              (p) =>
                  (query.isEmpty ||
                      ('${p.title} ${p.place}').toLowerCase().contains(
                        query,
                      )) &&
                  (filter != 'Today' ||
                      p.takenAt != null &&
                          ParkTime.date(p.takenAt!) == today) &&
                  (filter != 'Favourites' || p.data['favorite'] == true) &&
                  (filter != 'Attractions' ||
                      place == 'All attractions' ||
                      p.place == place),
            )
            .toList();
        final picked = photos.where((p) => p.photoId == selected).firstOrNull;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  PhotoPanel(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 35,
                          color: photoRose,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '${all.length}',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'photos matched',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7C8289),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (searching) ...[
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search attraction or photo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final value in [
                          'All',
                          'Today',
                          'Attractions',
                          'Favourites',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(
                                value,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: filter == value,
                              onSelected: (_) => setState(() => filter = value),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (filter == 'Attractions')
                    DropdownButtonFormField<String>(
                      initialValue: place,
                      items: [
                        for (final value in {
                          'All attractions',
                          ...all.map((p) => p.place).where((p) => p.isNotEmpty),
                        })
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (v) =>
                          setState(() => place = v ?? 'All attractions'),
                    ),
                  const SizedBox(height: 18),
                  if (photos.isEmpty)
                    const PhotoPanel(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No photos match this selection. Try another filter.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final day
                      in photos
                          .map(
                            (p) => p.takenAt == null
                                ? 'Park memories'
                                : ParkTime.date(p.takenAt!),
                          )
                          .toSet()) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        day == today ? 'Today • $day' : day,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: .8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final photo in photos.where(
                          (p) =>
                              (p.takenAt == null
                                  ? 'Park memories'
                                  : ParkTime.date(p.takenAt!)) ==
                              day,
                        ))
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected == photo.photoId
                                    ? photoRose
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: PhotoTile(
                              photo: photo,
                              onTap: () =>
                                  setState(() => selected = photo.photoId),
                              onFavorite: () => favorite(photo),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 17),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      picked == null ? 'Select a photo' : '1 photo selected',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: PhotoButton(
                      'Preview Photo',
                      onPressed: picked == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PhotoPreviewPage(
                                  repository: widget.repository,
                                  photo: picked,
                                  photos: photos,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PhotoPreviewPage extends StatefulWidget {
  final PhotoRepository repository;
  final ParkPhoto photo;
  final List<ParkPhoto> photos;
  const PhotoPreviewPage({
    super.key,
    required this.repository,
    required this.photo,
    this.photos = const [],
  });
  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  late ParkPhoto selected = widget.photo;
  late final entitlements = widget.repository.entitlements();
  Map<String, dynamic> edits = {};
  Uint8List? editedPreview;
  final aspects = <String, double>{};
  double get aspect {
    if (editedPreview != null) {
      final image = img.decodeImage(editedPreview!);
      if (image != null) return image.width / image.height;
    }
    return aspects.putIfAbsent(selected.photoId, () {
      try {
        final image = img.decodeImage(base64Decode(selected.preview));
        if (image != null) return image.width / image.height;
      } catch (_) {}
      return 4 / 3;
    });
  }

  bool busy = false;
  Future<void> edit() async {
    final value = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PhotoEditorPage(preview: selected.preview, initialEdits: edits),
      ),
    );
    if (value == null || !mounted) return;
    setState(() => busy = true);
    try {
      final bytes = await compute(applyPhotoChanges, {
        'source': base64Decode(selected.preview),
        'edits': value,
      });
      if (mounted) {
        setState(() {
          edits = value;
          editedPreview = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load the edited preview. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void format({String initial = 'digital', bool owned = false}) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoFormatPage(
            repository: widget.repository,
            photo: selected,
            edits: edits,
            preview: editedPreview == null
                ? selected.preview
                : base64Encode(editedPreview!),
            initialFormat: initial,
            ownsDigital: owned,
          ),
        ),
      );
  Future<void> savePreview() async {
    try {
      await FilePicker.saveFile(
        fileName: 'ThemePark-preview-${selected.photoId.substring(0, 8)}.jpg',
        type: FileType.custom,
        allowedExtensions: ['jpg'],
        bytes: editedPreview ?? base64Decode(selected.preview),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save this preview. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> menu(String action) async {
    try {
      if (action == 'hide') {
        await widget.repository.request('hide', {'photoId': selected.photoId});
        if (mounted) Navigator.pop(context);
      }
      if (action == 'favorite') {
        await widget.repository.request('favorite', {
          'photoId': selected.photoId,
          'favorite': selected.data['favorite'] != true,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Photo Preview',
    busy: busy,
    actions: [
      PopupMenuButton<String>(
        tooltip: 'Photo options',
        onSelected: menu,
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'favorite',
            child: Text('Toggle Favourite'),
          ),
          const PopupMenuItem(value: 'hide', child: Text('This isn’t me')),
        ],
      ),
    ],
    body: StreamBuilder<List<ParkPhoto>>(
      stream: entitlements,
      builder: (context, snapshot) {
        final owned =
            snapshot.data?.any((p) => p.photoId == selected.photoId) ?? false;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: Stack(
                children: [
                  if (editedPreview != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        editedPreview!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    PhotoImage(
                      selected.preview,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  if (selected.confidence != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      width: 110,
                      child: PhotoPanel(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          'Face match\n${selected.confidence}% score',
                          style: const TextStyle(
                            fontSize: 10,
                            color: photoRose,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              selected.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: photoInk,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${selected.place}${selected.takenAt == null ? '' : ' • ${ParkTime.date(selected.takenAt!)} · ${ParkTime.time(selected.takenAt!)}'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C8289)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photographer upload',
              style: TextStyle(fontSize: 11, color: Color(0xFF7C8289)),
            ),
            const SizedBox(height: 17),
            if (widget.photos.length > 1)
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final photo in widget.photos)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: InkWell(
                          onTap: busy
                              ? null
                              : () => setState(() {
                                  selected = photo;
                                  edits = {};
                                  editedPreview = null;
                                }),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: photo.photoId == selected.photoId
                                    ? photoRose
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: PhotoImage(
                              photo.preview,
                              width: 68,
                              height: 75,
                              radius: 8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PhotoButton(
                    'Edit Photo',
                    onPressed: busy ? null : edit,
                    outlined: true,
                    icon: Icons.edit_outlined,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: PhotoButton(
                    'Save Preview',
                    onPressed: busy ? null : savePreview,
                    outlined: true,
                    icon: Icons.ios_share_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            PhotoButton(
              owned ? 'Download Digital Photo' : 'Edit & Purchase',
              onPressed: busy
                  ? null
                  : owned
                  ? () => downloadParkPhoto(
                      context,
                      widget.repository,
                      selected.photoId,
                      edits: edits,
                    )
                  : () => format(),
            ),
            const SizedBox(height: 10),
            PhotoButton(
              'Send to Kiosk',
              onPressed: busy
                  ? null
                  : () => format(initial: 'print', owned: owned),
              outlined: true,
            ),
            const SizedBox(height: 17),
            const Text(
              'High-resolution, watermark-free digital copies are available after purchase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7C8289),
                height: 1.6,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PhotoCodePage extends StatefulWidget {
  final PhotoRepository repository;
  const PhotoCodePage({super.key, required this.repository});
  @override
  State<PhotoCodePage> createState() => _PhotoCodePageState();
}

class _PhotoCodePageState extends State<PhotoCodePage> {
  final code = TextEditingController();
  bool camera = false, busy = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> claim([String? scanned]) async {
    if (busy) return;
    final value = scanned ?? code.text.trim();
    if (value.isEmpty) {
      setState(() => error = 'Enter the photo code from your photographer.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      camera = false;
    });
    try {
      await widget.repository.request('claim', {'code': value});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added to your gallery.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Find Photos with Code',
    busy: busy,
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.photo_camera_outlined, size: 80, color: photoRose),
        const SizedBox(height: 20),
        const Text(
          'Your park memories',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        const Text(
          'Enter the photo code or scan the QR provided by your photographer. Face matching is optional.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.6, color: Color(0xFF7C8289)),
        ),
        const SizedBox(height: 24),
        PhotoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: code,
                enabled: !busy,
                onSubmitted: (_) => claim(),
                decoration: const InputDecoration(
                  labelText: 'Photo Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              if (camera)
                SizedBox(
                  height: 250,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final value = capture.barcodes.firstOrNull?.rawValue;
                      if (value != null && !busy) claim(value);
                    },
                    errorBuilder: (_, error) => const Center(
                      child: Text(
                        'Camera unavailable. Enter the photo code instead.',
                      ),
                    ),
                  ),
                ),
              PhotoButton(
                camera ? 'Close Camera' : 'Scan Photo QR',
                onPressed: busy ? null : () => setState(() => camera = !camera),
                outlined: true,
                icon: Icons.qr_code_scanner,
              ),
              const SizedBox(height: 15),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Text(error!, style: const TextStyle(color: photoRose)),
                ),
              PhotoButton('Find My Photo', onPressed: claim, busy: busy),
            ],
          ),
        ),
      ],
    ),
  );
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../photos/photo_widgets.dart';
import '../../photos/photo_repository.dart';
import '../admin_widgets.dart';
import 'park_admin_repository.dart';

class LandmarkManagementPage extends StatefulWidget {
  final ParkAdminRepository repository;
  const LandmarkManagementPage({super.key, required this.repository});
  @override
  State<LandmarkManagementPage> createState() => _LandmarkManagementPageState();
}

class _LandmarkManagementPageState extends State<LandmarkManagementPage> {
  late final stream = widget.repository.records('landmarkReferences');
  String query = '', filter = 'All';
  final busy = <String>{};
  Future<void> toggle(Map<String, dynamic> row) async {
    setState(() => busy.add(row['id']));
    try {
      await widget.repository.request('setLandmarkActive', {
        'id': row['id'],
        'active': row['active'] != true,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(photoError(e))));
      }
    } finally {
      if (mounted) setState(() => busy.remove(row['id']));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminHeading(
        'Landmark Recognition',
        'Reference images used to identify park locations.',
        action: AdminButton(
          'Add Landmark',
          icon: Icons.add_a_photo_outlined,
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => LandmarkEditor(repository: widget.repository),
          ),
        ),
      ),
      const SizedBox(height: 22),
      AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Build clear location references',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Use actual photographs of park signs, building facades and distinctive landmarks. Link each image to its location on the park map. Visitors confirm the detected landmark before changing their starting point.',
              style: TextStyle(color: adminMuted, height: 1.6),
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: 'Search landmark or location',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              children: [
                for (final v in ['All', 'Active', 'Inactive'])
                  ChoiceChip(
                    label: Text(v),
                    selected: filter == v,
                    onSelected: (_) => setState(() => filter = v),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, s) {
          if (s.hasError) {
            return const AdminEmpty(
              'Unable to load landmarks',
              'Please reopen this section.',
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = s.data!
              .where(
                (r) =>
                    '${r['name']} ${r['placeName']}'.toLowerCase().contains(
                      query.toLowerCase(),
                    ) &&
                    (filter == 'All' ||
                        (r['active'] == true) == (filter == 'Active')),
              )
              .toList();
          if (rows.isEmpty) {
            return const AdminEmpty(
              'No landmarks found',
              'Add a reference image for an existing park location.',
            );
          }
          return LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth > 1000
                  ? 3
                  : c.maxWidth > 650
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: columns,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: .9,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final row in rows)
                    AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: PhotoImage(
                                (row['features'] as Map?)?['previewBase64']
                                        as String? ??
                                    '',
                                width: double.infinity,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            row['name'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            row['placeName'] as String? ?? '',
                            style: const TextStyle(color: adminMuted),
                          ),
                          const SizedBox(height: 12),
                          AdminBadge(
                            row['active'] == true ? 'Active' : 'Inactive',
                            tone: row['active'] == true ? 'active' : 'archived',
                          ),
                          const SizedBox(height: 16),
                          AdminButton(
                            row['active'] == true
                                ? 'Deactivate Reference'
                                : 'Activate Reference',
                            outlined: true,
                            onPressed: busy.contains(row['id'])
                                ? null
                                : () => toggle(row),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ],
  );
}

class LandmarkEditor extends StatefulWidget {
  final ParkAdminRepository repository;
  const LandmarkEditor({super.key, required this.repository});
  @override
  State<LandmarkEditor> createState() => _LandmarkEditorState();
}

class _LandmarkEditorState extends State<LandmarkEditor> {
  late final places = widget.repository.records('attractions');
  final name = TextEditingController();
  Uint8List? image;
  String? placeId, error;
  bool busy = false;
  Future<void> choose() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      final file = picked.firstOrNull;
      if (file == null) return;
      if (await file.length() > 12000000) {
        throw StateError('Choose a file smaller than 12 MB.');
      }
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) throw StateError('Choose a readable photo.');
      final source = img.bakeOrientation(decoded),
          resized = img.copyResize(
            source,
            width: source.width > 1200 ? 1200 : source.width,
          ),
          bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 82));
      if (bytes.length > 2000000) throw StateError('Choose a smaller photo.');
      if (mounted) setState(() => image = bytes);
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    }
  }

  Future<void> save() async {
    if (name.text.trim().length < 2 || placeId == null || image == null) {
      setState(() => error = 'Add a photo, name and park location.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.request('saveLandmark', {
        'name': name.text.trim(),
        'placeId': placeId,
        'imageBase64': base64Encode(image!),
        'active': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Add Landmark Reference'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.5,
                child: image == null
                    ? Container(
                        color: const Color(0xFFFBF1EF),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 65,
                          color: adminRose,
                        ),
                      )
                    : Image.memory(image!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 15),
              AdminButton(
                'Choose Reference Photo',
                outlined: true,
                icon: Icons.upload_file,
                onPressed: busy ? null : choose,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                enabled: !busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Landmark Name'),
              ),
              const SizedBox(height: 18),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: places,
                builder: (context, s) => DropdownButtonFormField<String>(
                  initialValue: placeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Park Location',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in s.data ?? [])
                      if (p['deletedAt'] == null)
                        DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(
                            p['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => placeId = v),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Choose a clear sign or building. Avoid faces, temporary decorations and repeated patterns.',
                style: TextStyle(fontSize: 12, color: adminMuted, height: 1.6),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AdminButton(
          busy ? 'Processing…' : 'Save Reference',
          onPressed: busy ? null : save,
        ),
      ],
    ),
  );
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import '../../photos/photo_repository.dart';
import '../../photos/photo_widgets.dart';
import '../admin_widgets.dart';
import '../admin_models.dart';
import 'photo_admin_repository.dart';

class PhotoManagement extends StatefulWidget {
  final PhotoAdminRepository repository;
  final List<AdminVisitor> visitors;
  const PhotoManagement({
    super.key,
    required this.repository,
    required this.visitors,
  });
  @override
  State<PhotoManagement> createState() => _PhotoManagementState();
}

class _PhotoManagementState extends State<PhotoManagement> {
  late final photos = widget.repository.records('parkPhotos'),
      orders = widget.repository.records('photoOrders'),
      matches = widget.repository.records('photoMatches'),
      reviews = widget.repository.records('photoMatchReviews');
  String tab = 'Photos', query = '';
  int page = 0;
  final busy = <String>{};
  String? error;
  String name(String uid) =>
      widget.visitors.where((v) => v.id == uid).firstOrNull?.name ??
      (uid.length > 12 ? '${uid.substring(0, 12)}…' : uid);
  Future<void> action(
    String operation,
    ParkPhoto photo,
    Map<String, dynamic> data,
  ) async {
    if (busy.contains(photo.id)) return;
    setState(() {
      busy.add(photo.id);
      error = null;
    });
    try {
      final result = await widget.repository.request(operation, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              operation == 'recheck'
                  ? 'Matching completed: ${result['matched'] ?? 0} visitors.'
                  : 'Photo record updated.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy.remove(photo.id));
    }
  }

  Future<void> original(ParkPhoto photo) async {
    try {
      final value = await widget.repository.request('adminOriginal', {
        'photoId': photo.id,
      });
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      photo.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: PhotoImage(
                        value['imageBase64'] as String,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    }
  }

  Future<void> code(ParkPhoto photo) async {
    final value = photo.data['claimCode'] as String?;
    if (value == null || value.isEmpty) {
      setState(
        () => error =
            'This photo does not have a collection code. Upload it again with a new reference.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photographer Photo Code'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: 'PP1:$value',
                size: 245,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 15),
              SelectableText(value, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Share this code with the photographed visitor. Valid for 24 hours after upload.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: adminMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            child: const Text('Copy Code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void orderDetails(ParkPhoto order) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(photoOrderReference(order.id)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Visitor: ${name(order.data['ownerUid'] as String)}'),
              const SizedBox(height: 12),
              Text('Delivery: ${order.data['deliveryEmail'] ?? '—'}'),
              Text('Email status: ${order.data['emailStatus'] ?? 'pending'}'),
              const Divider(height: 25),
              for (final item in (order.data['items'] as List).cast<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['title'] as String),
                  subtitle: Text(
                    '${photoFormat(item['format'] as String)} • ${item['quantity'] ?? 1} copies',
                  ),
                  trailing: Text(photoMoney(item['priceMinor'] as num)),
                ),
              const Divider(),
              Text(
                'Total: ${photoMoney(order.data['totalMinor'] as num)}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: adminRose,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ParkPhoto>>(
    stream: photos,
    builder: (context, p) => StreamBuilder<List<ParkPhoto>>(
      stream: orders,
      builder: (context, o) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 14,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Photos',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: adminDark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage park photography, photo matches and purchases.',
                    style: TextStyle(color: adminMuted),
                  ),
                ],
              ),
              AdminButton(
                'Upload Park Photo',
                icon: Icons.add_photo_alternate_outlined,
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (_) =>
                        PhotoUploadDialog(repository: widget.repository),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (p.hasError || o.hasError)
            const AdminCard(
              child: Text(
                'Unable to load photo records. Please refresh the portal.',
              ),
            ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _stat(
                'Park Photos',
                '${p.data?.length ?? 0}',
                Icons.photo_library_outlined,
              ),
              _stat(
                'Active Photos',
                '${p.data?.where((v) => v.data['status'] == 'active').length ?? 0}',
                Icons.camera_alt_outlined,
              ),
              _stat(
                'Photo Orders',
                '${o.data?.length ?? 0}',
                Icons.receipt_long_outlined,
              ),
              _stat(
                'Confirmed Sales',
                photoMoney(
                  o.data?.fold<int>(
                        0,
                        (total, v) =>
                            total + (v.data['totalMinor'] as int? ?? 0),
                      ) ??
                      0,
                ),
                Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 25),
          AdminCard(
            child: Wrap(
              spacing: 14,
              runSpacing: 15,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final value in [
                  'Photos',
                  'Matches',
                  'Review Requests',
                  'Orders',
                ])
                  ChoiceChip(
                    label: Text(value),
                    selected: tab == value,
                    onSelected: (_) => setState(() {
                      tab = value;
                      page = 0;
                    }),
                  ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    onChanged: (v) => setState(() {
                      query = v.trim().toLowerCase();
                      page = 0;
                    }),
                    decoration: const InputDecoration(
                      hintText: 'Search photo, visitor or order',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          if (tab == 'Photos')
            _catalogue(p.data ?? [])
          else if (tab == 'Orders')
            _orderTable(o.data ?? [])
          else
            StreamBuilder<List<ParkPhoto>>(
              stream: tab == 'Matches' ? matches : reviews,
              builder: (context, s) => s.hasError
                  ? const AdminCard(
                      child: Text('Unable to load matching records.'),
                    )
                  : _matchTable(s.data ?? []),
            ),
        ],
      ),
    ),
  );
  Widget _stat(String title, String value, IconData icon) => SizedBox(
    width: 230,
    child: AdminCard(
      child: Row(
        children: [
          Icon(icon, color: adminRose, size: 31),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: adminMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: adminDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _catalogue(List<ParkPhoto> all) {
    final records =
        all
            .where(
              (p) =>
                  query.isEmpty ||
                  ('${p.title} ${p.place}').toLowerCase().contains(query),
            )
            .toList()
          ..sort(
            (a, b) =>
                ((b.data['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime(1970))
                    .compareTo(
                      (a.data['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime(1970),
                    ),
          );
    return Column(
      children: [
        if (records.isEmpty)
          const AdminCard(
            child: AdminEmpty(
              'No park photos found',
              'Upload a photographer photo to make it available for matching and photo-code access.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 1100
                  ? 4
                  : c.maxWidth >= 800
                  ? 3
                  : c.maxWidth >= 530
                  ? 2
                  : 1;
              return GridView.builder(
                itemCount: records.skip(page * 12).take(12).length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 17,
                  mainAxisSpacing: 17,
                  childAspectRatio: .76,
                ),
                itemBuilder: (context, index) {
                  final photo = records[page * 12 + index],
                      archived = photo.data['status'] == 'archived';
                  return AdminCard(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => original(photo),
                            child: PhotoImage(
                              photo.preview,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          photo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${photo.data['faceCount'] ?? 0} faces • ${photo.data['matchedVisitorCount'] ?? 0} matches',
                          style: const TextStyle(
                            fontSize: 11,
                            color: adminMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            AdminBadge(
                              archived ? 'Archived' : 'Active',
                              tone: archived ? 'inactive' : 'active',
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              enabled: !busy.contains(photo.id),
                              onSelected: (value) {
                                if (value == 'code') code(photo);
                                if (value == 'original') original(photo);
                                if (value == 'recheck') {
                                  action('recheck', photo, {
                                    'photoId': photo.id,
                                  });
                                }
                                if (value == 'archive') {
                                  action('archive', photo, {
                                    'photoId': photo.id,
                                    'archived': !archived,
                                  });
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'code',
                                  child: Text('Show Photo Code'),
                                ),
                                const PopupMenuItem(
                                  value: 'original',
                                  child: Text('View Original'),
                                ),
                                const PopupMenuItem(
                                  value: 'recheck',
                                  child: Text('Recheck Matches'),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(
                                    archived
                                        ? 'Restore Photo'
                                        : 'Archive Photo',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: 15),
        _pagination(records.length),
      ],
    );
  }

  Widget _orderTable(List<ParkPhoto> all) {
    final rows = all
        .where(
          (o) =>
              query.isEmpty ||
              ('${photoOrderReference(o.id)} ${name(o.data['ownerUid'] as String)} ${o.data['deliveryEmail']}')
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return Column(
      children: [
        AdminCard(
          padding: EdgeInsets.zero,
          child: rows.isEmpty
              ? const AdminEmpty(
                  'No photo orders found',
                  'Confirmed customer photo purchases will appear here.',
                )
              : AdminTable(
                  minWidth: 900,
                  columns: const [
                    DataColumn(label: Text('Order')),
                    DataColumn(label: Text('Visitor')),
                    DataColumn(label: Text('Photos')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Delivery')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final order in rows.skip(page * 12).take(12))
                      DataRow(
                        cells: [
                          DataCell(Text(photoOrderReference(order.id))),
                          DataCell(
                            Text(name(order.data['ownerUid'] as String)),
                          ),
                          DataCell(
                            Text('${(order.data['items'] as List).length}'),
                          ),
                          DataCell(
                            Text(photoMoney(order.data['totalMinor'] as num)),
                          ),
                          DataCell(
                            AdminBadge(
                              order.data['emailStatus'] == 'sent'
                                  ? 'Sent'
                                  : 'Pending',
                              tone: order.data['emailStatus'] == 'sent'
                                  ? 'active'
                                  : 'pending',
                            ),
                          ),
                          DataCell(
                            TextButton(
                              onPressed: () => orderDetails(order),
                              child: const Text('View Order'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 15),
        _pagination(rows.length),
      ],
    );
  }

  Widget _matchTable(List<ParkPhoto> all) {
    final rows = all
        .where(
          (r) =>
              query.isEmpty ||
              ('${r.data['photoId']} ${name(r.data['ownerUid'] as String)}')
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return Column(
      children: [
        AdminCard(
          padding: EdgeInsets.zero,
          child: rows.isEmpty
              ? const AdminEmpty(
                  'No matching records found',
                  'Face matches, photo-code access and visitor review requests appear here.',
                )
              : AdminTable(
                  minWidth: 930,
                  columns: const [
                    DataColumn(label: Text('Photo')),
                    DataColumn(label: Text('Visitor')),
                    DataColumn(label: Text('Source')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final record in rows.skip(page * 12).take(12))
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              record.data['title'] as String? ??
                                  record.data['photoId'] as String,
                            ),
                          ),
                          DataCell(
                            Text(name(record.data['ownerUid'] as String)),
                          ),
                          DataCell(
                            Text(
                              record.data['source'] == 'photo-code'
                                  ? 'Photo code'
                                  : record.data['score'] is num
                                  ? 'Face match ${((record.data['score'] as num) * 100).round()}%'
                                  : 'Visitor report',
                            ),
                          ),
                          DataCell(
                            AdminBadge(
                              tab == 'Review Requests'
                                  ? (record.data['status'] as String? ?? 'open')
                                  : record.data['hidden'] == true
                                  ? 'Hidden'
                                  : 'Visible',
                              tone: record.data['hidden'] == true
                                  ? 'inactive'
                                  : 'active',
                            ),
                          ),
                          DataCell(
                            tab == 'Review Requests'
                                ? TextButton(
                                    onPressed:
                                        record.data['status'] == 'reviewed' ||
                                            busy.contains(record.id)
                                        ? null
                                        : () => action(
                                            'resolveReview',
                                            record,
                                            {'reviewId': record.id},
                                          ),
                                    child: const Text('Mark Reviewed'),
                                  )
                                : const Text('—'),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 15),
        _pagination(rows.length),
      ],
    );
  }

  Widget _pagination(int count) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(
        '${count == 0 ? 0 : page * 12 + 1}–${(page * 12 + 12).clamp(0, count)} of $count',
        style: const TextStyle(color: adminMuted, fontSize: 12),
      ),
      const SizedBox(width: 15),
      IconButton(
        tooltip: 'Previous page',
        onPressed: page == 0 ? null : () => setState(() => page--),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Next page',
        onPressed: (page + 1) * 12 >= count
            ? null
            : () => setState(() => page++),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class PhotoUploadDialog extends StatefulWidget {
  final PhotoAdminRepository repository;
  const PhotoUploadDialog({super.key, required this.repository});
  @override
  State<PhotoUploadDialog> createState() => _PhotoUploadDialogState();
}

class _PhotoUploadDialogState extends State<PhotoUploadDialog> {
  final title = TextEditingController();
  late final places = widget.repository.places();
  late String requestId = widget.repository.newRequestId();
  String? attractionId, error;
  DateTime takenAt = DateTime.now();
  Uint8List? bytes;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      final file = result.firstOrNull;
      if (file == null) return;
      if (await file.length() > 12000000) {
        throw StateError('Choose a photo smaller than 12 MB.');
      }
      final selectedBytes = await file.readAsBytes();
      final decoded = img.decodeImage(selectedBytes);
      if (decoded == null) {
        throw StateError('Choose a readable JPEG or PNG photo.');
      }
      final source = img.bakeOrientation(decoded),
          resized = img.copyResize(
            source,
            width: source.width > 2400 ? 2400 : source.width,
          );
      if (!mounted) return;
      setState(() {
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
        requestId = widget.repository.newRequestId();
        if (title.text.isEmpty) {
          title.text = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        }
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Unable to open the selected photo.',
        );
      }
    }
  }

  Future<void> date() async {
    final day = await showDatePicker(
      context: context,
      initialDate: takenAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(takenAt),
    );
    if (time != null && mounted) {
      setState(
        () => takenAt = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> upload() async {
    if (bytes == null || title.text.trim().length < 2) {
      setState(() => error = 'Choose a photo and enter its title.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.request('upload', {
        'requestId': requestId,
        'title': title.text.trim(),
        'takenAt': takenAt.toUtc().toIso8601String(),
        'attractionId': attractionId ?? '',
        'imageBase64': base64Encode(bytes!),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo uploaded. ${result['matched'] ?? 0} visitors matched.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload Park Photo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: adminDark,
                ),
              ),
              const SizedBox(height: 20),
              if (bytes == null)
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF1EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 75,
                    color: adminRose,
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes!, height: 240, fit: BoxFit.contain),
                ),
              const SizedBox(height: 15),
              AdminButton(
                'Choose Photo',
                outlined: true,
                onPressed: busy ? null : choose,
                icon: Icons.upload_file_outlined,
              ),
              const SizedBox(height: 23),
              TextField(
                controller: title,
                enabled: !busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Photo Title'),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: places,
                builder: (context, s) => DropdownButtonFormField<String>(
                  initialValue: attractionId,
                  decoration: const InputDecoration(
                    labelText: 'Attraction / Photo Spot',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Other park location'),
                    ),
                    for (final place in s.data ?? [])
                      DropdownMenuItem(
                        value: place['id'] as String,
                        child: Text(place['name'] as String),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => attractionId = v),
                ),
              ),
              const SizedBox(height: 15),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: adminRose,
                ),
                title: const Text('Photo Capture Time'),
                subtitle: Text(takenAt.toString().substring(0, 16)),
                trailing: const Icon(Icons.edit_outlined, size: 19),
                onTap: busy ? null : date,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AdminButton(
                      'Cancel',
                      outlined: true,
                      onPressed: busy ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: AdminButton(
                      busy ? 'Uploading & Matching…' : 'Upload & Match',
                      onPressed: busy ? null : upload,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

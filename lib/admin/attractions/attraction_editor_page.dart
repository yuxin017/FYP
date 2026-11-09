import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'data/admin_attraction_store.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/widgets/attraction_widgets.dart';
import '../portal/admin_theme.dart';
import 'attraction_admin_guard.dart';
import '../../attractions/widgets/attraction_cover.dart';
import 'cover_photo.dart';
import '../../attractions/data/slot_reader.dart';
import '../../attractions/widgets/attraction_queue_summary.dart';

class AttractionEditorPage extends StatefulWidget {
  const AttractionEditorPage({
    super.key,
    required this.store,
    required this.adminAccess,
    this.attraction,
    this.kind = ParkPlaceKind.attractions,
    this.pickCover,
    this.slotReader,
  });
  final AdminAttractionStore store;
  final ValueListenable<bool> adminAccess;
  final Attraction? attraction;
  final ParkPlaceKind kind;
  final Future<Uint8List?> Function()? pickCover;
  final SlotReader? slotReader;

  @override
  State<AttractionEditorPage> createState() => _AttractionEditorPageState();
}

class _AttractionEditorPageState extends State<AttractionEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _standby = TextEditingController();
  final _photoField = GlobalKey<FormFieldState<String>>();
  final _height = TextEditingController();
  final _capacity = TextEditingController();
  final _mapX = TextEditingController();
  final _mapY = TextEditingController();
  late final String _id;
  Attraction? _original;
  String? _category;
  AttractionStatus _status = AttractionStatus.closed;
  bool _saving = false;
  bool _reloading = false;
  String? _error;
  bool _conflict = false;
  String? _cover;
  AttractionCrowd? _crowd;
  bool _pickingPhoto = false;
  ParkPlaceKind get _kind => _original?.placeKind ?? widget.kind;
  bool get _isRide => _kind == ParkPlaceKind.attractions;
  String get _itemName => _kind.itemName;
  static const _categories = [
    'Thrill rides',
    'Family rides',
    'Water rides',
    'Shows',
  ];

  @override
  void initState() {
    super.initState();
    _original = widget.attraction;
    _id = _original?.id ?? widget.store.newAttractionId();
    _fill(_original);
  }

  void _fill(Attraction? attraction) {
    _name.text = attraction?.name ?? '';
    _description.text = attraction?.description ?? '';
    _standby.text = attraction?.standbyMinutes?.toString() ?? '';
    _cover = attraction?.coverImageBase64;
    _photoField.currentState?.didChange(_cover);
    _crowd = attraction?.crowdLevel;
    _height.text = attraction?.minHeightCm.toString() ?? '0';
    _capacity.text =
        (attraction?.reservationCapacity ??
                Attraction.defaultReservationCapacity)
            .toString();
    _mapX.text = attraction?.mapX.toString() ?? '';
    _mapY.text = attraction?.mapY.toString() ?? '';
    _category = attraction?.category ?? (_isRide ? null : _kind.label);
    _status = attraction?.status ?? AttractionStatus.closed;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _standby.dispose();
    _height.dispose();
    _capacity.dispose();
    _mapX.dispose();
    _mapY.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_saving || _pickingPhoto || !widget.adminAccess.value) return;
    setState(() {
      _pickingPhoto = true;
      _error = null;
    });
    try {
      Uint8List? bytes;
      if (widget.pickCover != null) {
        bytes = await widget.pickCover!();
      } else {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        bytes = await photo?.readAsBytes();
      }
      if (bytes == null) return;
      final encoded = encodeAttractionCover(bytes);
      if (!mounted) return;
      setState(() => _cover = encoded);
      _photoField.currentState?.didChange(encoded);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to select this photo. Please choose another.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  String? _coordinate(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || !number.isFinite
        ? 'Enter a valid number using a decimal point.'
        : null;
  }

  Future<void> _save() async {
    if (_saving ||
        _pickingPhoto ||
        _reloading ||
        !widget.adminAccess.value ||
        !_form.currentState!.validate()) {
      return;
    }
    final replacement = Attraction(
      id: _id,
      name: _name.text,
      category: _category!,
      status: _status,
      minHeightCm: int.parse(_height.text.trim()),
      reservationCapacity: int.parse(_capacity.text.trim()),
      mapX: double.parse(_mapX.text.trim()),
      mapY: double.parse(_mapY.text.trim()),
      description: _description.text,
      coverImageBase64: _cover,
      crowdLevel: _crowd,
      standbyMinutes: int.tryParse(_standby.text.trim()),
    );
    setState(() {
      _saving = true;
      _error = null;
      _conflict = false;
    });
    try {
      if (_original == null) {
        await widget.store.createAttraction(replacement);
      } else {
        await widget.store.updateAttraction(
          original: _original!,
          replacement: replacement,
        );
      }
      if (!mounted) return;
      // Release PopScope before returning from the editor.
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.adminAccess.value) {
          Navigator.of(context).pop(true);
        }
      });
    } on AttractionConflict catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _conflict = _original != null;
        });
      }
    } on FirebaseException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Attraction save failed: ${error.plugin}/${error.code}');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        setState(
          () => _error = switch (error.code) {
            'permission-denied' =>
              'Firebase denied this save (permission-denied). Your admin access or database rules need to be checked. Your entered details have been kept.',
            'unauthenticated' =>
              'Please sign in again before saving. Your entered details have been kept.',
            'unavailable' || 'deadline-exceeded' =>
              'The save could not be confirmed. Check your connection and retry; your entered details have been kept.',
            _ =>
              'Unable to save the $_itemName (${error.code}). Your entered details have been kept. Please try again.',
          },
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Unexpected attraction save error (${error.runtimeType}): $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        setState(
          () => _error =
              'Unable to save the $_itemName. Your entered details have been kept. Please try again.',
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _reloadLatest() async {
    if (_saving || _reloading || !widget.adminAccess.value) return;
    setState(() {
      _reloading = true;
      _error = null;
    });
    try {
      final latest = await widget.store.watchAttraction(_id).first;
      if (!mounted) return;
      if (latest == null) {
        setState(
          () =>
              _error = 'This $_itemName no longer exists. Return to the list.',
        );
      } else {
        setState(() {
          _original = latest;
          _fill(latest);
          _conflict = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to load the latest information. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _reloading || _pickingPhoto;
    final categories = {..._categories, ?_category}.toList();
    final itemHeading =
        '${_itemName[0].toUpperCase()}${_itemName.substring(1)}';
    return AttractionAdminGuard(
      access: widget.adminAccess,
      child: PopScope(
        canPop: !busy,
        child: Scaffold(
          backgroundColor: AdminTheme.background,
          appBar: AppBar(
            title: Text(
              _original == null ? 'Add $_itemName' : 'Edit $_itemName',
            ),
            backgroundColor: AdminTheme.background,
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      '$itemHeading information',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRide
                          ? 'Set the photo and details customers see in Virtual Queue. Changes are saved to the park database.'
                          : 'Set the details customers see on the park map under ${_kind.label}.',
                    ),
                    const SizedBox(height: 22),
                    FormField<String>(
                      key: _photoField,
                      initialValue: _cover,
                      validator: (value) =>
                          _isRide &&
                              _original == null &&
                              (value == null || value.isEmpty)
                          ? 'Add a cover photo.'
                          : null,
                      builder: (field) => Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: field.hasError
                                ? Theme.of(context).colorScheme.error
                                : AdminTheme.border,
                          ),
                        ),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AttractionCover(
                              encoded: _cover,
                              width: 150,
                              height: 150,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isRide
                                      ? 'Customer cover photo'
                                      : 'Cover photo (optional)',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'JPG, PNG or WebP · up to 8 MB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AdminTheme.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _pickPhoto,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                  label: Text(
                                    _pickingPhoto
                                        ? 'Processing photo…'
                                        : _cover == null
                                        ? 'Choose cover photo'
                                        : 'Replace cover photo',
                                  ),
                                ),
                                if (field.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      field.errorText!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _name,
                      enabled: !busy,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: '$itemHeading name',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? (_isRide
                                ? 'Enter an attraction name.'
                                : 'Enter a name.')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      enabled: !busy,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 1200,
                      decoration: InputDecoration(
                        labelText: '$itemHeading description',
                        hintText: _isRide
                            ? 'Describe the experience, safety guidance and what visitors should know.'
                            : 'Tell visitors what they can find here.',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? (_isRide
                                ? 'Enter an attraction description.'
                                : 'Enter a description.')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    if (_isRide)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('editor-category-$_category'),
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final category in categories)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() => _category = value),
                        validator: (value) =>
                            value == null ? 'Choose a category.' : null,
                      )
                    else
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Facility type',
                        ),
                        child: Text(_kind.label),
                      ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<AttractionStatus>(
                      isExpanded: true,
                      key: ValueKey('editor-status-${_status.name}'),
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: _isRide ? 'Ride status' : 'Status',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final status in AttractionStatus.values)
                          DropdownMenuItem(
                            value: status,
                            child: Text(attractionStatusLabel(status)),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _status = value!),
                    ),
                    if (_isRide) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _height,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimum height (cm)',
                          helperText:
                              'Use 0 when no minimum height is specified.',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final height = int.tryParse(value?.trim() ?? '');
                          return height == null || height < 0 || height > 250
                              ? 'Enter a whole number from 0 to 250 cm.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _capacity,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Capacity per entry window',
                          helperText:
                              'Used for new automatic 15-minute windows.',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final capacity = int.tryParse(value?.trim() ?? '');
                          return capacity == null ||
                                  capacity < 1 ||
                                  capacity > 1000
                              ? 'Enter a whole number from 1 to 1000.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Current queue information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Crowd updates automatically from confirmed bookings. Staff can report the standby wait.',
                        style: TextStyle(color: AdminTheme.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      AttractionQueueSummary(
                        attractionId: _id,
                        reader: widget.slotReader,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _standby,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Standby wait (minutes)',
                          helperText:
                              'Leave blank if the wait has not been reported.',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final minutes = int.tryParse(value.trim());
                          return minutes == null || minutes < 0 || minutes > 600
                              ? 'Enter a whole number from 0 to 600 minutes.'
                              : null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Map position',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use the park map’s coordinate system. Editing a name does not change its map position.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _mapX,
                      enabled: !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Map X',
                        border: OutlineInputBorder(),
                      ),
                      validator: _coordinate,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mapY,
                      enabled: !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Map Y',
                        border: OutlineInputBorder(),
                      ),
                      validator: _coordinate,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      if (_conflict)
                        TextButton(
                          onPressed: busy ? null : _reloadLatest,
                          child: const Text('Load latest (discard my edits)'),
                        ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminTheme.rose,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : _reloading
                            ? 'Loading...'
                            : 'Save $_itemName',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

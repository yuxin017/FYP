import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../accounts/account_widgets.dart';
import '../../photos/photo_repository.dart';
import '../../photos/photo_widgets.dart';

class FaceRecognitionSettingsPage extends StatefulWidget {
  final PhotoRepository? repository;
  const FaceRecognitionSettingsPage({super.key, this.repository});
  @override
  State<FaceRecognitionSettingsPage> createState() =>
      _FaceRecognitionSettingsPageState();
}

class _FaceRecognitionSettingsPageState
    extends State<FaceRecognitionSettingsPage> {
  late final repo = widget.repository ?? FirebasePhotoRepository(),
      profile = repo.faceProfile();
  bool consent = false, busy = false;
  Uint8List? selfie;
  String? error;
  Future<void> pick(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 8000000) {
        throw StateError('Choose a selfie smaller than 8 MB.');
      }
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('Choose a clear JPEG or PNG selfie.');
      }
      final image = img.bakeOrientation(decoded),
          resized = img.copyResize(
            image,
            width: image.width > 900 ? 900 : image.width,
          );
      if (mounted) {
        setState(() {
          selfie = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Unable to open the photo. Please try again.',
        );
      }
    }
  }

  Future<bool> password() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const _FacePasswordDialog(),
    );
    if (value == null) return false;
    await repo.reauthenticate(value);
    return true;
  }

  Future<void> setup() async {
    if (selfie == null || !consent) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      try {
        await repo.request('enroll', {
          'consent': true,
          'imageBase64': base64Encode(selfie!),
        });
      } catch (e) {
        if (e.toString().contains('Confirm your password')) {
          if (!mounted || !await password()) return;
          await repo.request('enroll', {
            'consent': true,
            'imageBase64': base64Encode(selfie!),
          });
        } else {
          rethrow;
        }
      }
      if (mounted) {
        setState(() => selfie = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Face matching is active. Your park photos will appear as they are found.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove face profile?'),
        content: const Text(
          'Automatic photo matching will stop and your face profile will be removed. Purchased photos and photos added with a photo code remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Profile'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Face Profile'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.request('disable', {});
      if (mounted) setState(() => consent = false);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Face Recognition',
    busy: busy,
    child: StreamBuilder<Map<String, dynamic>>(
      stream: profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load your face profile. Please reopen this page.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final enabled = snapshot.data!['enabled'] == true;
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 25),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Color(0xFFEEDDD8),
                child: Icon(
                  Icons.face_retouching_natural,
                  size: 53,
                  color: photoRose,
                ),
              ),
            ),
            const SizedBox(height: 13),
            Center(
              child: Chip(
                label: Text(
                  enabled ? 'Active' : 'Not Set Up',
                  style: const TextStyle(
                    color: photoRose,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.white,
                side: const BorderSide(color: photoRose),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Find your park photos automatically',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: photoInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an optional selfie so the app can match photos taken during your visit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF606973),
                height: 1.6,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            PhotoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How it works',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 13),
                  for (final step in [
                    (1, 'Take or upload a clear selfie'),
                    (2, 'We create a private face profile'),
                    (3, 'Matched park photos appear in your gallery'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: photoRose,
                            child: Text(
                              '${step.$1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              step.$2,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            PhotoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selfie tips',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  for (final tip in [
                    (Icons.light_mode_outlined, 'Use good lighting'),
                    (Icons.face_outlined, 'Face the camera'),
                    (Icons.visibility_outlined, 'Remove hats and sunglasses'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(tip.$1, color: photoRose, size: 20),
                          const SizedBox(width: 14),
                          Text(tip.$2, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (selfie != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(selfie!, height: 210, fit: BoxFit.contain),
              ),
              const SizedBox(height: 15),
            ],
            Row(
              children: [
                Expanded(
                  child: PhotoButton(
                    'Take Selfie',
                    onPressed: busy ? null : () => pick(ImageSource.camera),
                    outlined: true,
                    icon: Icons.camera_alt_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PhotoButton(
                    'Upload Selfie',
                    onPressed: busy ? null : () => pick(ImageSource.gallery),
                    outlined: true,
                    icon: Icons.photo_library_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consent,
              onChanged: busy
                  ? null
                  : (v) => setState(() => consent = v ?? false),
              title: const Text(
                'I agree to use my selfie for park photo matching.',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(error!, style: const TextStyle(color: photoRose)),
              ),
            PhotoButton(
              enabled ? 'Update Face Profile' : 'Set Up Face Recognition',
              onPressed: selfie != null && consent ? setup : null,
              busy: busy,
            ),
            if (enabled) ...[
              const SizedBox(height: 12),
              PhotoButton(
                'Remove Face Profile',
                onPressed: busy ? null : remove,
                outlined: true,
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : () => Navigator.maybePop(context),
              child: Text(enabled ? 'Back' : 'Maybe Later'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Optional. Your selfie is used to create your photo-matching profile. You can remove the profile at any time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7C8289),
                height: 1.5,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _FacePasswordDialog extends StatefulWidget {
  const _FacePasswordDialog();
  @override
  State<_FacePasswordDialog> createState() => _FacePasswordDialogState();
}

class _FacePasswordDialogState extends State<_FacePasswordDialog> {
  final password = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm your identity'),
    content: TextField(
      controller: password,
      obscureText: true,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Current password'),
      onSubmitted: (v) {
        if (v.isNotEmpty) Navigator.pop(context, v);
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, password.text),
        child: const Text('Continue'),
      ),
    ],
  );
}

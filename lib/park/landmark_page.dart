import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../photos/photo_widgets.dart';
import '../photos/photo_repository.dart';
import 'intelligence_repository.dart';

class LandmarkLocationPage extends StatefulWidget {
  final ParkIntelligenceRepository repository;
  const LandmarkLocationPage({super.key, required this.repository});
  @override
  State<LandmarkLocationPage> createState() => _LandmarkLocationPageState();
}

class _LandmarkLocationPageState extends State<LandmarkLocationPage> {
  Uint8List? image;
  Map<String, dynamic>? result;
  String? error;
  bool busy = false;
  Future<void> capture(ImageSource source) async {
    if (busy) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2000000) {
        throw StateError('Choose a smaller landmark image.');
      }
      setState(() {
        busy = true;
        image = bytes;
        result = null;
        error = null;
      });
      final response = await widget.repository.request('recognizeLandmark', {
        'imageBase64': base64Encode(bytes),
      });
      if (mounted) {
        setState(() {
          result = response;
          if (response['matched'] != true) {
            error = response['reason'] == 'no-references'
                ? 'No landmark references are available yet. Choose your location on the map or ask park staff.'
                : 'This landmark could not be matched confidently. Try a clearer view of a sign or building, or choose your location on the map.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Find My Location',
    helpTitle: 'Find a park landmark',
    helpText:
        'Take a clear photograph of a nearby park landmark or choose one from your gallery. Review the detected landmark before using it as your starting point. If it cannot be recognised, choose your starting point on the park map.',
    selectedIndex: 2,
    busy: busy,
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const PhotoPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_searching, color: photoRose, size: 29),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find your place in the park',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: photoRose,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use a nearby landmark to set your starting point.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: .88,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  Image.memory(image!, fit: BoxFit.cover)
                else
                  Container(
                    color: const Color(0xFFE6DDD6),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 85,
                          color: photoRose,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Capture a park sign or building',
                          style: TextStyle(color: photoInk, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                ),
                if (busy)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                if (result?['matched'] == true)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 25,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: photoRose.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '${result!['name']} detected',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        PhotoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Point your camera at a nearby landmark',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 13),
              const Text(
                'We will match the landmark to the park map to estimate your starting location.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6, color: Color(0xFF7C8289)),
              ),
              const SizedBox(height: 24),
              if (result?['matched'] == true) ...[
                PhotoButton(
                  'Use This Landmark',
                  onPressed: () =>
                      Navigator.pop(context, result!['placeId'] as String),
                ),
                const SizedBox(height: 12),
              ],
              PhotoButton(
                image == null ? 'Open Camera' : 'Take Another Photo',
                onPressed: busy ? null : () => capture(ImageSource.camera),
                icon: Icons.camera_alt_outlined,
              ),
              const SizedBox(height: 12),
              PhotoButton(
                'Choose a Photo',
                outlined: true,
                onPressed: busy ? null : () => capture(ImageSource.gallery),
                icon: Icons.photo_outlined,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Choose Location on Map'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: photoRose, height: 1.5),
                  ),
                ),
              const SizedBox(height: 20),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 20, color: Color(0xFF7C8289)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Camera images are processed only for location detection and are not stored in your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C8289),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

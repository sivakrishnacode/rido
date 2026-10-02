import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A photo from the camera: its bytes and file name.
typedef TakenPhoto = ({Uint8List bytes, String name});

/// Opens the phone's camera ([front]: the selfie camera) and returns the photo, resized and compressed like the
/// document photos (D-08). Null when the driver backs out; throws when the camera can't open (no permission).
typedef PhotoCamera = Future<TakenPhoto?> Function({bool front});

Future<TakenPhoto?> _takePhoto({bool front = false}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  if (file == null) return null;
  return (bytes: await file.readAsBytes(), name: file.name.isEmpty ? 'photo.jpg' : file.name);
}

/// The camera (tests replace it).
final photoCameraProvider = Provider<PhotoCamera>((ref) => _takePhoto);

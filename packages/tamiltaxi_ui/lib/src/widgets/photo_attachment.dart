import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/tt_tokens.dart';
import '../theme/tt_colors.dart';
import 'tt_card.dart';
import 'tt_dialogs.dart';

class PhotoAttachment {
  const PhotoAttachment(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

typedef AttachmentPicker = Future<PhotoAttachment?> Function(bool camera);
final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => (camera) async {
    final file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw Exception('Choose an image smaller than 8 MB');
    }
    return PhotoAttachment(bytes, file.name.isEmpty ? 'photo.jpg' : file.name);
  },
);

class PhotoAttachmentTile extends ConsumerStatefulWidget {
  const PhotoAttachmentTile({
    super.key,
    required this.photo,
    required this.onChanged,
    this.label = 'Add a photo or screenshot',
    this.camera = false,
  });
  final PhotoAttachment? photo;
  final ValueChanged<PhotoAttachment?> onChanged;
  final String label;
  final bool camera;
  @override
  ConsumerState<PhotoAttachmentTile> createState() =>
      _PhotoAttachmentTileState();
}

class _PhotoAttachmentTileState extends ConsumerState<PhotoAttachmentTile> {
  bool _picking = false;
  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final photo = await ref.read(attachmentPickerProvider)(widget.camera);
      if (mounted && photo != null) widget.onChanged(photo);
    } catch (_) {
      if (mounted) {
        showTtSnack(
          context,
          'Could not open the image. Check photo permission and try again (up to 8 MB).',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => TtCard(
    color: TtColors.background,
    onTap: widget.photo == null && !_picking ? _pick : null,
    child: Row(
      children: [
        if (widget.photo case final photo?)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              photo.bytes,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          )
        else if (_picking)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(),
          )
        else
          const Icon(Icons.add_a_photo_outlined, color: TtColors.coral600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.photo == null ? '${widget.label} (optional)' : 'Photo added',
            style: context.type.bodyMedium,
          ),
        ),
        if (widget.photo != null)
          IconButton(
            tooltip: 'Remove photo',
            icon: const Icon(Icons.close),
            onPressed: () => widget.onChanged(null),
          ),
      ],
    ),
  );
}

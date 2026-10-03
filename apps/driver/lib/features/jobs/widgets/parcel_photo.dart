import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// Protected parcel image: only the assigned driver can read it.
class ParcelPhoto extends ConsumerWidget {
  const ParcelPhoto({super.key, required this.tripId});
  final String tripId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientProvider);
    final url = '${api.baseUrl}/trips/$tripId/parcel-photo';
    final headers = {'Authorization': 'Bearer ${api.session.token}'};
    Widget image({double? width, double? height}) => Image.network(
      url,
      headers: headers,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Text('Photo unavailable'),
      loadingBuilder: (_, child, loading) => loading == null
          ? child
          : const Center(child: CircularProgressIndicator()),
    );
    return TtCard(
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: InteractiveViewer(child: image())),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
      child: Row(
        children: [
          image(width: 72, height: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Photo of parcel · tap to view',
              style: context.type.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

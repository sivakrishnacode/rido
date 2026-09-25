import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import '../features/states/s04_no_internet_screen.dart';

/// Standard handling for repository data: [loading] while waiting (use a skeleton),
/// S-04 "You're offline" on [OfflineException] with Retry, and [data] otherwise.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.loading,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget loading;

  /// Usually `() => ref.invalidate(provider)`.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = value.error;
    if (value.hasError && error is OfflineException) return S04NoInternetView(onRetry: onRetry);
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) return Center(child: Text('Something went wrong: $error'));
    return loading;
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_driver/overlay/background_offers.dart';
import 'package:rido_driver/state/driver_session.dart';

/// The overlay plugin's native side as Android behaves: the window service starts *asynchronously*
/// ([startDelay] after showOverlay returns), `closeOverlay` stops it (also while starting).
class FakeOverlayPlatform {
  FakeOverlayPlatform({this.startDelay = const Duration(milliseconds: 300), this.active = false});

  final Duration startDelay;
  bool active;
  bool _starting = false;
  int shows = 0;
  int closes = 0;

  /// When true, closeOverlay doesn't answer until [releaseHungCloses] (the unpatched plugin never answered
  /// when nothing was running).
  bool hangOnClose = false;
  final List<Completer<bool>> _hung = [];

  void releaseHungCloses() {
    for (final c in _hung) {
      if (!c.isCompleted) c.complete(true);
    }
  }

  static const _main = MethodChannel('x-slayer/overlay_channel');
  static const _messenger = BasicMessageChannel<Object?>('x-slayer/overlay_messenger', JSONMessageCodec());

  void install(WidgetTester tester) {
    final m = tester.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_main, (call) async {
      switch (call.method) {
        case 'checkPermission':
          return true;
        case 'isOverlayActive':
          return active;
        case 'showOverlay':
          shows++;
          _starting = true;
          Future<void>.delayed(startDelay, () {
            if (_starting) active = true;
            _starting = false;
          });
          return null;
        case 'closeOverlay':
          closes++;
          _starting = false;
          active = false;
          if (hangOnClose) {
            final c = Completer<bool>();
            _hung.add(c);
            return c.future;
          }
          return true;
      }
      return null;
    });
    m.setMockMessageHandler(_messenger.name, (_) async => null);
  }
}

class _Host extends ConsumerStatefulWidget {
  const _Host();
  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  late final BackgroundOffers offers = BackgroundOffers(ref, onAccepted: (_) {})..start();

  @override
  void initState() {
    super.initState();
    offers; // create + start
  }

  @override
  void dispose() {
    offers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Ends a test cleanly: offline (stops the mock session's request timers), unmount, let pending timers run out.
Future<void> _finish(WidgetTester tester, ProviderContainer container, [FakeOverlayPlatform? platform]) async {
  container.read(driverSessionProvider.notifier).goOffline();
  platform?.releaseHungCloses();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

late ProviderContainer _container;

Future<BackgroundOffers> _pumpOnline(WidgetTester tester) async {
  final container = _container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _Host()));
  await container.read(driverSessionProvider.notifier).goOnline();
  await tester.pump();
  return tester.state<_HostState>(find.byType(_Host)).offers;
}

Future<void> _settle(WidgetTester tester, [Duration d = const Duration(seconds: 4)]) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('going to the background shows the bubble after a short delay', (tester) async {
    final platform = FakeOverlayPlatform()..install(tester);
    final offers = await _pumpOnline(tester);
    offers.onLifecycle(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 300));
    expect(platform.shows, 0, reason: 'no bubble yet: could be a quick app switch');
    await _settle(tester, const Duration(seconds: 1));
    expect(platform.shows, 1);
    expect(platform.active, isTrue);
    await _finish(tester, _container, platform);
  });

  testWidgets('a quick app switch never flashes the bubble', (tester) async {
    final platform = FakeOverlayPlatform()..install(tester);
    final offers = await _pumpOnline(tester);
    offers
      ..onLifecycle(AppLifecycleState.paused)
      ..onLifecycle(AppLifecycleState.resumed);
    await _settle(tester);
    expect(platform.shows, 0);
    expect(platform.active, isFalse);
    await _finish(tester, _container, platform);
  });

  testWidgets('coming back while the bubble is still starting closes it (never shown inside the app)', (tester) async {
    final platform = FakeOverlayPlatform(startDelay: const Duration(milliseconds: 1500))..install(tester);
    final offers = await _pumpOnline(tester);
    offers.onLifecycle(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 700)); // show requested, service still starting
    expect(platform.shows, 1);
    offers.onLifecycle(AppLifecycleState.resumed);
    await _settle(tester, const Duration(seconds: 5));
    expect(platform.active, isFalse);
    await _finish(tester, _container, platform);
  });

  testWidgets('a bubble left over from before is closed when the app starts in front', (tester) async {
    final platform = FakeOverlayPlatform(active: true)..install(tester);
    await _pumpOnline(tester);
    await _settle(tester, const Duration(seconds: 1));
    expect(platform.active, isFalse);
    expect(platform.closes, greaterThan(0));
    await _finish(tester, _container, platform);
  });

  testWidgets('a close that never answers does not freeze later changes', (tester) async {
    final platform = FakeOverlayPlatform()..install(tester);
    final offers = await _pumpOnline(tester);
    offers.onLifecycle(AppLifecycleState.paused);
    await _settle(tester, const Duration(seconds: 1));
    platform.hangOnClose = true;
    offers.onLifecycle(AppLifecycleState.resumed);
    await _settle(tester, const Duration(seconds: 12));
    platform.hangOnClose = false;
    offers.onLifecycle(AppLifecycleState.paused);
    await _settle(tester, const Duration(seconds: 5));
    expect(platform.shows, 2, reason: 'the queue kept working after the stuck close');
    await _finish(tester, _container, platform);
  });

  testWidgets('the screen being destroyed in the background (detached) keeps the bubble', (tester) async {
    final platform = FakeOverlayPlatform()..install(tester);
    final offers = await _pumpOnline(tester);
    offers.onLifecycle(AppLifecycleState.paused);
    await _settle(tester, const Duration(seconds: 1));
    expect(platform.active, isTrue);
    // Android destroyed the Activity; the engine (and the online session) keeps running.
    offers.onLifecycle(AppLifecycleState.detached);
    await _settle(tester, const Duration(seconds: 3));
    expect(platform.active, isTrue, reason: 'detached is background, not "back in the app"');
    offers.onLifecycle(AppLifecycleState.resumed);
    await _settle(tester, const Duration(seconds: 3));
    expect(platform.active, isFalse);
    await _finish(tester, _container, platform);
  });

  testWidgets('offline: no bubble in the background', (tester) async {
    final platform = FakeOverlayPlatform()..install(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _Host()));
    tester.state<_HostState>(find.byType(_Host)).offers.onLifecycle(AppLifecycleState.paused);
    await _settle(tester);
    expect(platform.shows, 0);
    await _finish(tester, container, platform);
  });
}

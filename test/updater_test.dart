import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leave_tracker/main.dart';
import 'package:leave_tracker/store.dart';
import 'package:leave_tracker/updater.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSource implements UpdateSource {
  FakeSource({this.current = '1.0.3', this.release, this.failCheck = false, this.failDownload = false});

  String? current;
  AppUpdate? release;
  bool failCheck;
  bool failDownload;
  final installed = <String>[];
  Completer<void>? holdDownload;

  @override
  Future<String?> currentVersion() async => current;

  @override
  Future<AppUpdate?> latest() async {
    if (failCheck) throw Exception('offline');
    return release;
  }

  @override
  Future<void> downloadAndInstall(AppUpdate update, void Function(double? progress) onProgress) async {
    onProgress(0.5);
    await holdDownload?.future;
    if (failDownload) throw Exception('offline');
    onProgress(1);
    installed.add(update.version);
  }
}

AppUpdate release(String version) => AppUpdate(
      version: version,
      apkUrl: Uri.parse('https://github.com/$updateRepo/releases/download/v$version/annual-leave.apk'),
    );

Map<String, Object?> githubRelease({
  String tag = 'v1.0.12',
  String asset = 'annual-leave.apk',
  String? url,
  bool draft = false,
  bool prerelease = false,
}) =>
    {
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://github.com/$updateRepo/releases/download/$tag/notes.txt'},
        {
          'name': asset,
          'browser_download_url': url ?? 'https://github.com/$updateRepo/releases/download/$tag/$asset',
        },
      ],
    };

void main() {
  group('compareVersions', () {
    test('compares number by number, not as text', () {
      expect(compareVersions('1.0.10', '1.0.9'), greaterThan(0));
      expect(compareVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.3', '1.0.3'), 0);
    });

    test('ignores a leading v, a build suffix and missing parts', () {
      expect(compareVersions('v1.0.4', '1.0.3'), greaterThan(0));
      expect(compareVersions('1.0.3+7', '1.0.3'), 0);
      expect(compareVersions('1.1', '1.1.0'), 0);
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    });
  });

  group('parseRelease', () {
    test('reads the version and the APK link', () {
      final update = parseRelease(githubRelease())!;
      expect(update.version, '1.0.12');
      expect(update.apkUrl.toString(), 'https://github.com/$updateRepo/releases/download/v1.0.12/annual-leave.apk');
    });

    test('ignores drafts, pre-releases and odd tags', () {
      expect(parseRelease(githubRelease(draft: true)), isNull);
      expect(parseRelease(githubRelease(prerelease: true)), isNull);
      expect(parseRelease(githubRelease(tag: 'nightly')), isNull);
    });

    test('ignores releases without an APK from this repository', () {
      expect(parseRelease(githubRelease(asset: 'source.zip')), isNull);
      expect(parseRelease(githubRelease(url: 'https://example.com/annual-leave.apk')), isNull);
      expect(parseRelease(githubRelease(url: 'https://github.com/someone/else/releases/download/v9/a.apk')), isNull);
      expect(parseRelease(githubRelease(url: 'http://github.com/$updateRepo/releases/download/v1/a.apk')), isNull);
      expect(parseRelease({'message': 'Not Found'}), isNull);
      expect(parseRelease('nonsense'), isNull);
    });
  });

  group('UpdateController', () {
    test('offers a newer release only', () async {
      final source = FakeSource(release: release('1.0.4'));
      final updates = UpdateController(source);
      await updates.check();
      expect(updates.currentVersion, '1.0.3');
      expect(updates.available?.version, '1.0.4');

      source.release = release('1.0.3');
      await updates.check(manual: true);
      expect(updates.available, isNull);
      expect(updates.message, 'You have the latest version.');

      source.release = release('1.0.2');
      await updates.check();
      expect(updates.available, isNull);
    });

    test('a background check fails silently, a manual one explains', () async {
      final updates = UpdateController(FakeSource(failCheck: true));
      await updates.check();
      expect(updates.message, isNull);
      expect(updates.checking, isFalse);

      await updates.check(manual: true);
      expect(updates.message, contains('Could not check'));
    });

    test('no releases yet means nothing to offer', () async {
      final updates = UpdateController(FakeSource());
      await updates.check(manual: true);
      expect(updates.available, isNull);
      expect(updates.message, 'You have the latest version.');
    });

    test('install downloads and opens the installer', () async {
      final source = FakeSource(release: release('1.0.4'));
      final updates = UpdateController(source);
      await updates.check();
      await updates.install();
      expect(source.installed, ['1.0.4']);
      expect(updates.installerOpened, isTrue);
      expect(updates.downloading, isFalse);
      expect(updates.progress, 1);
    });

    test('a failed download can be retried', () async {
      final source = FakeSource(release: release('1.0.4'), failDownload: true);
      final updates = UpdateController(source);
      await updates.check();
      await updates.install();
      expect(updates.installerOpened, isFalse);
      expect(updates.message, contains('could not be downloaded'));

      source.failDownload = false;
      await updates.install();
      expect(source.installed, ['1.0.4']);
      expect(updates.message, isNull);
    });
  });

  testWidgets('home screen offers the update and shows its progress', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      LeaveStore.storageKey:
          '{"version":1,"contracts":[{"id":"c","start":"2026-03-01","years":1,"daysPerYear":25,"carryMax":10,"broughtForward":0}],"leaves":[]}',
    });
    final store = LeaveStore(clock: () => DateTime.utc(2026, 11, 26));
    await store.load();
    final source = FakeSource(release: release('1.0.4'))..holdDownload = Completer<void>();
    final updates = UpdateController(source);

    await tester.pumpWidget(LeaveApp(store: store, updates: updates));
    expect(find.textContaining('is available'), findsNothing);

    await updates.check();
    await tester.pump();
    expect(find.text('Version 1.0.4 is available'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pump();
    expect(find.text('Downloading… 50%'), findsOneWidget);
    expect(find.text('Update'), findsNothing);

    source.holdDownload!.complete();
    await tester.pumpAndSettle();
    expect(source.installed, ['1.0.4']);
    expect(find.textContaining('Tap Install'), findsOneWidget);
    expect(find.text('Open again'), findsOneWidget);

    // The settings screen shows the installed version.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Version 1.0.3.'), 200);
    expect(find.textContaining('Version 1.0.3.'), findsOneWidget);
  });
}

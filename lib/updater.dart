/// In-app updates.
///
/// Every push to `main` makes GitHub Actions publish a release with a signed
/// APK. The app asks GitHub for the latest release, and if it is newer than
/// the installed version it downloads the APK and opens the Android
/// installer. Android only accepts the update when it is signed with the same
/// key as the installed app, and it keeps the app's data.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The GitHub repository whose releases carry the updates.
const updateRepo = 'pesu98/HR-Application';

/// A released version of the app.
class AppUpdate {
  const AppUpdate({required this.version, required this.apkUrl});

  /// Version without the leading `v`, e.g. `1.0.12`.
  final String version;
  final Uri apkUrl;
}

/// Compares dotted versions number by number. A leading `v` and any `+build`
/// suffix are ignored. Returns a negative number, zero or a positive number
/// when [a] is older than, the same as, or newer than [b].
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .trim()
      .replaceFirst(RegExp('^v'), '')
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final diff = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (diff != 0) return diff;
  }
  return 0;
}

/// Reads GitHub's "latest release" answer. Returns null unless it is a
/// published release with a version tag and an APK hosted in [updateRepo].
AppUpdate? parseRelease(Object? json) {
  if (json is! Map) return null;
  final tag = json['tag_name'];
  final assets = json['assets'];
  if (tag is! String || assets is! List) return null;
  if (json['draft'] == true || json['prerelease'] == true) return null;
  if (!RegExp(r'^v?\d+(\.\d+)*$').hasMatch(tag)) return null;

  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = asset['name'];
    final link = asset['browser_download_url'];
    if (name is! String || link is! String || !name.endsWith('.apk')) continue;
    final url = Uri.tryParse(link);
    if (url != null &&
        url.scheme == 'https' &&
        url.host == 'github.com' &&
        url.path.startsWith('/$updateRepo/releases/download/')) {
      return AppUpdate(version: tag.replaceFirst(RegExp('^v'), ''), apkUrl: url);
    }
  }
  return null;
}

/// Where updates come from. Replaced by a fake in tests.
abstract class UpdateSource {
  /// The installed version, e.g. `1.0.12`.
  Future<String?> currentVersion();

  /// The newest published release, or null when there is none.
  Future<AppUpdate?> latest();

  /// Downloads [update] and opens the Android installer.
  /// [onProgress] gets 0..1, or null when the size is unknown.
  Future<void> downloadAndInstall(AppUpdate update, void Function(double? progress) onProgress);
}

/// Updates from this app's GitHub releases. Android only.
class GithubUpdateSource implements UpdateSource {
  static const _channel = MethodChannel('leave_tracker/updater');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Map<String, Object?>> _info() async =>
      await _channel.invokeMapMethod<String, Object?>('info') ?? const {};

  @override
  Future<String?> currentVersion() async => (await _info())['version'] as String?;

  @override
  Future<AppUpdate?> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.https('api.github.com', '/repos/$updateRepo/releases/latest'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return null; // nothing released yet
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub answered ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
      return parseRelease(jsonDecode(body));
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> downloadAndInstall(AppUpdate update, void Function(double? progress) onProgress) async {
    final path = (await _info())['updateDir'] as String?;
    if (path == null) throw const FileSystemException('No folder for updates');
    final dir = Directory(path);
    await dir.create(recursive: true);
    await for (final old in dir.list()) {
      if (old is File) await old.delete();
    }

    final fileName = 'annual-leave-${update.version}.apk';
    final partial = File('${dir.path}/$fileName.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(update.apkUrl);
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed (${response.statusCode})');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.timeout(const Duration(seconds: 30))) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(total > 0 ? received / total : null);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
    await partial.rename('${dir.path}/$fileName');
    await _channel.invokeMethod<void>('install', {'fileName': fileName});
  }
}

/// Update state shown by the UI.
class UpdateController extends ChangeNotifier {
  UpdateController(this._source);

  final UpdateSource _source;

  /// Installed version, once known.
  String? currentVersion;

  /// A newer release, if there is one.
  AppUpdate? available;

  bool checking = false;
  bool downloading = false;

  /// True once the Android installer has been opened for [available].
  bool installerOpened = false;

  /// Download progress 0..1, or null when unknown.
  double? progress;

  /// Outcome of the last check the user asked for, or of a failed download.
  String? message;

  /// Looks for a newer release. A background check ([manual] false) stays
  /// silent when it fails or finds nothing.
  Future<void> check({bool manual = false}) async {
    if (checking || downloading) return;
    checking = true;
    if (manual) message = null;
    notifyListeners();
    try {
      final current = currentVersion = await _source.currentVersion();
      final latest = await _source.latest();
      final newer = latest != null && current != null && compareVersions(latest.version, current) > 0;
      if (available?.version != (newer ? latest.version : null)) installerOpened = false;
      available = newer ? latest : null;
      if (manual && !newer) message = 'You have the latest version.';
    } on Exception {
      if (manual) message = 'Could not check for updates. Check your internet connection.';
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// Downloads the available update and opens the Android installer.
  Future<void> install() async {
    final update = available;
    if (update == null || downloading) return;
    downloading = true;
    progress = 0;
    message = null;
    notifyListeners();
    var shown = 0;
    try {
      await _source.downloadAndInstall(update, (value) {
        final percent = value == null ? -1 : (value * 100).floor();
        if (percent == shown) return;
        shown = percent;
        progress = value;
        notifyListeners();
      });
      installerOpened = true;
    } on Exception {
      message = 'The update could not be downloaded. Check your internet connection and try again.';
    } finally {
      downloading = false;
      notifyListeners();
    }
  }
}

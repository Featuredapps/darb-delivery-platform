import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'design_system.dart';
import 'localizations.dart';

class DarbUpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final String releaseNotes;

  const DarbUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.releaseNotes,
  });

  factory DarbUpdateInfo.fromJson(Map<String, dynamic> json) => DarbUpdateInfo(
    versionCode: (json['versionCode'] as num).toInt(),
    versionName: json['versionName']?.toString() ?? '',
    apkUrl: json['apkUrl']?.toString() ?? '',
    sha256: json['sha256']?.toString().toLowerCase() ?? '',
    releaseNotes: json['releaseNotes']?.toString() ?? '',
  );
}

class DarbUpdater {
  DarbUpdater._();
  static final instance = DarbUpdater._();
  static const _channel = MethodChannel('com.darb/update');
  static const _releaseApi = 'https://api.github.com/repos/anasgdxj/darb-delivery-platform/releases/tags/latest';
  static const _fallbackManifest = 'https://github.com/anasgdxj/darb-delivery-platform/releases/download/latest/app-update.json';

  final availableUpdate = ValueNotifier<DarbUpdateInfo?>(null);
  final downloadProgress = ValueNotifier<double?>(null);
  String? downloadedApkPath;
  bool _checking = false;
  bool checkFailed = false;

  Future<void> checkForUpdate({bool force = false}) async {
    if (_checking) return;
    _checking = true;
    checkFailed = false;
    try {
      Map<String, dynamic>? decoded;
      try {
        final response = await http.get(
          Uri.parse(_releaseApi),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'Cache-Control': 'no-cache',
          },
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final release = jsonDecode(utf8.decode(response.bodyBytes));
          if (release is Map<String, dynamic> && release['assets'] is List) {
            final assets = (release['assets'] as List).whereType<Map<String, dynamic>>();
            Map<String, dynamic>? manifest;
            for (final asset in assets) {
              if (asset['name'] == 'app-update.json') {
                manifest = asset;
                break;
              }
            }
            final url = manifest?['browser_download_url']?.toString();
            if (url != null && url.startsWith('https://')) {
              final manifestResponse = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
              if (manifestResponse.statusCode == 200) {
                final value = jsonDecode(utf8.decode(manifestResponse.bodyBytes));
                if (value is Map<String, dynamic>) decoded = value;
              }
            }
          }
        }
      } catch (_) {
        // Try the stable direct manifest URL below.
      }
      if (decoded == null) {
        final fallback = await http.get(
          Uri.parse(_fallbackManifest),
          headers: const {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 12));
        if (fallback.statusCode != 200) throw Exception('Update manifest unavailable');
        final value = jsonDecode(utf8.decode(fallback.bodyBytes));
        if (value is! Map<String, dynamic>) throw const FormatException('Invalid update manifest');
        decoded = value;
      }
      final info = DarbUpdateInfo.fromJson(decoded);
      if (info.versionCode <= 0 ||
          !info.apkUrl.startsWith('https://') ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(info.sha256)) {
        throw const FormatException('Invalid update metadata');
      }
      final package = await PackageInfo.fromPlatform();
      final installedBuild = int.tryParse(package.buildNumber) ?? 0;
      availableUpdate.value = info.versionCode > installedBuild ? info : null;
      checkFailed = false;
    } catch (_) {
      if (force) checkFailed = true;
    } finally {
      _checking = false;
    }
  }

  Future<String> downloadUpdate(DarbUpdateInfo info) async {
    downloadProgress.value = 0;
    final client = http.Client();
    try {
      final supportDir = await getApplicationSupportDirectory();
      final updateDir = Directory('${supportDir.path}/updates');
      if (!await updateDir.exists()) await updateDir.create(recursive: true);
      final file = File('${updateDir.path}/darb-update-${info.versionCode}.apk');
      final partial = File('${file.path}.part');
      var completed = false;

      for (var attempt = 0; attempt < 4 && !completed; attempt++) {
        try {
          final existing = await partial.exists() ? await partial.length() : 0;
          final request = http.Request('GET', Uri.parse(info.apkUrl));
          if (existing > 0) request.headers['Range'] = 'bytes=$existing-';
          final response = await client.send(request).timeout(const Duration(seconds: 30));

          if (existing > 0 && response.statusCode == 200) {
            await partial.writeAsBytes(const [], flush: true);
          } else if (existing > 0 && response.statusCode != 206) {
            throw HttpException('Server cannot resume download (HTTP ${response.statusCode})');
          } else if (existing == 0 && response.statusCode != 200) {
            throw HttpException('Download failed (HTTP ${response.statusCode})');
          }

          final append = existing > 0 && response.statusCode == 206;
          final startAt = append ? existing : 0;
          final contentRange = response.headers['content-range'];
          int? total;
          if (response.statusCode == 206 && contentRange != null) {
            final match = RegExp(r'^bytes \d+-\d+/(\d+)$').firstMatch(contentRange);
            if (match != null) total = int.tryParse(match.group(1)!);
            if (total == null) throw const FormatException('Invalid Content-Range');
          } else if (response.statusCode == 200) {
            total = response.contentLength;
          }

          var received = startAt;
          final sink = partial.openWrite(mode: append ? FileMode.append : FileMode.write);
          try {
            await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
              sink.add(chunk);
              received += chunk.length;
              if (total != null && total > 0) {
                downloadProgress.value = (received / total).clamp(0.0, 1.0);
              }
            }
            await sink.flush();
          } finally {
            await sink.close();
          }

          if (total != null && received < total) {
            if (attempt == 3) throw const SocketException('Download interrupted repeatedly');
            continue;
          }
          if (total != null && received > total) {
            await partial.delete();
            throw const FormatException('Downloaded file size is invalid');
          }
          final actualHash = (await sha256.bind(partial.openRead()).first).toString();
          if (actualHash != info.sha256) {
            await partial.delete();
            throw const FormatException('APK checksum mismatch');
          }
          if (await file.exists()) await file.delete();
          await partial.rename(file.path);
          completed = true;
        } catch (_) {
          if (attempt == 3) rethrow;
          await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
      if (!completed) throw const SocketException('Download did not complete');
      downloadedApkPath = file.path;
      downloadProgress.value = 1;
      return file.path;
    } catch (_) {
      downloadProgress.value = null;
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<String> installDownloadedApk() async {
    final path = downloadedApkPath;
    if (path == null || !await File(path).exists()) {
      throw StateError('No downloaded update');
    }
    return await _channel.invokeMethod<String>('installApk', {'path': path}) ?? 'unknown';
  }
}

class DarbUpdateDialog extends StatefulWidget {
  final DarbUpdateInfo info;
  const DarbUpdateDialog({super.key, required this.info});

  @override
  State<DarbUpdateDialog> createState() => _DarbUpdateDialogState();
}

class _DarbUpdateDialogState extends State<DarbUpdateDialog> {
  bool _busy = false;
  String? _error;
  bool get _downloaded => DarbUpdater.instance.downloadedApkPath != null &&
      File(DarbUpdater.instance.downloadedApkPath!).existsSync();

  Future<void> _download() async {
    setState(() { _busy = true; _error = null; });
    try {
      await DarbUpdater.instance.downloadUpdate(widget.info);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = dt('تعذر تنزيل التحديث'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await DarbUpdater.instance.installDownloadedApk();
      if (result == 'permission_required') {
        if (mounted) setState(() => _error = dt('اسمح لدَرْب بتثبيت التحديثات من إعدادات أندرويد ثم ارجع واضغط تثبيت'));
      }
    } catch (_) {
      if (mounted) setState(() => _error = dt('تعذر تنزيل التحديث'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AlertDialog(
      title: Text(dt('يتوفر تحديث جديد'), style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detail(dt('الإصدار الجديد'), info.versionName),
          const SizedBox(height: 8),
          if (info.releaseNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(dt('ما الجديد في هذا التحديث؟'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...info.releaseNotes.split(RegExp(r'\r?\n')).map((line) => line.trim()).where((line) => line.isNotEmpty).map((line) {
              final note = line.replaceFirst(RegExp(r'^[-•]\s*'), '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.check_circle, size: 15, color: DarbColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note, style: TextStyle(color: DarbColors.muted, height: 1.4))),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 14),
          ValueListenableBuilder<double?>(
            valueListenable: DarbUpdater.instance.downloadProgress,
            builder: (context, progress, _) => progress == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 6),
                      Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: DarbColors.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(dt('لاحقاً'))),
        FilledButton(
          onPressed: _busy ? null : (_downloaded ? _install : _download),
          child: Text(_busy ? dt('جارٍ تنزيل التحديث') : (_downloaded ? dt('تثبيت التحديث') : dt('تحديث الآن'))),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Row(
    children: [
      Expanded(child: Text(label, style: TextStyle(color: DarbColors.muted))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}
).firstMatch(contentRange);
          if (match != null) total = int.tryParse(match.group(1)!);
        } else if (response.statusCode == 200) {
          total = response.contentLength;
        }
        var received = startAt;
        final sink = partial.openWrite(mode: append ? FileMode.append : FileMode.write);
        try {
          await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
            sink.add(chunk);
            received += chunk.length;
            if (total != null && total > 0) {
              downloadProgress.value = (received / total).clamp(0.0, 1.0);
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (total != null && received < total) {
          if (attempt == 3) throw const SocketException('Download interrupted repeatedly');
          continue;
        }
        if (total != null && received > total) {
          await partial.delete();
          throw const FormatException('Downloaded file size is invalid');
        }
        final actualHash = (await sha256.bind(partial.openRead()).first).toString();
        if (actualHash != info.sha256) {
          await partial.delete();
          throw const FormatException('APK checksum mismatch');
        }
        if (await file.exists()) await file.delete();
        await partial.rename(file.path);
        completed = true;
      }

      if (!completed) throw const SocketException('Download did not complete');
      downloadedApkPath = file.path;
      downloadProgress.value = 1;
      return file.path;
    } catch (_) {
      downloadProgress.value = null;
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<String> installDownloadedApk() async {
    final path = downloadedApkPath;
    if (path == null || !await File(path).exists()) {
      throw StateError('No downloaded update');
    }
    return await _channel.invokeMethod<String>('installApk', {'path': path}) ?? 'unknown';
  }
}

class DarbUpdateDialog extends StatefulWidget {
  final DarbUpdateInfo info;
  const DarbUpdateDialog({super.key, required this.info});

  @override
  State<DarbUpdateDialog> createState() => _DarbUpdateDialogState();
}

class _DarbUpdateDialogState extends State<DarbUpdateDialog> {
  bool _busy = false;
  String? _error;
  bool get _downloaded => DarbUpdater.instance.downloadedApkPath != null &&
      File(DarbUpdater.instance.downloadedApkPath!).existsSync();

  Future<void> _download() async {
    setState(() { _busy = true; _error = null; });
    try {
      await DarbUpdater.instance.downloadUpdate(widget.info);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = dt('تعذر تنزيل التحديث'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await DarbUpdater.instance.installDownloadedApk();
      if (result == 'permission_required') {
        if (mounted) setState(() => _error = dt('اسمح لدَرْب بتثبيت التحديثات من إعدادات أندرويد ثم ارجع واضغط تثبيت'));
      }
    } catch (_) {
      if (mounted) setState(() => _error = dt('تعذر تنزيل التحديث'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AlertDialog(
      title: Text(dt('يتوفر تحديث جديد'), style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detail(dt('الإصدار الجديد'), info.versionName),
          const SizedBox(height: 8),
          if (info.releaseNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(dt('ما الجديد في هذا التحديث؟'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...info.releaseNotes.split(RegExp(r'\r?\n')).map((line) => line.trim()).where((line) => line.isNotEmpty).map((line) {
              final note = line.replaceFirst(RegExp(r'^[-•]\s*'), '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.check_circle, size: 15, color: DarbColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note, style: TextStyle(color: DarbColors.muted, height: 1.4))),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 14),
          ValueListenableBuilder<double?>(
            valueListenable: DarbUpdater.instance.downloadProgress,
            builder: (context, progress, _) => progress == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 6),
                      Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: DarbColors.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(dt('لاحقاً'))),
        FilledButton(
          onPressed: _busy ? null : (_downloaded ? _install : _download),
          child: Text(_busy ? dt('جارٍ تنزيل التحديث') : (_downloaded ? dt('تثبيت التحديث') : dt('تحديث الآن'))),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Row(
    children: [
      Expanded(child: Text(label, style: TextStyle(color: DarbColors.muted))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

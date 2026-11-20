import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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
      final response = await http.get(
        Uri.parse(_releaseApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        if (force) checkFailed = true;
        return;
      }
      final release = jsonDecode(response.body);
      if (release is! Map<String, dynamic> || release['assets'] is! List) {
        throw const FormatException('Invalid release response');
      }
      final assets = release['assets'] as List;
      final manifest = assets.cast<Map<String, dynamic>?>().whereType<Map<String, dynamic>>().firstWhere(
        (asset) => asset['name'] == 'app-update.json',
        orElse: () => <String, dynamic>{},
      );
      final manifestUrl = manifest['browser_download_url']?.toString();
      if (manifestUrl == null || manifestUrl.isEmpty) {
        availableUpdate.value = null;
        return;
      }
      final manifestResponse = await http.get(Uri.parse(manifestUrl)).timeout(const Duration(seconds: 15));
      if (manifestResponse.statusCode != 200) throw Exception('Manifest HTTP ${manifestResponse.statusCode}');
      final decoded = jsonDecode(manifestResponse.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid update manifest');
      final info = DarbUpdateInfo.fromJson(decoded);
      if (info.versionCode <= 0 || !info.apkUrl.startsWith('https://') || !RegExp(r'^[a-f0-9]{64}$').hasMatch(info.sha256)) {
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
    final request = http.Request('GET', Uri.parse(info.apkUrl));
    try {
      final response = await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final file = File('${Directory.systemTemp.path}/darb-update-${info.versionCode}.apk');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength ?? 0;
      try {
        await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) downloadProgress.value = received / total;
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final actualHash = (await sha256.bind(file.openRead()).first).toString();
      if (actualHash != info.sha256) {
        await file.delete().catchError((_) => file);
        throw const FormatException('APK checksum mismatch');
      }
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
          if (info.releaseNotes.isNotEmpty) Text(info.releaseNotes, style: TextStyle(color: DarbColors.muted)),
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
          child: Text(_busy ? dt('جارٍ تنزيل التحديث') : (_downloaded ? dt('تثبيت التحديث') : dt('تنزيل التحديث'))),
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

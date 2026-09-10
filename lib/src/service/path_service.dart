import 'dart:async';
import 'dart:io';

import 'package:extended_image/extended_image.dart' show extendedImageDiskCacheDirectory;
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'jh_service.dart';
import 'log.dart';

PathService pathService = PathService();

class PathService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  /// Folder name of the long-term (smart) cache inside the data directory.
  static const String smartCacheFolderName = 'cache';

  /// Cache folders written by earlier versions into the OS temp directory.
  /// Their files are migrated into [smartCacheDir] once so the long-term
  /// cache survives (see below).
  static const List<String> legacySmartCacheFolderNames = ['autotemp', 'cacheimage'];

  /// visible for all
  late Directory tempDir;

  /// Long-term (smart) cache root holding the cached images. Page bodies are
  /// kept in the database; this directory only holds the extended_image disk
  /// cache.
  ///
  /// It deliberately lives in the persistent data directory instead of the OS
  /// temp directory: iOS deletes the contents of `<container>/tmp` while the
  /// app is not running (app update, storage pressure, re-sign), which silently
  /// evicted the whole long-term cache and made already viewed images download
  /// again.
  late Directory smartCacheDir;

  /// visible on ios&windows&macos
  Directory? appDocDir;

  /// visible on windows
  Directory? appSupportDir;

  /// visible on android
  Directory? externalStorageDir;

  Directory? systemDownloadDir;

  @override
  List<JHLifeCircleBean> get initDependencies => [];

  @override
  Future<void> doInitBean() async {
    await Future.wait([
      getTemporaryDirectory().then((value) => tempDir = value),
      getApplicationDocumentsDirectory().then((value) => appDocDir = value).catchError((error) => null),
      getApplicationSupportDirectory().then((value) => appSupportDir = value).catchError((error) => null),
      getExternalStorageDirectory().then((value) => externalStorageDir = value).catchError((error) => null),
      getDownloadsDirectory().then((value) => systemDownloadDir = value).catchError((error) => null),
    ]);

    /// The long-term cache must not be stored in [tempDir]: the OS is free to
    /// delete its contents. The app data directory (see [getVisibleDir]) is
    /// only cleared when the app itself is removed.
    smartCacheDir = Directory(join(getVisibleDir().path, smartCacheFolderName));
    await smartCacheDir.create(recursive: true);

    extendedImageDiskCacheDirectory = smartCacheDir.path;

    /// Handed to the background: a stale copy in temp would be deleted by the
    /// system anyway, and making the user download all of it again is worse
    /// than a second of extra IO after startup.
    unawaited(_migrateLegacySmartCaches());
  }

  @override
  Future<void> doAfterBeanReady() async {}

  /// Moves files cached by earlier versions out of the OS temp directory into
  /// [smartCacheDir]. Failures are logged and ignored; a single missing cache
  /// file only costs one re-download.
  Future<void> _migrateLegacySmartCaches() async {
    for (final String folderName in legacySmartCacheFolderNames) {
      final Directory legacyDir = Directory(join(tempDir.path, folderName));
      if (legacyDir.path == smartCacheDir.path || !legacyDir.existsSync()) {
        continue;
      }

      int moved = 0;
      try {
        for (final FileSystemEntity entity in legacyDir.listSync()) {
          if (entity is! File) {
            continue;
          }

          final String name = basename(entity.path);
          final File target = File(join(smartCacheDir.path, name));
          if (target.existsSync()) {
            continue;
          }

          try {
            /// Same volume: cheap atomic rename.
            await entity.rename(target.path);
            moved++;
          } catch (_) {
            /// Different volume (Android keeps temp on the internal cache
            /// mount while the data directory may live elsewhere).
            try {
              await entity.copy(target.path);
              await entity.delete();
              moved++;
            } catch (e) {
              log.warning('Migrate legacy cache file failed: ${entity.path}', e);
            }
          }
        }
        log.info('Migrated $moved long-term cache files out of $folderName.');
      } catch (e) {
        log.warning('Migrate legacy cache folder failed: ${legacyDir.path}', e);
      }
    }
  }

  Directory getVisibleDir() {
    if (Platform.isAndroid && externalStorageDir != null) {
      return externalStorageDir!;
    }
    if (GetPlatform.isWindows && appSupportDir != null) {
      return appSupportDir!;
    }
    if (GetPlatform.isLinux && appSupportDir != null) {
      return appSupportDir!;
    }
    return appDocDir ?? appSupportDir ?? systemDownloadDir!;
  }
}

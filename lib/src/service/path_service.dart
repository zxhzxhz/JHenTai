import 'dart:io';

import 'package:extended_image/extended_image.dart' show extendedImageDiskCacheDirectory;
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'jh_service.dart';

PathService pathService = PathService();

class PathService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  /// Smart cache (pages + images) lives in this dedicated folder inside temp.
  static const String smartCacheFolderName = 'autotemp';

  /// visible for all
  late Directory tempDir;

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

    /// Route the long-term image cache into a dedicated folder inside temp so
    /// it can be measured and evicted independently of other temp files.
    final Directory smartCacheDir = Directory(join(tempDir.path, smartCacheFolderName));
    await smartCacheDir.create(recursive: true);
    extendedImageDiskCacheDirectory = smartCacheDir.path;
  }

  @override
  Future<void> doAfterBeanReady() async {}

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

import 'dart:io';

import 'package:extended_image/extended_image.dart' show clearDiskCachedImages;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/dao/dio_cache_dao.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/network_setting.dart';

import '../../../routes/routes.dart';
import '../../../utils/byte_util.dart';
import '../../../utils/route_util.dart';
import '../../../utils/text_input_formatter.dart';
import '../../../utils/toast_util.dart';

class SettingNetworkPage extends StatelessWidget {
  final TextEditingController proxyAddressController = TextEditingController(text: networkSetting.proxyAddress.value);

  SettingNetworkPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('networkSetting'.tr)),
      body: Obx(() => ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildEnableDomainFronting(),
              _buildProxyAddress(),
              _buildEnableSmartCache(),
              if (networkSetting.enableSmartCache.isTrue) ...[
                _buildSmartCacheRetention(),
                _buildSmartCacheMaxSize(),
                _buildSmartCacheEvictPolicy(),
              ],
              const _CacheSizeTile(),
              _buildTimeoutTile(
                context: context,
                title: 'connectTimeout'.tr,
                value: networkSetting.connectTimeout,
                onSave: networkSetting.saveConnectTimeout,
              ),
              _buildTimeoutTile(
                context: context,
                title: 'receiveTimeout'.tr,
                value: networkSetting.receiveTimeout,
                onSave: networkSetting.saveReceiveTimeout,
              ),
            ],
          ).withListTileTheme(context)),
    );
  }

  Widget _buildEnableDomainFronting() {
    return SwitchListTile(
      title: Text('enableDomainFronting'.tr),
      subtitle: Text('bypassSNIBlocking'.tr),
      value: networkSetting.enableDomainFronting.value,
      onChanged: networkSetting.saveEnableDomainFronting,
    );
  }

  Widget _buildProxyAddress() {
    return ListTile(
      title: Text('proxyAddress'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () => toRoute(Routes.proxy),
    );
  }

  Widget _buildEnableSmartCache() {
    return SwitchListTile(
      title: Text('enableSmartCache'.tr),
      subtitle: Text('enableSmartCacheHint'.tr),
      value: networkSetting.enableSmartCache.value,
      onChanged: networkSetting.saveEnableSmartCache,
    );
  }

  Widget _buildSmartCacheRetention() {
    return ListTile(
      title: Text('smartCacheRetention'.tr),
      subtitle: Text('smartCacheRetentionHint'.tr),
      trailing: DropdownButton<Duration>(
        value: networkSetting.smartCacheRetention.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (Duration? newValue) => networkSetting.saveSmartCacheRetention(newValue!),
        items: [
          DropdownMenuItem(child: Text('unlimited'.tr), value: Duration.zero),
          DropdownMenuItem(child: Text('1d'.tr), value: const Duration(days: 1)),
          DropdownMenuItem(child: Text('3d'.tr), value: const Duration(days: 3)),
          DropdownMenuItem(child: Text('7d'.tr), value: const Duration(days: 7)),
          DropdownMenuItem(child: Text('30d'.tr), value: const Duration(days: 30)),
        ],
      ),
    );
  }

  Widget _buildSmartCacheMaxSize() {
    return ListTile(
      title: Text('smartCacheMaxSize'.tr),
      subtitle: Text('smartCacheMaxSizeHint'.tr),
      trailing: DropdownButton<int>(
        value: networkSetting.smartCacheMaxSizeMB.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (int? newValue) => networkSetting.saveSmartCacheMaxSizeMB(newValue ?? 0),
        items: [
          DropdownMenuItem(child: Text('unlimited'.tr), value: 0),
          const DropdownMenuItem(child: Text('512MB'), value: 512),
          const DropdownMenuItem(child: Text('1GB'), value: 1024),
          const DropdownMenuItem(child: Text('2GB'), value: 2048),
          const DropdownMenuItem(child: Text('5GB'), value: 5120),
          const DropdownMenuItem(child: Text('10GB'), value: 10240),
        ],
      ),
    );
  }

  Widget _buildSmartCacheEvictPolicy() {
    return ListTile(
      title: Text('smartCacheEvictPolicy'.tr),
      subtitle: Text('smartCacheEvictPolicyHint'.tr),
      trailing: DropdownButton<SmartCacheEvictPolicy>(
        value: networkSetting.smartCacheEvictPolicy.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (SmartCacheEvictPolicy? newValue) =>
            networkSetting.saveSmartCacheEvictPolicy(newValue ?? SmartCacheEvictPolicy.addedDate),
        items: [
          DropdownMenuItem(child: Text('smartCacheEvictByAddedDate'.tr), value: SmartCacheEvictPolicy.addedDate),
          DropdownMenuItem(child: Text('smartCacheEvictByUsageFrequency'.tr), value: SmartCacheEvictPolicy.usageFrequency),
        ],
      ),
    );
  }

  Widget _buildTimeoutTile({
    required BuildContext context,
    required String title,
    required RxInt value,
    required Future<void> Function(int) onSave,
  }) {
    return Obx(
      () => ListTile(
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${value.value} ms', style: UIConfig.settingPageListTileTrailingTextStyle(context)),
            const Icon(Icons.keyboard_arrow_right).marginOnly(left: 4),
          ],
        ),
        onTap: () async {
          int? result = await showDialog<int>(
            context: context,
            builder: (context) => _TimeoutSettingDialog(title: title, initialValue: value.value),
          );
          if (result != null) {
            await onSave(result);
            toast('saveSuccess'.tr);
          }
        },
      ),
    );
  }
}

class _TimeoutSettingDialog extends StatefulWidget {
  final String title;
  final int initialValue;

  const _TimeoutSettingDialog({Key? key, required this.title, required this.initialValue}) : super(key: key);

  @override
  State<_TimeoutSettingDialog> createState() => _TimeoutSettingDialogState();
}

class _TimeoutSettingDialogState extends State<_TimeoutSettingDialog> {
  static const int min = 0;
  static const int max = 60000;
  static const int step = 500;

  late int value;
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    value = widget.initialValue.clamp(min, max);
    controller = TextEditingController(text: value.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text('ms', style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor)),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ step,
              label: '$value ms',
              onChanged: (double v) => _setValue(v.round()),
            ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: min, maxValue: max),
              ],
              decoration: InputDecoration(
                isDense: true,
                suffixText: 'ms',
                errorText: _hasError() ? 'invalid'.tr : null,
              ),
              onSubmitted: (String text) => _confirm(),
              onChanged: (String text) {
                int? parsed = _parse();
                if (parsed != null) {
                  setState(() => value = parsed);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(onPressed: _confirm, child: Text('OK'.tr)),
      ],
    );
  }

  int? _parse() {
    int? parsed = int.tryParse(controller.text);
    if (parsed == null || parsed < min || parsed > max) {
      return null;
    }
    return parsed;
  }

  bool _hasError() => controller.text.isNotEmpty && _parse() == null;

  void _setValue(int newValue) {
    setState(() {
      value = newValue;
      controller.text = newValue.toString();
    });
  }

  void _confirm() {
    int? parsed = _parse();
    if (parsed == null) {
      return;
    }
    backRoute(result: parsed);
  }
}

/// Shows the total size of the long-term cache: the page cache (dio_cache)
/// plus the image cache, with refresh and clear actions.
class _CacheSizeTile extends StatefulWidget {
  const _CacheSizeTile({Key? key}) : super(key: key);

  @override
  State<_CacheSizeTile> createState() => _CacheSizeTileState();
}

class _CacheSizeTileState extends State<_CacheSizeTile> {
  bool loading = false;
  String sizeText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<int> _computeTotalCacheSize() async {
    final int pageBytes = await DioCacheDao.getTotalSize();

    final Directory imageCacheDirectory = pathService.smartCacheDir;
    int imageBytes = 0;
    if (imageCacheDirectory.existsSync()) {
      for (final FileSystemEntity entity in imageCacheDirectory.listSync()) {
        if (entity is File) {
          imageBytes += entity.lengthSync();
        }
      }
    }
    return pageBytes + imageBytes;
  }

  Future<void> _load() async {
    if (loading) {
      return;
    }

    setState(() => loading = true);

    try {
      final int totalBytes = await _computeTotalCacheSize();
      sizeText = byte2String(totalBytes.toDouble());
    } catch (e) {
      log.error('Get cache size failed', e);
      sizeText = '-1B';
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _clear() async {
    if (loading) {
      return;
    }

    await ehRequest.removeAllCache();
    await clearDiskCachedImages();
    toast('clearSuccess'.tr, isCenter: false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('cacheSize'.tr),
      subtitle: Text(loading || sizeText.isEmpty ? 'loading'.tr : sizeText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _clear, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/utils/file_type_utils.dart';
import '../../../../data/api/file_api.dart';
import '../../../common/components/frosted_action_button.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../server_detail/providers/active_server_provider.dart';

class FileImageViewerPage extends ConsumerStatefulWidget {
  const FileImageViewerPage({
    super.key,
    required this.path,
    required this.fileName,
  });

  final String path;
  final String fileName;

  @override
  ConsumerState<FileImageViewerPage> createState() =>
      _FileImageViewerPageState();
}

class _FileImageViewerPageState extends ConsumerState<FileImageViewerPage> {
  Uint8List? _imageData;
  String? _error;
  bool _isLoading = true;
  final PhotoViewController _photoViewController = PhotoViewController();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final serverId = ref.read(activeServerIdProvider);
      final client = await ref.read(dioClientProvider(serverId).future);
      final imageData = await FileApi(client).downloadBytes(path: widget.path);

      if (mounted) {
        setState(() {
          _imageData = imageData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareImage() async {
    if (_imageData == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${widget.fileName}');
      await tempFile.writeAsBytes(_imageData!);

      await SharePlus.instance.share(
        ShareParams(subject: widget.fileName, files: [XFile(tempFile.path)]),
      );
    } catch (e) {
      if (mounted) {
        // 可以根据需要显示错误 toast
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      title: widget.fileName,
      showBlur: false,
      titleColor: CupertinoColors.white,
      useMiddleTruncate: true,
      trailingBuilder: (isDark, isOverlapping) => FrostedActionButton(
        text: context.l10n.common_share,
        icon: TablerIcons.share_2,
        isDark: true,
        isOverlapping: isOverlapping,
        foregroundColor: CupertinoColors.white,
        onTap: _imageData != null ? _shareImage : null,
      ),
      body: Container(
        color: CupertinoColors.black,
        child: Center(child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const CupertinoActivityIndicator(radius: 12);
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: CupertinoColors.systemRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.files_imageLoadFailed,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              onPressed: _loadImage,
              child: Text(context.l10n.common_retry),
            ),
          ],
        ),
      );
    }

    if (_imageData == null) {
      return Text(
        context.l10n.files_imageNoData,
        style: const TextStyle(color: CupertinoColors.white),
      );
    }

    final isSvg = FileTypeUtils.isSvgByName(widget.fileName);

    if (isSvg) {
      return PhotoView.customChild(
        controller: _photoViewController,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4.1,
        initialScale: PhotoViewComputedScale.contained,
        basePosition: Alignment.center,
        backgroundDecoration: const BoxDecoration(color: CupertinoColors.black),
        child: SvgPicture.memory(
          _imageData!,
          placeholderBuilder: (context) =>
              const Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    return PhotoView(
      imageProvider: MemoryImage(_imageData!),
      controller: _photoViewController,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4.1,
      initialScale: PhotoViewComputedScale.contained,
      basePosition: Alignment.center,
      backgroundDecoration: const BoxDecoration(color: CupertinoColors.black),
      loadingBuilder: (context, event) =>
          const Center(child: CupertinoActivityIndicator()),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey),
      ),
    );
  }
}

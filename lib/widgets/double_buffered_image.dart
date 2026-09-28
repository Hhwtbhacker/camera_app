import 'package:flutter/material.dart';

/// 双缓冲网络图片。
///
/// 当 [imageUrl] 变化时，先在后台解码下一帧（_next），解码完成后再替换当前显示
/// 帧（_current）。这样用户永远不会看到“旧图被清空 → 白屏/黑屏 → 新图显示”的闪烁
/// 过程，即使网络抖动也能保持上一帧稳定显示。
class DoubleBufferedImage extends StatefulWidget {
  /// 图片地址，变化时会触发后台预加载
  final String imageUrl;

  /// 图片填充方式
  final BoxFit fit;

  /// 加载占位图
  final Widget? placeholder;

  /// 请求头
  final Map<String, String>? headers;

  const DoubleBufferedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.headers,
  });

  @override
  State<DoubleBufferedImage> createState() => _DoubleBufferedImageState();
}

class _DoubleBufferedImageState extends State<DoubleBufferedImage> {
  String? _currentUrl;
  String? _loadingUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.imageUrl;
  }

  @override
  void didUpdateWidget(covariant DoubleBufferedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl && _loadingUrl != widget.imageUrl) {
      _preload(widget.imageUrl);
    }
  }

  /// 后台预加载下一帧，完成后替换当前帧。
  Future<void> _preload(String url) async {
    _loadingUrl = url;
    try {
      await precacheImage(
        NetworkImage(url, headers: widget.headers),
        context,
      );
      if (mounted && widget.imageUrl == url) {
        setState(() => _currentUrl = url);
      }
    } catch (_) {
      // 加载失败时保持当前帧继续显示，避免黑屏闪烁
    } finally {
      if (_loadingUrl == url) {
        _loadingUrl = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentUrl;
    if (current == null) {
      return widget.placeholder ??
          const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
    }

    return Image.network(
      current,
      gaplessPlayback: true,
      fit: widget.fit,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 64, color: Colors.white38),
              SizedBox(height: 12),
              Text('图片加载失败', style: TextStyle(color: Colors.white54)),
            ],
          ),
        );
      },
    );
  }
}

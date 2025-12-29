import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

/// Widget لعرض الصور (URLs أو ملفات محلية)
class ImageWidget extends StatefulWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ImageWidget({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  bool _fileExists = false;
  bool _isCheckingFile = true;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  @override
  void didUpdateWidget(ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _checkFileExists();
    }
  }

  Future<void> _checkFileExists() async {
    if (widget.imagePath == null || 
        widget.imagePath!.isEmpty ||
        widget.imagePath!.startsWith('http://') ||
        widget.imagePath!.startsWith('https://')) {
      setState(() {
        _isCheckingFile = false;
        _fileExists = false;
      });
      return;
    }

    try {
      final file = File(widget.imagePath!);
      final exists = await file.exists();
      if (mounted) {
        setState(() {
          _fileExists = exists;
          _isCheckingFile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fileExists = false;
          _isCheckingFile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      return _buildErrorWidget();
    }

    // إذا كانت الصورة من URL
    if (widget.imagePath!.startsWith('http://') || widget.imagePath!.startsWith('https://')) {
      return ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: CachedNetworkImage(
          imageUrl: widget.imagePath!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (context, url) => widget.placeholder ?? _buildPlaceholder(),
          errorWidget: (context, url, error) {
            // Error loading image from URL
            return widget.errorWidget ?? _buildErrorWidget();
          },
        ),
      );
    }

    // إذا كانت الصورة ملف محلي
    if (_isCheckingFile) {
      return _buildPlaceholder();
    }

    if (!_fileExists) {
      return widget.errorWidget ?? _buildErrorWidget();
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Image.file(
        File(widget.imagePath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.width != null ? widget.width!.toInt() : null,
        cacheHeight: widget.height != null ? widget.height!.toInt() : null,
        errorBuilder: (context, error, stackTrace) {
          // Error loading image from file
          return widget.errorWidget ?? _buildErrorWidget();
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.lightPrimary,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.lightPrimary,
      child: const Icon(
        Icons.image_not_supported_rounded,
        color: AppTheme.primaryColor,
      ),
    );
  }
}








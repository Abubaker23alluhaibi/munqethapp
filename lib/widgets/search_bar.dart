import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

class AnimatedSearchBar extends StatefulWidget {
  final String? hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onTap;

  const AnimatedSearchBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isExpanded = false;
  bool _isFocused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _controller.clear();
        _isFocused = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 56,
      width: _isExpanded ? double.infinity : 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: _isFocused ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: _isExpanded
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    onTap: () {
                      setState(() => _isFocused = true);
                      widget.onTap?.call();
                    },
                    decoration: InputDecoration(
                      hintText: widget.hintText ?? 'ابحث...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppTheme.textSecondary,
                  onPressed: _toggleSearch,
                ),
              ],
            )
          : Center(
              child: IconButton(
                icon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
                onPressed: _toggleSearch,
              ),
            ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 300.ms, curve: Curves.easeOut);
  }
}

class SearchBarWidget extends StatelessWidget {
  final String? hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onTap;

  const SearchBarWidget({
    super.key,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.lightPrimary.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hintText ?? 'ابحث...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}


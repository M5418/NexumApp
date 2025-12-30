import 'package:flutter/material.dart';

/// Skeleton placeholder for posts while loading
/// Shows immediately to give perceived < 1s load time
class PostSkeleton extends StatelessWidget {
  final bool isDarkMode;
  
  const PostSkeleton({
    super.key,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final shimmerBase = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0);
    final shimmerHighlight = isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Name + Time
          Row(
            children: [
              _SkeletonBox(
                width: 44,
                height: 44,
                borderRadius: 22,
                baseColor: shimmerBase,
                highlightColor: shimmerHighlight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(
                      width: 120,
                      height: 14,
                      borderRadius: 4,
                      baseColor: shimmerBase,
                      highlightColor: shimmerHighlight,
                    ),
                    const SizedBox(height: 6),
                    _SkeletonBox(
                      width: 80,
                      height: 10,
                      borderRadius: 4,
                      baseColor: shimmerBase,
                      highlightColor: shimmerHighlight,
                    ),
                  ],
                ),
              ),
              _SkeletonBox(
                width: 24,
                height: 24,
                borderRadius: 12,
                baseColor: shimmerBase,
                highlightColor: shimmerHighlight,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Text content lines
          _SkeletonBox(
            width: double.infinity,
            height: 12,
            borderRadius: 4,
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
          ),
          const SizedBox(height: 8),
          _SkeletonBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 12,
            borderRadius: 4,
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
          ),
          const SizedBox(height: 8),
          _SkeletonBox(
            width: MediaQuery.of(context).size.width * 0.5,
            height: 12,
            borderRadius: 4,
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
          ),
          
          const SizedBox(height: 16),
          
          // Media placeholder
          _SkeletonBox(
            width: double.infinity,
            height: 200,
            borderRadius: 12,
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) => _SkeletonBox(
              width: 60,
              height: 24,
              borderRadius: 12,
              baseColor: shimmerBase,
              highlightColor: shimmerHighlight,
            )),
          ),
        ],
      ),
    );
  }
}

/// Animated skeleton box with shimmer effect
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// List of skeleton posts for initial loading state
class PostSkeletonList extends StatelessWidget {
  final int count;
  final bool isDarkMode;
  
  const PostSkeletonList({
    super.key,
    this.count = 3,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (context, index) => PostSkeleton(isDarkMode: isDarkMode),
    );
  }
}

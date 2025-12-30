import 'package:flutter/material.dart';

class ConnectionCardSkeleton extends StatefulWidget {
  final bool isDarkMode;
  
  const ConnectionCardSkeleton({super.key, this.isDarkMode = false});

  @override
  State<ConnectionCardSkeleton> createState() => _ConnectionCardSkeletonState();
}

class _ConnectionCardSkeletonState extends State<ConnectionCardSkeleton>
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
    final isDark = widget.isDarkMode;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image placeholder
              Expanded(
                flex: 3,
                child: _ShimmerBox(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  animation: _animation.value,
                ),
              ),
              // Avatar placeholder (overlapping)
              Transform.translate(
                offset: const Offset(0, -20),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: _ShimmerBox(
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        animation: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              // Name placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      animation: _animation.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Username placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Container(
                    height: 10,
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      animation: _animation.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Button placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    animation: _animation.value,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final Color baseColor;
  final Color highlightColor;
  final double animation;

  const _ShimmerBox({
    required this.baseColor,
    required this.highlightColor,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(animation - 1, 0),
          end: Alignment(animation + 1, 0),
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Grid of connection card skeletons for loading state
class ConnectionGridSkeleton extends StatelessWidget {
  final int count;
  final bool isDarkMode;
  
  const ConnectionGridSkeleton({
    super.key,
    this.count = 6,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 155 / 260,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return ConnectionCardSkeleton(isDarkMode: isDarkMode);
      },
    );
  }
}

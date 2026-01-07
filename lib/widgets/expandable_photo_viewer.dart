import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Shows an expandable photo viewer dialog
/// For profile photos: displays in a large circle with elegant design
/// For cover photos: displays full-width with normal expansion
void showExpandablePhoto({
  required BuildContext context,
  required String? imageUrl,
  required bool isProfilePhoto,
  String? heroTag,
  String? fallbackInitial,
}) {
  if (imageUrl == null || imageUrl.isEmpty) return;
  
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.9),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ExpandablePhotoViewer(
        imageUrl: imageUrl,
        isProfilePhoto: isProfilePhoto,
        heroTag: heroTag,
        fallbackInitial: fallbackInitial,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _ExpandablePhotoViewer extends StatelessWidget {
  final String imageUrl;
  final bool isProfilePhoto;
  final String? heroTag;
  final String? fallbackInitial;

  const _ExpandablePhotoViewer({
    required this.imageUrl,
    required this.isProfilePhoto,
    this.heroTag,
    this.fallbackInitial,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Main content
            Center(
              child: GestureDetector(
                onTap: () {}, // Prevent tap from closing when tapping on image
                child: isProfilePhoto
                    ? _buildProfilePhotoView(context, size, isDark)
                    : _buildCoverPhotoView(context, size),
              ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoView(BuildContext context, Size size, bool isDark) {
    // Calculate size - large circle that fits nicely on screen
    final circleSize = size.width * 0.85;
    final maxSize = size.height * 0.6;
    final finalSize = circleSize > maxSize ? maxSize : circleSize;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decorative ring
        Container(
          width: finalSize + 16,
          height: finalSize + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFBFAE01).withValues(alpha: 0.8),
                const Color(0xFFD4C100).withValues(alpha: 0.6),
                const Color(0xFFBFAE01).withValues(alpha: 0.4),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: finalSize + 8,
              height: finalSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              ),
              child: Center(
                child: heroTag != null
                    ? Hero(
                        tag: heroTag!,
                        child: _buildCircleImage(finalSize),
                      )
                    : _buildCircleImage(finalSize),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleImage(double size) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: Colors.grey[800],
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFBFAE01),
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: Colors.grey[800],
          child: Center(
            child: Text(
              fallbackInitial ?? '?',
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPhotoView(BuildContext context, Size size) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: size.width,
        maxHeight: size.height * 0.7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: heroTag != null
            ? Hero(
                tag: heroTag!,
                child: _buildCoverImage(),
              )
            : _buildCoverImage(),
      ),
    );
  }

  Widget _buildCoverImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        height: 300,
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFBFAE01),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 300,
        color: Colors.grey[900],
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white54,
            size: 48,
          ),
        ),
      ),
    );
  }
}

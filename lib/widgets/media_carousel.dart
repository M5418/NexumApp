import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;

  const MediaCarousel({super.key, required this.imageUrls, this.height = 300});

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    if (widget.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: CachedNetworkImage(
          imageUrl: widget.imageUrls.first,
          height: widget.height,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: widget.height,
            color: const Color(0xFF666666).withValues(alpha: 51),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: widget.height,
            color: const Color(0xFF666666).withValues(alpha: 51),
            child: const Icon(
              Icons.broken_image,
              color: Color(0xFF666666),
              size: 50,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: widget.imageUrls[index],
                  height: widget.height,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: widget.height,
                    color: const Color(0xFF666666).withValues(alpha: 51),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFBFAE01),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: widget.height,
                    color: const Color(0xFF666666).withValues(alpha: 51),
                    child: const Icon(
                      Icons.broken_image,
                      color: Color(0xFF666666),
                      size: 50,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Page indicators
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.imageUrls.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 128),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

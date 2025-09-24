import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MediaNavBar extends StatelessWidget {
  final int currentIndex; // 0-based
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const MediaNavBar({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${currentIndex + 1} of $total',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: onPrev != null ? Colors.white : Colors.grey,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: onNext != null ? Colors.white : Colors.grey,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

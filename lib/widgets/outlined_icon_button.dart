import 'package:flutter/material.dart';

class OutlinedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color borderColor;
  final double borderWidth;

  const OutlinedIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconSize = 18,
    this.borderColor = const Color(0xFF666666),
    this.borderWidth = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          side: BorderSide(color: borderColor, width: borderWidth),
          backgroundColor: Colors.transparent,
        ),
        child: Icon(icon, size: iconSize, color: borderColor),
      ),
    );
  }
}

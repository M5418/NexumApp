import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/post.dart';

class ReactionPicker extends StatelessWidget {
  final Function(ReactionType) onReactionSelected;
  final ReactionType? currentReaction;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.currentReaction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Opacity(
          opacity: ((scale - 0.95) / 0.05).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF111111).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReactionButton(
                  icon: Icons.workspace_premium,
                  reactionType: ReactionType.diamond,
                  isSelected: currentReaction == ReactionType.diamond,
                  onTap: () => onReactionSelected(ReactionType.diamond),
                ),
                const SizedBox(width: 12),
                _ReactionButton(
                  icon: Icons.thumb_up_alt_outlined,
                  reactionType: ReactionType.like,
                  isSelected: currentReaction == ReactionType.like,
                  onTap: () => onReactionSelected(ReactionType.like),
                ),
                const SizedBox(width: 12),
                _ReactionButton(
                  icon: Icons.favorite_border,
                  reactionType: ReactionType.heart,
                  isSelected: currentReaction == ReactionType.heart,
                  onTap: () => onReactionSelected(ReactionType.heart),
                ),
                const SizedBox(width: 12),
                _ReactionButton(
                  icon: Icons.emoji_emotions_outlined,
                  reactionType: ReactionType.wow,
                  isSelected: currentReaction == ReactionType.wow,
                  onTap: () => onReactionSelected(ReactionType.wow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final ReactionType reactionType;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.reactionType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFBFAE01).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          scale: isSelected ? 1.12 : 1.0,
          child: Icon(
            icon,
            size: 24,
            color: isSelected ? const Color(0xFFBFAE01) : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? const Color(0xFFBFAE01) : const Color(0xFF666666),
        ),
      ),
    );
  }
}

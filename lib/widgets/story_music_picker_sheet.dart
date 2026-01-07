import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/models/story_music_model.dart';
import '../repositories/firebase/firebase_story_music_repository.dart';

class StoryMusicPickerSheet extends StatefulWidget {
  final StoryMusicModel? currentSelection;
  final bool isVideoMuted; // If video is muted, music can be selected
  
  const StoryMusicPickerSheet({
    super.key,
    this.currentSelection,
    this.isVideoMuted = true,
  });

  @override
  State<StoryMusicPickerSheet> createState() => _StoryMusicPickerSheetState();
}

class _StoryMusicPickerSheetState extends State<StoryMusicPickerSheet> {
  final FirebaseStoryMusicRepository _musicRepo = FirebaseStoryMusicRepository();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<StoryMusicModel> _tracks = [];
  bool _isLoading = true;
  String? _playingTrackId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadMusic();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _totalDuration = duration;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playingTrackId = null;
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    });
  }

  Future<void> _loadMusic() async {
    setState(() => _isLoading = true);
    
    // Try cache first for instant display
    final cached = await _musicRepo.getStoryMusicFromCache();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _tracks = cached;
        _isLoading = false;
      });
    }
    
    // Then fetch fresh data
    final fresh = await _musicRepo.getStoryMusic();
    if (mounted) {
      setState(() {
        _tracks = fresh;
        _isLoading = false;
      });
    }
  }

  Future<void> _playPreview(StoryMusicModel track) async {
    if (_playingTrackId == track.id && _isPlaying) {
      // Pause current track
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else if (_playingTrackId == track.id && !_isPlaying) {
      // Resume current track
      await _audioPlayer.resume();
      setState(() => _isPlaying = true);
    } else {
      // Play new track
      setState(() {
        _playingTrackId = track.id;
        _currentPosition = Duration.zero;
      });
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(track.audioUrl));
    }
  }

  Future<void> _stopPreview() async {
    await _audioPlayer.stop();
    setState(() {
      _playingTrackId = null;
      _isPlaying = false;
      _currentPosition = Duration.zero;
    });
  }

  void _selectTrack(StoryMusicModel track) {
    _stopPreview();
    Navigator.pop(context, track);
  }

  void _removeSelection() {
    _stopPreview();
    Navigator.pop(context, 'remove'); // Special value to indicate removal
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF666666).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  lang.t('story.select_music'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                // Remove button if there's a current selection
                if (widget.currentSelection != null)
                  TextButton.icon(
                    onPressed: _removeSelection,
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    label: Text(
                      lang.t('story.remove_music'),
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Current selection indicator
          if (widget.currentSelection != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFAE01), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFFBFAE01), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${lang.t('story.current')}: ${widget.currentSelection!.title}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          const Divider(height: 1),
          
          // Music list
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                      ),
                    ),
                  )
                : _tracks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.music_off,
                                size: 48,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                lang.t('story.no_music_available'),
                                style: GoogleFonts.inter(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _tracks.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          final isCurrentlyPlaying = _playingTrackId == track.id;
                          final isSelected = widget.currentSelection?.id == track.id;
                          
                          return _MusicTrackTile(
                            track: track,
                            isPlaying: isCurrentlyPlaying && _isPlaying,
                            isSelected: isSelected,
                            currentPosition: isCurrentlyPlaying ? _currentPosition : Duration.zero,
                            totalDuration: isCurrentlyPlaying ? _totalDuration : Duration(seconds: track.durationSec),
                            isDark: isDark,
                            onPlayTap: () => _playPreview(track),
                            onSelectTap: () => _selectTrack(track),
                          );
                        },
                      ),
          ),
          
          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _MusicTrackTile extends StatelessWidget {
  final StoryMusicModel track;
  final bool isPlaying;
  final bool isSelected;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isDark;
  final VoidCallback onPlayTap;
  final VoidCallback onSelectTap;

  const _MusicTrackTile({
    required this.track,
    required this.isPlaying,
    required this.isSelected,
    required this.currentPosition,
    required this.totalDuration,
    required this.isDark,
    required this.onPlayTap,
    required this.onSelectTap,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelectTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected 
            ? const Color(0xFFBFAE01).withValues(alpha: 0.1)
            : Colors.transparent,
        child: Row(
          children: [
            // Play/Pause button with cover
            GestureDetector(
              onTap: onPlayTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFAE01).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: track.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track.coverUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(
                              Icons.music_note,
                              color: Color(0xFFBFAE01),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.music_note,
                              color: Color(0xFFBFAE01),
                            ),
                          )
                        : const Icon(
                            Icons.music_note,
                            color: Color(0xFFBFAE01),
                            size: 24,
                          ),
                  ),
                  // Play/Pause overlay
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.check_circle,
                            color: Color(0xFFBFAE01),
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.artist}  •  ${_formatDuration(totalDuration)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  // Progress bar when playing
                  if (isPlaying || currentPosition > Duration.zero)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: totalDuration.inMilliseconds > 0
                                    ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
                                    : 0,
                                backgroundColor: isDark ? Colors.white24 : Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                                minHeight: 3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(currentPosition),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFBFAE01),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Use button
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onSelectTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected 
                    ? const Color(0xFF666666)
                    : const Color(0xFFBFAE01),
                foregroundColor: isSelected ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                isSelected ? 'Selected' : 'Use',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

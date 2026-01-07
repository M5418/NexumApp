import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/models/story_music_model.dart';
import 'repositories/firebase/firebase_story_music_repository.dart';
import 'add_story_music_page.dart';

class StoryMusicListPage extends StatefulWidget {
  const StoryMusicListPage({super.key});

  @override
  State<StoryMusicListPage> createState() => _StoryMusicListPageState();
}

class _StoryMusicListPageState extends State<StoryMusicListPage> {
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
    
    try {
      final tracks = await _musicRepo.getStoryMusic(limit: 100);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playPreview(StoryMusicModel track) async {
    if (_playingTrackId == track.id && _isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else if (_playingTrackId == track.id && !_isPlaying) {
      await _audioPlayer.resume();
      setState(() => _isPlaying = true);
    } else {
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

  Future<void> _deleteTrack(StoryMusicModel track) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('story_music.delete_title'), style: GoogleFonts.inter()),
        content: Text(
          lang.t('story_music.delete_message'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('common.cancel'), style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lang.t('common.delete'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      try {
        await _musicRepo.deleteMusic(track.id);
        await _loadMusic();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.t('story_music.deleted'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFBFAE01),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.t('story_music.delete_failed'), style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(StoryMusicModel track) async {
    try {
      await _musicRepo.toggleMusicActive(track.id, !track.isActive);
      await _loadMusic();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0C0C0C) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              lang.t('story_music.title'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFFBFAE01)),
                onPressed: () async {
                  await _stopPreview();
                  if (!mounted) return;
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'add_story_music'),
                      builder: (_) => const AddStoryMusicPage(),
                    ),
                  );
                  if (result == true) {
                    _loadMusic();
                  }
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                  ),
                )
              : _tracks.isEmpty
                  ? _buildEmptyState(isDark, lang)
                  : RefreshIndicator(
                      onRefresh: _loadMusic,
                      color: const Color(0xFFBFAE01),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          return _buildTrackCard(track, isDark, lang);
                        },
                      ),
                    ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await _stopPreview();
              if (!mounted) return;
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'add_story_music'),
                  builder: (_) => const AddStoryMusicPage(),
                ),
              );
              if (result == true) {
                _loadMusic();
              }
            },
            backgroundColor: const Color(0xFFBFAE01),
            icon: const Icon(Icons.add, color: Colors.black),
            label: Text(
              lang.t('story_music.add'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: 16),
          Text(
            lang.t('story_music.no_music'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang.t('story_music.add_first'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(StoryMusicModel track, bool isDark, LanguageProvider lang) {
    final isCurrentlyPlaying = _playingTrackId == track.id;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Play button with cover
                GestureDetector(
                  onTap: () => _playPreview(track),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: track.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: track.coverUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Icon(
                                  Icons.music_note,
                                  color: Color(0xFFBFAE01),
                                  size: 28,
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.music_note,
                                  color: Color(0xFFBFAE01),
                                  size: 28,
                                ),
                              )
                            : const Icon(
                                Icons.music_note,
                                color: Color(0xFFBFAE01),
                                size: 28,
                              ),
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isCurrentlyPlaying && _isPlaying ? Icons.pause : Icons.play_arrow,
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
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Active status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: track.isActive
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              track.isActive ? lang.t('story_music.active') : lang.t('story_music.inactive'),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: track.isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${track.artist}  •  ${track.formattedDuration}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      if (track.genre != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          track.genre!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFBFAE01),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'toggle':
                        _toggleActive(track);
                        break;
                      case 'delete':
                        _deleteTrack(track);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            track.isActive ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            track.isActive ? lang.t('story_music.deactivate') : lang.t('story_music.activate'),
                            style: GoogleFonts.inter(),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          const SizedBox(width: 12),
                          Text(
                            lang.t('common.delete'),
                            style: GoogleFonts.inter(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Progress bar when playing
          if (isCurrentlyPlaying)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _totalDuration.inMilliseconds > 0
                            ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                            : 0,
                        backgroundColor: isDark ? Colors.white24 : Colors.black12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_totalDuration),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

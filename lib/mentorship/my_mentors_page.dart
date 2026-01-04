// c:\Users\dehou\nexum-app\lib\mentorship\my_mentors_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../repositories/interfaces/mentorship_repository.dart';
import 'mentorship_chat_page.dart';
import '../core/i18n/language_provider.dart';

class MyMentorsPage extends StatefulWidget {
  const MyMentorsPage({super.key});

  @override
  State<MyMentorsPage> createState() => _MyMentorsPageState();
}

class _MyMentorsPageState extends State<MyMentorsPage> {
  late MentorshipRepository _repo;
  bool _loading = true;
  String? _error;
  List<MentorModel> _mentors = [];

  @override
  void initState() {
    super.initState();
    _repo = context.read<MentorshipRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.getMyMentors();
      if (!mounted) return;
      setState(() => _mentors = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load mentors: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final surfaceColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    const secondaryTextColor = Color(0xFF666666);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('mentorship.my_mentors'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading && _mentors.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null && _mentors.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01)),
                          child: Text('Retry', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFBFAE01),
                  onRefresh: _load,
                  child: _mentors.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                Provider.of<LanguageProvider>(context, listen: false).t('mentorship.no_mentors'),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondaryTextColor),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _mentors.length,
                          itemBuilder: (context, index) {
                            final mentor = _mentors[index];
                            final avatar = mentor.avatarUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(mentor.name)}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(13),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundImage: NetworkImage(avatar),
                                          ),
                                          if (mentor.isOnline)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: surfaceColor,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mentor.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              mentor.profession ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: secondaryTextColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              mentor.company ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: secondaryTextColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.chat_bubble_outline, color: textColor),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              settings: const RouteSettings(name: 'mentorship_chat'),
                                              builder: (context) => MentorshipChatPage(
                                                mentorUserId: mentor.id,
                                                mentorName: mentor.name,
                                                mentorAvatar: avatar,
                                                isOnline: mentor.isOnline,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        mentor.rating.toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${mentor.reviewCount} ${Provider.of<LanguageProvider>(context, listen: false).t('mentorship.reviews')})',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${mentor.yearsExperience}+ ${Provider.of<LanguageProvider>(context, listen: false).t('mentorship.years_exp')}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFBFAE01),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    mentor.bio,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: secondaryTextColor,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: mentor.expertise.map((skill) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFBFAE01).withAlpha(26),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          skill,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFBFAE01),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            // TODO: Schedule session flow (optional)
                                          },
                                          icon: Icon(Icons.calendar_today, size: 16, color: textColor),
                                          label: Text(
                                            Provider.of<LanguageProvider>(context, listen: false).t('mentorship.schedule'),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: textColor,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: textColor.withAlpha(51)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                settings: const RouteSettings(name: 'mentorship_chat'),
                                                builder: (context) => MentorshipChatPage(
                                                  mentorUserId: mentor.id,
                                                  mentorName: mentor.name,
                                                  mentorAvatar: avatar,
                                                  isOnline: mentor.isOnline,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.chat, size: 16, color: Colors.black),
                                          label: Text(
                                            Provider.of<LanguageProvider>(context, listen: false).t('mentorship.message'),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFBFAE01),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
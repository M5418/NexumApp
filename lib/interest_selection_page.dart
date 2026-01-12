import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'connect_friends_page.dart';
import 'core/profile_api.dart';
import 'responsive/responsive_breakpoints.dart';
import 'services/community_interest_sync_service.dart';
import 'services/onboarding_service.dart';

class InterestSelectionPage extends StatefulWidget {
  final List<String>? initialSelected;
  final bool returnSelectedOnPop;
  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;
  final String selectedStatus;

  const InterestSelectionPage({
    super.key,
    this.initialSelected,
    this.returnSelectedOnPop = false,
    this.firstName = 'User',
    this.lastName = '',
    this.hasProfilePhoto = false,
    this.selectedStatus = '',
  });

  @override
  State<InterestSelectionPage> createState() => _InterestSelectionPageState();
}

class _InterestSelectionPageState extends State<InterestSelectionPage> {
  final Set<String> _selectedInterests = {};
  final int _maxInterests = 10;
  bool _isSaving = false;

  final Map<String, List<String>> _interestCategories = {
    'Arts & Culture': [
      'Art',
      'Painting',
      'Sculpture',
      'Drawing',
      'Photography',
      'Architecture',
      'Graphic Design',
      'Calligraphy',
      'Street Art',
      'Museums',
      'Art History',
      'Theater',
      'Comedy',
      'Opera',
      'Ballet',
      'Contemporary Dance',
      'Musicals',
      'Cultural Heritage',
      'Archaeology',
      'Mythology',
    ],
    'Music': [
      'Pop',
      'Hip-hop',
      'R&B',
      'Afrobeats',
      'Amapiano',
      'Reggae',
      'Dancehall',
      'Jazz',
      'Blues',
      'Rock',
      'Metal',
      'Country',
      'Classical',
      'EDM',
      'House',
      'Techno',
      'Trance',
      'Drum & Bass',
      'K-Pop',
      'J-Pop',
      'Gospel',
      'Songwriting',
      'Music Production',
      'DJing',
      'Piano',
      'Guitar',
    ],
    'Film & TV': [
      'Action Films',
      'Adventure Films',
      'Comedy Films',
      'Drama Films',
      'Thriller',
      'Horror',
      'Sci-Fi',
      'Fantasy',
      'Documentary',
      'Anime',
      'Animation',
      'TV Series',
      'K-Dramas',
      'Nollywood',
      'Bollywood',
      'Screenwriting',
      'Directing',
      'VFX',
    ],
    'Gaming': [
      'Mobile Games',
      'PC Games',
      'Console Games',
      'eSports',
      'MOBA',
      'FPS',
      'Battle Royale',
      'RPG',
      'MMORPG',
      'Strategy',
      'Simulation',
      'Sports Games',
      'Racing Games',
      'Puzzle',
      'Indie Games',
      'Game Design',
      'Game Streaming',
    ],
    'Books & Writing': [
      'Fiction',
      'Nonfiction',
      'Biographies',
      'Self-Help',
      'Fantasy',
      'Science Fiction',
      'Mystery & Thriller',
      'Poetry',
      'Manga',
      'Comics',
      'Creative Writing',
      'Journalism',
      'Blogging',
      'Copywriting',
      'Book Clubs',
      'Literary Criticism',
    ],
    'Science & Tech': [
      'Programming',
      'Mobile Development',
      'Web Front-end',
      'Web Back-end',
      'UI/UX Design',
      'Data Science',
      'Machine Learning',
      'Artificial Intelligence',
      'Computer Vision',
      'NLP',
      'Cybersecurity',
      'Blockchain',
      'Crypto',
      'Cloud Computing',
      'DevOps',
      'Databases',
      'Big Data',
      'AR/VR',
      'Internet of Things',
      'Robotics',
      'Electronics',
      '3D Printing',
      'Mathematics',
      'Astronomy',
      'Physics',
      'Biotechnology',
      'Bioinformatics',
      'Health Tech',
    ],
    'Business & Finance': [
      'Entrepreneurship',
      'Startups',
      'Product Management',
      'Project Management',
      'Marketing',
      'Digital Marketing',
      'Social Media Marketing',
      'SEO',
      'Online Advertising',
      'Sales',
      'Customer Success',
      'E-commerce',
      'Dropshipping',
      'Personal Finance',
      'Stock Investing',
      'Forex Trading',
      'Crypto Investing',
      'Real Estate',
      'Accounting',
      'Economics',
      'Leadership',
      'Management',
      'Human Resources',
      'Negotiation',
    ],
    'Health & Fitness': [
      'Strength Training',
      'Bodybuilding',
      'Cardio',
      'Running',
      'Cycling',
      'Swimming',
      'Yoga',
      'Pilates',
      'CrossFit',
      'HIIT',
      'Boxing',
      'Martial Arts',
      'Stretching & Mobility',
      'Nutrition',
      'Weight Loss',
      'Muscle Gain',
      'Physical Therapy',
      'Sports Science',
    ],
    'Wellness & Lifestyle': [
      'Meditation',
      'Mindfulness',
      'Breathwork',
      'Sleep Optimization',
      'Stress Management',
      'Journaling',
      'Productivity',
      'Time Management',
      'Minimalism',
      'Spiritual Growth',
      'Life Coaching',
      'Work-Life Balance',
    ],
    'Food & Drink': [
      'African Cuisine',
      'Asian Cuisine',
      'European Cuisine',
      'Middle Eastern Cuisine',
      'Street Food',
      'Vegan',
      'Vegetarian',
      'Gluten-Free',
      'Healthy Cooking',
      'Baking',
      'Pastry',
      'BBQ & Grilling',
      'Seafood',
      'Smoothies & Juices',
      'Coffee',
      'Tea',
      'Wine',
      'Craft Beer',
      'Mixology',
      'Quick Recipes',
      'Meal Prep',
    ],
    'Travel & Adventure': [
      'Travel',
      'Road Trips',
      'Backpacking',
      'Luxury Travel',
      'Business Travel',
      'Beaches',
      'Mountains',
      'Safari',
      'National Parks',
      'Camping',
      'Hiking',
      'Trekking',
      'Mountaineering',
      'Snorkeling',
      'Scuba Diving',
      'Skiing',
      'Snowboarding',
      'Urban Exploration',
      'Cultural Tourism',
      'Astro-tourism',
    ],
    'Nature & Environment': [
      'Wildlife',
      'Animal Conservation',
      'Ecology',
      'Recycling',
      'Renewable Energy',
      'Climate Action',
      'Ocean Conservation',
      'Desert Landscapes',
      'Tropical Forests',
      'Sustainable Living',
      'Gardening',
      'Indoor Plants',
      'Birdwatching',
      'Geology',
      'Meteorology',
    ],
    'Sports': [
      'Football (Soccer)',
      'Basketball',
      'Tennis',
      'Volleyball',
      'Handball',
      'Rugby',
      'Boxing',
      'MMA',
      'Judo',
      'Taekwondo',
      'Karate',
      'Wrestling',
      'Fencing',
      'Athletics',
      'Marathon',
      'Trail Running',
      'Road Cycling',
      'Mountain Biking',
      'BMX',
      'Triathlon',
      'Competitive Swimming',
      'Water Polo',
      'Rowing',
      'Canoe & Kayak',
      'Surfing',
      'Kitesurfing',
      'Sailing',
      'Diving',
      'Skiing',
      'Snowboarding',
      'Golf',
      'Cricket',
      'Baseball',
      'Softball',
      'Ice Hockey',
      'Field Hockey',
      'Badminton',
      'Table Tennis',
      'Squash',
      'Darts',
      'Snooker/Billiards',
      'Chess',
    ],
    'Fashion & Beauty': [
      'Fashion',
      'Streetwear',
      'Haute Couture',
      'Personal Styling',
      'Sustainable Fashion',
      'Shoes',
      'Watches',
      'Jewelry',
      'Makeup',
      'Skincare',
      'Haircare',
      'Barbering',
      'Fragrance',
      'Nail Art',
      'Runway Shows',
    ],
    'Home & DIY': [
      'Interior Design',
      'Home Organization',
      'Renovation',
      'DIY Projects',
      'Woodworking',
      'Metalworking',
      'Painting & Wallpaper',
      'Smart Home',
      'Residential Real Estate',
      'Landscaping',
      'Outdoor Gardening',
      'Home Security',
    ],
    'Photo & Video': [
      'Photography',
      'Portrait Photography',
      'Landscape Photography',
      'Street Photography',
      'Macro Photography',
      'Drone Photography',
      'Videography',
      'Video Editing',
      'Vlogging',
      'Live Streaming',
      'Motion Design',
      'Color Grading',
      'Cinematography',
      'Lighting Techniques',
      'Stock Footage',
    ],
    'Auto & Moto': [
      'Cars',
      'Electric Vehicles',
      'Supercars',
      'Car Tuning',
      'Detailing',
      'Safe Driving',
      'Motorcycles',
      'Motocross',
      'Karting',
      'Rally',
      'Formula 1',
      'Off-roading',
    ],
    'Aviation & Space': [
      'Commercial Aviation',
      'Business Aviation',
      'Private Pilots',
      'Airlines',
      'Airports',
      'Plane Spotting',
      'Drones',
      'Flight Simulators',
      'Aviation History',
      'Space Exploration',
      'Rockets',
      'Satellites',
    ],
    'Maritime': [
      'Boats',
      'Yachting',
      'Sailing',
      'Navigation',
      'Fishing',
      'Scuba & Freediving',
      'Ports & Logistics',
      'Maritime History',
    ],
    'Pets & Animals': [
      'Dogs',
      'Dog Training',
      'Cats',
      'Birds',
      'Fish & Aquariums',
      'Reptiles',
      'Small Mammals',
      'Exotic Pets',
      'Pet Adoption',
      'Veterinary Care',
      'Animal Photography',
      'Horse Riding',
    ],
    'Society & Causes': [
      'Volunteering',
      'Education Access',
      'Public Health',
      'Human Rights',
      'Diversity & Inclusion',
      'Road Safety',
      'Poverty Alleviation',
      'Social Innovation',
      'Civic Tech',
      'Smart Cities',
      'Open Data',
      'Community Building',
    ],
    'Religion & Spirituality': [
      'Christianity',
      'Islam',
      'Judaism',
      'Hinduism',
      'Buddhism',
      'African Spiritualities',
      'Bible Studies',
      'Comparative Religion',
      'Philosophy of Religion',
      'Interfaith Dialogue',
    ],
    'Life & Relationships': [
      'Family',
      'Parenting',
      'Relationships',
      'Marriage',
      'Friendship',
      'Mental Health',
      'Personal Development',
      'Career Growth',
      'Public Speaking',
      'Etiquette',
    ],
    'Education & Languages': [
      'Language Learning',
      'English',
      'French',
      'Spanish',
      'Arabic',
      'Swahili',
      'Portuguese',
      'Chinese',
      'Tutoring',
      'Teaching',
      'Scholarships',
      'MOOCs',
    ],
    'Podcasts & Audio': [
      'Podcasting',
      'Audio Production',
      'Voiceover',
      'Audiobooks',
      'True-Crime Podcasts',
      'News Podcasts',
      'Tech Podcasts',
      'Health Podcasts',
    ],
    'Pop Culture & Collecting': [
      'Superheroes',
      'Cosplay',
      'Comic Cons',
      'Action Figures',
      'Collectible Cards',
      'LEGO',
      'Model Building',
      'Retro Tech',
      'Vintage Games',
      'Memes',
      'Internet Culture',
      'Fan Theories',
    ],
  };

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else if (_selectedInterests.length < _maxInterests) {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedInterests.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      // Sync interests with community memberships BEFORE updating profile
      // Pass empty list as oldInterests for new accounts so all selected interests are treated as new
      await CommunityInterestSyncService().syncUserInterests(
        _selectedInterests.toList(),
        oldInterests: widget.initialSelected ?? [],
      );
      
      // Save interests to user profile
      await ProfileApi().update({
        'interest_domains': _selectedInterests.toList(),
      });
      
      // Update onboarding step
      await OnboardingService().setStep(OnboardingStep.connectFriends);
      
      if (!mounted) return;

      final next = ConnectFriendsPage(
        firstName: widget.firstName,
        lastName: widget.lastName,
      );

      if (!context.isMobile) {
        _pushWithPopupTransition(context, next);
      } else {
        Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'connect_friends'), builder: (_) => next));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('common.save_failed'),
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSelected != null) {
      _selectedInterests.addAll(widget.initialSelected!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !widget.returnSelectedOnPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.returnSelectedOnPop) {
          Navigator.pop(context, _selectedInterests.toList());
        }
      },
      child: context.isMobile ? _buildMobile(context, isDarkMode, lang) : _buildDesktop(context, isDarkMode, lang),
    );
  }

  Widget _buildMobile(BuildContext context, bool isDarkMode, LanguageProvider lang) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF000000) : Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 26),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const Spacer(),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        onPressed: () {
                          if (widget.returnSelectedOnPop) {
                            Navigator.pop(
                              context,
                              _selectedInterests.toList(),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          Provider.of<LanguageProvider>(context).t('common.interests'),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      // Continue button in app bar
                      if (!widget.returnSelectedOnPop)
                        TextButton(
                          onPressed: _selectedInterests.isNotEmpty && !_isSaving ? _saveAndContinue : null,
                          style: TextButton.styleFrom(
                            foregroundColor: _selectedInterests.isNotEmpty && !_isSaving
                                ? const Color(0xFFBFAE01)
                                : (isDarkMode ? Colors.grey : Colors.grey),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            _isSaving ? lang.t('profile_bio.saving') : lang.t('interests.continue'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _contentBody(context, isDarkMode, lang, gridColumns: 3, includeContinueButton: false),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, bool isDarkMode, LanguageProvider lang) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: isDarkMode ? const Color(0xFF000000) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header row (replaces app bar)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
                            onPressed: () {
                              if (widget.returnSelectedOnPop) {
                                Navigator.pop(context, _selectedInterests.toList());
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lang.t('interests.title'),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0x1A666666)),

                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _contentBody(context, isDarkMode, lang, gridColumns: 5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!widget.returnSelectedOnPop)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _selectedInterests.isNotEmpty && !_isSaving ? _saveAndContinue : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedInterests.isNotEmpty && !_isSaving
                                  ? const Color(0xFFBFAE01)
                                  : (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                              foregroundColor: _selectedInterests.isNotEmpty && !_isSaving
                                  ? Colors.black
                                  : (isDarkMode ? Colors.grey : Colors.grey),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              _isSaving ? lang.t('profile_bio.saving') : lang.t('interests.continue'),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contentBody(BuildContext context, bool isDarkMode, LanguageProvider lang, {required int gridColumns, bool includeContinueButton = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Title and Description
        Text(
          lang.t('interests.title'),
          style: GoogleFonts.inter(
            fontSize: context.isMobile ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${lang.t('interests.subtitle')}\n${_selectedInterests.length}/$_maxInterests ${lang.t('interests.selected')}',
          style: GoogleFonts.inter(
            fontSize: context.isMobile ? 14 : 15,
            color: const Color(0xFF999999),
          ),
        ),
        const SizedBox(height: 24),

        // Interests Blocks
        ..._interestCategories.entries.map((entry) {
          final category = entry.key;
          final interests = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: context.isMobile ? 18 : 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: interests.length,
                itemBuilder: (context, i) {
                  final interest = interests[i];
                  final isSelected = _selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () => _toggleInterest(interest),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFBFAE01)
                            : (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFBFAE01)
                              : (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                          width: 1,
                        ),
                        boxShadow: [
                          if (!isDarkMode)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 13),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          interest,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.black
                                : (isDarkMode ? Colors.white : Colors.black),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          );
        }),

        // Continue Button (only if includeContinueButton is true)
        if (includeContinueButton && context.isMobile && !widget.returnSelectedOnPop) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedInterests.isNotEmpty && !_isSaving ? _saveAndContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedInterests.isNotEmpty && !_isSaving
                    ? const Color(0xFFBFAE01)
                    : (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                foregroundColor: _selectedInterests.isNotEmpty && !_isSaving
                    ? Colors.black
                    : (isDarkMode ? Colors.grey : Colors.grey),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                _isSaving ? lang.t('profile_bio.saving') : lang.t('interests.continue'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  void _pushWithPopupTransition(BuildContext context, Widget page) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ));
  }
}
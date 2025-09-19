import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_feed_page.dart';

class ConnectFriendsPage extends StatefulWidget {
  final String firstName;
  final String lastName;

  const ConnectFriendsPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
  });

  @override
  State<ConnectFriendsPage> createState() => _ConnectFriendsPageState();
}

class _ConnectFriendsPageState extends State<ConnectFriendsPage> {
  // Track connection status for each friend
  final Map<String, bool> _connectionStatus = {};

  // Sample friend data
  final List<Map<String, String>> _suggestedFriends = [
    {
      'name': 'Nexum',
      'username': '@nexum.official',
      'avatar': 'N',
      'color': '0xFF000000',
    },
    {
      'name': 'Reid Vaughn',
      'username': '@reidvaughn',
      'avatar': 'R',
      'color': '0xFF4A90E2',
    },
    {
      'name': 'Blake Lambert',
      'username': '@blakelambert',
      'avatar': 'B',
      'color': '0xFF50C878',
    },
    {
      'name': 'Lily Collins',
      'username': '@lilycollins',
      'avatar': 'L',
      'color': '0xFFE91E63',
    },
    {
      'name': 'Nora James',
      'username': '@norajames',
      'avatar': 'N',
      'color': '0xFF9C27B0',
    },
    {
      'name': 'Keanu Angelo',
      'username': '@keanuang',
      'avatar': 'K',
      'color': '0xFFFF9800',
    },
    {
      'name': 'Zoe Monroe',
      'username': '@zoemonroe',
      'avatar': 'Z',
      'color': '0xFFFF5722',
    },
    {
      'name': 'Aria Morgan',
      'username': '@ariamorgan',
      'avatar': 'A',
      'color': '0xFF795548',
    },
    {
      'name': 'Skye Dawson',
      'username': '@skyedawson',
      'avatar': 'S',
      'color': '0xFF607D8B',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize connection status - some already connected
    _connectionStatus['Lily Collins'] = true;
    _connectionStatus['Nora James'] = true;
  }

  void _toggleConnection(String friendName) {
    setState(() {
      _connectionStatus[friendName] = !(_connectionStatus[friendName] ?? false);
    });
  }

  void _completeAccountCreation() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeFeedPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF000000) : Color(0xFFFFFFFF),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Spacer(),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Connect with Friends',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Description
              Text(
                'Find and connect with friends to see what they\'re up to.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 32),

              // Friends List
              Expanded(
                child: ListView.builder(
                  itemCount: _suggestedFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _suggestedFriends[index];
                    final isConnected =
                        _connectionStatus[friend['name']] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          // Profile Avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(int.parse(friend['color']!)),
                            ),
                            child: Center(
                              child: Text(
                                friend['avatar']!,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Name and Username
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend['name']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  friend['username']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Connect/Connected Button
                          SizedBox(
                            width: 90,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _toggleConnection(friend['name']!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected
                                    ? Colors.transparent
                                    : Colors.black,
                                foregroundColor: isConnected
                                    ? Colors.black
                                    : Colors.white,
                                elevation: 0,
                                side: isConnected
                                    ? const BorderSide(
                                        color: Color(0xFFE0E0E0),
                                        width: 1,
                                      )
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              child: Text(
                                isConnected ? 'Connected' : 'Connect',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              // Done Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _completeAccountCreation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Done',
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
    );
  }
}

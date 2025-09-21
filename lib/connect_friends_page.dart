import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_feed_page.dart';
import 'core/users_api.dart';

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
  final Map<int, bool> _connectionStatus = {};

  // Loaded from backend
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  Future<void> _loadUsers() async {
    try {
      final users = await UsersApi().list();
      setState(() {
        _friends = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      // TODO: Optionally show an error message to the user
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _toggleConnection(int userId) {
    setState(() {
      _connectionStatus[userId] = !(_connectionStatus[userId] ?? false);
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final user = _friends[index];
                          final int userId = (user['id'] as num).toInt();
                          final bool isConnected =
                              _connectionStatus[userId] ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                // Profile Avatar
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage:
                                      (user['avatarUrl'] != null &&
                                          (user['avatarUrl'] as String)
                                              .isNotEmpty)
                                      ? NetworkImage(
                                          user['avatarUrl'] as String,
                                        )
                                      : null,
                                  child:
                                      (user['avatarUrl'] == null ||
                                          (user['avatarUrl'] as String).isEmpty)
                                      ? Text(
                                          (user['avatarLetter'] ?? 'U')
                                              .toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),

                                // Name and Username
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (user['name'] ?? 'User').toString(),
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
                                        (user['username'] ?? '').toString(),
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
                                    onPressed: () => _toggleConnection(userId),
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

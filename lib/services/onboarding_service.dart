import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding steps in order
enum OnboardingStep {
  signUp,           // 0 - Account created, needs to start profile flow
  profileFlowStart, // 1 - Viewing the overview page
  name,             // 2 - Name page
  birthday,         // 3 - Birthday page
  gender,           // 4 - Gender page
  address,          // 5 - Address page
  photo,            // 6 - Profile photo page
  cover,            // 7 - Cover photo page
  welcome,          // 8 - Completion welcome page
  status,           // 9 - Status selection page
  experience,       // 10 - Professional experience page
  training,         // 11 - Training page
  bio,              // 12 - Bio page
  interests,        // 13 - Interest selection page
  connectFriends,   // 14 - Connect friends page
  completed,        // 15 - Onboarding complete
}

/// Service to track and persist onboarding progress.
/// Uses both local storage (for fast startup) and Firebase (for persistence across devices).
class OnboardingService extends ChangeNotifier {
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  static const String _localKey = 'onboarding_step';
  static const String _firestoreField = 'onboardingStep';

  OnboardingStep _currentStep = OnboardingStep.completed;
  bool _isInitialized = false;
  String? _userId;

  OnboardingStep get currentStep => _currentStep;
  bool get isInitialized => _isInitialized;
  bool get isOnboardingComplete => _currentStep == OnboardingStep.completed;
  bool get needsOnboarding => _currentStep != OnboardingStep.completed;

  /// Initialize the service for a specific user
  Future<void> initialize(String userId) async {
    if (_isInitialized && _userId == userId) return;
    
    _userId = userId;
    debugPrint('🚀 OnboardingService: Initializing for user $userId');

    // First, try to load from local storage (fast)
    await _loadFromLocal();

    // Then sync with Firebase (authoritative source)
    await _syncWithFirebase(userId);

    _isInitialized = true;
    debugPrint('✅ OnboardingService: Initialized at step ${_currentStep.name}');
  }

  /// Load onboarding step from local storage
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stepIndex = prefs.getInt(_localKey);
      if (stepIndex != null && stepIndex >= 0 && stepIndex < OnboardingStep.values.length) {
        _currentStep = OnboardingStep.values[stepIndex];
        debugPrint('📱 OnboardingService: Loaded from local: ${_currentStep.name}');
      }
    } catch (e) {
      debugPrint('⚠️ OnboardingService: Failed to load from local: $e');
    }
  }

  /// Sync with Firebase (authoritative source)
  Future<void> _syncWithFirebase(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final stepIndex = data?[_firestoreField] as int?;
        
        if (stepIndex != null && stepIndex >= 0 && stepIndex < OnboardingStep.values.length) {
          _currentStep = OnboardingStep.values[stepIndex];
          debugPrint('☁️ OnboardingService: Synced from Firebase: ${_currentStep.name}');
        } else {
          // No onboarding step in Firebase - check if profile is complete
          final isComplete = _checkProfileComplete(data);
          if (isComplete) {
            _currentStep = OnboardingStep.completed;
            // Save to Firebase for future
            await _saveToFirebase(userId, OnboardingStep.completed);
          } else {
            // User exists but hasn't completed onboarding - determine step
            _currentStep = _determineStepFromProfile(data);
          }
          debugPrint('☁️ OnboardingService: Determined step: ${_currentStep.name}');
        }
        
        // Update local storage to match Firebase
        await _saveToLocal(_currentStep);
      }
    } catch (e) {
      debugPrint('⚠️ OnboardingService: Failed to sync with Firebase: $e');
      // Keep local value if Firebase fails
    }
  }

  /// Check if profile is complete based on existing data
  bool _checkProfileComplete(Map<String, dynamic>? data) {
    if (data == null) return false;
    
    // Check essential fields
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final dateOfBirth = data['dateOfBirth'] as String? ?? '';
    
    // If these basic fields are filled, consider onboarding complete
    return firstName.isNotEmpty && lastName.isNotEmpty && dateOfBirth.isNotEmpty;
  }

  /// Determine which step user should be on based on their profile data
  OnboardingStep _determineStepFromProfile(Map<String, dynamic>? data) {
    if (data == null) return OnboardingStep.signUp;

    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final dateOfBirth = data['dateOfBirth'] as String? ?? '';
    final gender = data['gender'] as String? ?? '';
    final country = data['country'] as String? ?? '';
    final bio = data['bio'] as String? ?? '';
    final avatarUrl = data['avatarUrl'] as String? ?? '';
    final coverUrl = data['coverUrl'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final experiences = data['professionalExperiences'] as List<dynamic>?;
    final trainings = data['trainings'] as List<dynamic>?;
    final interests = data['interestDomains'] as List<dynamic>?;
    
    // Check each step in order
    if (firstName.isEmpty || lastName.isEmpty || username.isEmpty) {
      return OnboardingStep.name;
    }
    if (dateOfBirth.isEmpty) {
      return OnboardingStep.birthday;
    }
    if (gender.isEmpty) {
      return OnboardingStep.gender;
    }
    if (country.isEmpty) {
      return OnboardingStep.address;
    }
    if (avatarUrl.isEmpty) {
      return OnboardingStep.photo;
    }
    if (coverUrl.isEmpty) {
      return OnboardingStep.cover;
    }
    // Welcome page is just a transition, skip to status
    if (status.isEmpty) {
      return OnboardingStep.status;
    }
    // Experience is optional but we still show the page
    if (experiences == null) {
      return OnboardingStep.experience;
    }
    // Training is optional but we still show the page
    if (trainings == null) {
      return OnboardingStep.training;
    }
    if (bio.isEmpty) {
      return OnboardingStep.bio;
    }
    if (interests == null || interests.isEmpty) {
      return OnboardingStep.interests;
    }

    return OnboardingStep.completed;
  }

  /// Save onboarding step to local storage
  Future<void> _saveToLocal(OnboardingStep step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_localKey, step.index);
    } catch (e) {
      debugPrint('⚠️ OnboardingService: Failed to save to local: $e');
    }
  }

  /// Save onboarding step to Firebase
  Future<void> _saveToFirebase(String userId, OnboardingStep step) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({_firestoreField: step.index});
    } catch (e) {
      debugPrint('⚠️ OnboardingService: Failed to save to Firebase: $e');
    }
  }

  /// Update the current onboarding step
  Future<void> setStep(OnboardingStep step) async {
    if (_currentStep == step) return;
    
    _currentStep = step;
    debugPrint('📝 OnboardingService: Step updated to ${step.name}');

    // Save to both local and Firebase
    await _saveToLocal(step);
    if (_userId != null) {
      await _saveToFirebase(_userId!, step);
    }

    notifyListeners();
  }

  /// Mark a step as completed and move to the next
  Future<void> completeStep(OnboardingStep completedStep) async {
    final nextIndex = completedStep.index + 1;
    if (nextIndex < OnboardingStep.values.length) {
      await setStep(OnboardingStep.values[nextIndex]);
    }
  }

  /// Mark onboarding as fully complete
  Future<void> markComplete() async {
    await setStep(OnboardingStep.completed);
  }

  /// Reset onboarding (for testing or re-onboarding)
  Future<void> reset() async {
    _currentStep = OnboardingStep.signUp;
    _isInitialized = false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localKey);
    } catch (_) {}

    notifyListeners();
  }

  /// Clear local state (for logout)
  void clear() {
    _currentStep = OnboardingStep.completed;
    _isInitialized = false;
    _userId = null;
  }
}

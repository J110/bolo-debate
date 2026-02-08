class AppConstants {
  AppConstants._();

  // API - Configure these for deployment
  // For production, these will be overridden by --dart-define flags during build
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const String baseUrl = '$apiBaseUrl/api';
  static const String wsUrl = apiBaseUrl.replaceFirst('http', 'ws').replaceFirst('https', 'wss') + '/ws';
  
  // LiveKit URL - Set during build
  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'ws://localhost:7880',
  );

  // Room
  static const int roomDurationMinutes = 30;
  static const int maxExtensions = 3;
  static const int extensionMinutes = 5;
  static const int scheduleAdvanceMinutes = 30;

  // Chat
  static const int maxMessageLength = 500;

  // Pagination
  static const int defaultPageSize = 20;

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String regionKey = 'selected_region';

  // Reactions
  static const List<String> reactions = ['👏', '🔥', '💯', '🤔', '👍', '👎', '❤️', '😂'];
}

class AppStrings {
  AppStrings._();

  static const String appName = 'Bolo Debate';
  static const String tagline = 'Voice your opinion';

  // Pledge
  static const String pledgeTitle = 'Community Pledge';
  static const String pledgeContent = '''
By joining this room, I pledge to:

• Be respectful to all participants
• Not bully, harass, or criticize others personally
• Be polite and accept differences of opinion
• Not use abusive, insensitive, or hateful language
• Listen actively and engage constructively

I understand that violating these guidelines may result in removal from the room or being banned from the platform.
''';

  // Errors
  static const String networkError = 'Please check your internet connection';
  static const String genericError = 'Something went wrong. Please try again';
}

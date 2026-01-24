class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signin = '/signin';
  static const String signupOptions = '/signup-options';
  static const String signupEmail = '/signup-email';
  static const String otpVerification = '/otp-verification';
  static const String accountName = '/account-name';
  static const String age = '/age';
  static const String profileSetup = '/profile-setup';
  static const String passwordSetup = '/password-setup';
  static const String welcomeComplete = '/welcome-complete';
  static const String home = '/home';
  static const String messages = '/messages';
  static String chat(String userId) => '/chat/$userId';
}


class RouteNames {
  RouteNames._();

  static const String splash = 'splash';
  static const String login = 'login';
  static const String signup = 'signup';
  static const String home = 'home';
  static const String search = 'search';
  static const String friends = 'friends';
  static const String requests = 'requests';
  static const String userProfile = 'user_profile';

  static const String splashPath = '/splash';
  static const String loginPath = '/login';
  static const String signupPath = '/signup';
  static const String homePath = '/home';
  static const String searchPath = '/home/search';
  static const String friendsPath = '/home/friends';
  static const String requestsPath = '/home/requests';
  static const String userProfilePath = '/u/:username';

  static String userProfilePathFor(String username) => '/u/$username';
}

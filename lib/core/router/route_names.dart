// Planned: Implement route name constants
class RouteNames {
  // Auth routes
  static const String splash = '/';
  static const String getStarted = '/get-started';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  
  // User routes
  static const String home = '/home'; // Map screen
  static const String stalls = '/stalls';
  static const String stallDetail = '/stalls/:id';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String reportStall = '/stalls/:id/report';
  
  // Admin routes
  static const String admin = '/admin';
  static const String adminStalls = '/admin/stalls';
  static const String adminMap = '/admin/map';
  static const String adminAddStall = '/admin/stalls/add';
  static const String adminEditStall = '/admin/stalls/:id/edit';
  static const String adminReports = '/admin/reports';
}

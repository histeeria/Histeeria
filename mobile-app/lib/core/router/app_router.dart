import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/signin_screen.dart';
import '../../features/auth/presentation/screens/signin_confirmation_screen.dart';
import '../../features/auth/presentation/screens/signin_options_screen.dart';
import '../../features/auth/presentation/screens/signin_email_password_screen.dart';
import '../../features/auth/presentation/screens/signin_password_screen.dart';
import '../../features/auth/presentation/screens/signup_options_screen.dart';
import '../../features/auth/presentation/screens/signup_email_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/account_name_screen.dart';
import '../../features/auth/presentation/screens/age_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/password_setup_screen.dart';
import '../../features/auth/presentation/screens/welcome_complete_screen.dart';
import '../../features/auth/presentation/screens/add_account_screen.dart';
import '../../features/feed/presentation/screens/home_screen.dart';
import '../../features/messages/presentation/screens/messages_list_screen.dart';
import '../../features/messages/presentation/screens/chat_screen.dart';
import '../../features/messages/presentation/screens/start_conversation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/search/presentation/screens/functional_search_screen.dart';
import '../../features/feed/presentation/screens/explore_screen.dart';
// import '../../features/jobs/presentation/screens/jobs_screen.dart'; // TODO: Create JobsScreen
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/account_settings_screen.dart';
import '../../features/settings/presentation/screens/personal_info/change_email_screen.dart';
import '../../features/settings/presentation/screens/personal_info/change_phone_screen.dart';
import '../../features/settings/presentation/screens/personal_info/change_gender_screen.dart';
import '../../features/settings/presentation/screens/personal_info/change_birthday_screen.dart';
import '../../features/settings/presentation/screens/personal_info/change_username_screen.dart';
import '../../features/settings/presentation/screens/personal_info/change_password_screen.dart'
    as personal_info;
import '../../features/settings/presentation/screens/account_management/linked_accounts_screen.dart';
import '../../features/settings/presentation/screens/account_management/connected_apps_screen.dart';
import '../../features/settings/presentation/screens/account_management/login_activity_screen.dart'
    as account_management;
import '../../features/settings/presentation/screens/account_management/download_data_screen.dart'
    as account_management_download;
import '../../features/settings/presentation/screens/account_management/memorialization_screen.dart';
import '../../features/settings/presentation/screens/earnings/earnings_overview_screen.dart';
import '../../features/settings/presentation/screens/earnings/monetization_settings_screen.dart';
import '../../features/settings/presentation/screens/earnings/payout_methods_screen.dart';
import '../../features/settings/presentation/screens/earnings/transaction_history_screen.dart';
import '../../features/settings/presentation/screens/earnings/revenue_analytics_screen.dart';
import '../../features/settings/presentation/screens/jobs_projects/job_preferences_screen.dart';
import '../../features/settings/presentation/screens/jobs_projects/my_applications_screen.dart';
import '../../features/settings/presentation/screens/jobs_projects/project_portfolio_screen.dart';
import '../../features/settings/presentation/screens/jobs_projects/company_profile_screen.dart';
import '../../features/settings/presentation/screens/profile/profile_settings_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/change_display_name_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/change_bio_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/change_location_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/change_website_screen.dart';
import '../../features/settings/presentation/screens/profile/about/experience_screen.dart';
import '../../features/settings/presentation/screens/profile/about/education_screen.dart';
import '../../features/settings/presentation/screens/profile/about/skills_screen.dart';
import '../../features/settings/presentation/screens/profile/about/story_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/profile_photo_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/cover_photo_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/tag_selector_screen.dart';
import '../../features/settings/presentation/screens/profile/basic_info/social_links_screen.dart';
import '../../features/settings/presentation/screens/profile/sharing/qr_code_screen.dart';
import '../../features/settings/presentation/screens/profile/coming_soon_screen.dart';
import '../../features/settings/presentation/screens/security/security_settings_screen.dart';
import '../../features/settings/presentation/screens/security/change_password_screen.dart'
    as security;
import '../../features/settings/presentation/screens/security/two_factor_auth_screen.dart';
import '../../features/settings/presentation/screens/security/active_sessions_screen.dart';
import '../../features/settings/presentation/screens/security/login_activity_screen.dart'
    as security_login;
import '../../features/settings/presentation/screens/notifications/notification_settings_screen.dart';
import '../../features/settings/presentation/screens/notifications/do_not_disturb_screen.dart';
import '../../features/settings/presentation/screens/notifications/advanced_notifications_screen.dart';
import '../../features/settings/presentation/screens/messages/message_settings_screen.dart';
import '../../features/settings/presentation/screens/messages/auto_download_screen.dart';
import '../../features/settings/presentation/screens/messages/storage_usage_screen.dart';
import '../../features/settings/presentation/screens/messages/chat_backup_screen.dart';
import '../../features/settings/presentation/screens/privacy/data_privacy_screen.dart';
import '../../features/settings/presentation/screens/privacy/download_data_screen.dart'
    as privacy_download;
import '../../features/settings/presentation/screens/privacy/permissions_screen.dart';
import '../../features/settings/presentation/screens/privacy/activity_log_screen.dart';
import '../../features/create/presentation/screens/create_post_screen.dart';
import '../../features/create/presentation/screens/create_poll_screen.dart';
import '../../features/create/presentation/screens/create_article_screen.dart';
import '../../features/create/presentation/screens/create_reel_screen.dart';
import '../../features/create/presentation/screens/create_story_screen.dart';
import '../../features/statuses/presentation/screens/status_viewer_screen.dart';
import '../../features/articles/presentation/screens/article_viewer_screen.dart';
import '../../features/posts/data/models/article.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_story_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_skill_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_certification_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_language_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_volunteering_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_publication_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_interest_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_achievement_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_experience_screen.dart';
import '../../features/profile/presentation/screens/add_edit/add_edit_education_screen.dart';
import '../../features/posts/presentation/screens/post_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../features/profile/data/providers/profile_provider.dart';
import '../../features/auth/data/providers/auth_provider.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found: ${state.uri}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(path: '/signin', builder: (context, state) => const SignInScreen()),
    GoRoute(
      path: '/signin-options',
      builder: (context, state) => const SignInOptionsScreen(),
    ),
    GoRoute(
      path: '/signin-confirmation',
      builder: (context, state) => const SignInConfirmationScreen(),
    ),
    GoRoute(
      path: '/signin-email-password',
      builder: (context, state) => const SignInEmailPasswordScreen(),
    ),
    GoRoute(
      path: '/signin-password',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return SignInPasswordScreen(email: email);
      },
    ),
    GoRoute(
      path: '/signup-options',
      builder: (context, state) => const SignUpOptionsScreen(),
    ),
    GoRoute(
      path: '/signup-email',
      builder: (context, state) => const SignUpEmailScreen(),
    ),
    GoRoute(
      path: '/otp-verification',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return OTPVerificationScreen(email: email);
      },
    ),
    GoRoute(
      path: '/account-name',
      builder: (context, state) => const AccountNameScreen(),
    ),
    GoRoute(path: '/age', builder: (context, state) => const AgeScreen()),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/password-setup',
      builder: (context, state) => const PasswordSetupScreen(),
    ),
    GoRoute(
      path: '/welcome-complete',
      builder: (context, state) => const WelcomeCompleteScreen(),
    ),
    GoRoute(
      path: '/add-account',
      builder: (context, state) => const AddAccountScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/explore',
      builder: (context, state) {
        final filter = state.uri.queryParameters['filter'];
        return ExploreScreen(filter: filter);
      },
    ),
    // TODO: Uncomment when JobsScreen is created
    // GoRoute(
    //   path: '/jobs',
    //   pageBuilder: (context, state) => CustomTransitionPage<void>(
    //     key: state.pageKey,
    //     child: const JobsScreen(),
    //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
    //       return FadeTransition(opacity: animation, child: child);
    //     },
    //     transitionDuration: const Duration(milliseconds: 200),
    //   ),
    // ),
    GoRoute(
      path: '/messages',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const MessagesListScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide in from right with smooth easing
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;

          // Smooth ease-in-out curve for natural feel
          var curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return SlideTransition(
            position: Tween(begin: begin, end: end).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
      ),
    ),
    GoRoute(
      path: '/messages/new',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const StartConversationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          var curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween(begin: begin, end: end).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
      ),
    ),
    GoRoute(
      path: '/chat/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: ChatScreen(
            userId: userId,
            userName: extra['userName'] as String? ?? 'User',
            userUsername: extra['userUsername'] as String? ?? '@user',
            isOnline: extra['isOnline'] as bool? ?? false,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide in from right with smooth easing
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;

            var curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween(begin: begin, end: end).animate(curvedAnimation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 350),
        );
      },
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/edit-profile',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const EditProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    // Story
    GoRoute(
      path: '/edit-profile/story',
      pageBuilder: (context, state) {
        // Get current user's story from AuthProvider
        final authProvider = Provider.of<AuthProvider>(
          context,
          listen: false,
        );
        final currentStory = authProvider.currentUser?.story;
        
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditStoryScreen(initialStory: currentStory),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                  .animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Experience
    GoRoute(
      path: '/edit-profile/experience/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditExperienceScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/experience/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final exp = profileProvider.experiences.firstWhere(
          (e) => e.id == id,
          orElse: () => throw Exception('Experience not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditExperienceScreen(experience: exp),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Education
    GoRoute(
      path: '/edit-profile/education/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditEducationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/education/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final edu = profileProvider.education.firstWhere(
          (e) => e.id == id,
          orElse: () => throw Exception('Education not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditEducationScreen(education: edu),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Skills
    GoRoute(
      path: '/edit-profile/skills/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditSkillScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/skills/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final skill = profileProvider.skills.firstWhere(
          (s) => s.id == id,
          orElse: () => throw Exception('Skill not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditSkillScreen(skill: skill),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Certifications
    GoRoute(
      path: '/edit-profile/certifications/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditCertificationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/certifications/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final cert = profileProvider.certifications.firstWhere(
          (c) => c.id == id,
          orElse: () => throw Exception('Certification not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditCertificationScreen(certification: cert),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Languages
    GoRoute(
      path: '/edit-profile/languages/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditLanguageScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/languages/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final lang = profileProvider.languages.firstWhere(
          (l) => l.id == id,
          orElse: () => throw Exception('Language not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditLanguageScreen(language: lang),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Volunteering
    GoRoute(
      path: '/edit-profile/volunteering/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditVolunteeringScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/volunteering/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final vol = profileProvider.volunteering.firstWhere(
          (v) => v.id == id,
          orElse: () => throw Exception('Volunteering not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditVolunteeringScreen(volunteering: vol),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Publications
    GoRoute(
      path: '/edit-profile/publications/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditPublicationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/publications/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final pub = profileProvider.publications.firstWhere(
          (p) => p.id == id,
          orElse: () => throw Exception('Publication not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditPublicationScreen(publication: pub),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Interests
    GoRoute(
      path: '/edit-profile/interests/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditInterestScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/interests/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final interest = profileProvider.interests.firstWhere(
          (i) => i.id == id,
          orElse: () => throw Exception('Interest not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditInterestScreen(interest: interest),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    // Achievements
    GoRoute(
      path: '/edit-profile/achievements/add',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AddEditAchievementScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/edit-profile/achievements/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final profileProvider = Provider.of<ProfileProvider>(
          context,
          listen: false,
        );
        final achievement = profileProvider.achievements.firstWhere(
          (a) => a.id == id,
          orElse: () => throw Exception('Achievement not found'),
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: AddEditAchievementScreen(achievement: achievement),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const NotificationsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const FunctionalSearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Post Detail Page
    GoRoute(
      path: '/post/:id',
      pageBuilder: (context, state) {
        final postId = state.pathParameters['id'] ?? '';
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: PostDetailScreen(postId: postId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
      },
    ),
    // Profile by Username
    GoRoute(
      path: '/profile/:username',
      pageBuilder: (context, state) {
        final username = state.pathParameters['username'] ?? '';
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: ProfileScreen(username: username), // Pass username
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AccountSettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/email',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeEmailScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/phone',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangePhoneScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/gender',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeGenderScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/birthday',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeBirthdayScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/username',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeUsernameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/password',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const personal_info.ChangePasswordScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/linked-accounts',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const LinkedAccountsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/connected-apps',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ConnectedAppsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/login-activity',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const account_management.LoginActivityScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/download-data',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const account_management_download.DownloadDataScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/memorialization',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const MemorializationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/earnings-overview',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const EarningsOverviewScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/monetization',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const MonetizationSettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/payout-methods',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const PayoutMethodsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/transactions',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const TransactionHistoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/revenue-analytics',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const RevenueAnalyticsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/job-preferences',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const JobPreferencesScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/my-applications',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const MyApplicationsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/project-portfolio',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ProjectPortfolioScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/account/company-profile',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CompanyProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ProfileSettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Profile Basic Info Routes
    GoRoute(
      path: '/settings/profile/display-name',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeDisplayNameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/bio',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeBioScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/location',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeLocationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/website',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChangeWebsiteScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Profile About Routes
    GoRoute(
      path: '/settings/profile/experience',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ExperienceScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Fully Implemented Routes
    GoRoute(
      path: '/settings/profile/photo',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ProfilePhotoScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/cover-photo',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CoverPhotoScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/tag',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const TagSelectorScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/social-links',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const SocialLinksScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/story',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const StoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/education',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const EducationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/skills',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const SkillsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/certifications',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Certifications',
          description: 'Add your professional certifications',
          icon: Icons.verified_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/languages',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Languages',
          description: 'Languages you speak',
          icon: Icons.translate_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/volunteering',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Volunteering',
          description: 'Add your volunteer experience',
          icon: Icons.volunteer_activism_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/publications',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Publications',
          description: 'Add your published works',
          icon: Icons.article_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/interests',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Interests',
          description: 'What you\'re interested in',
          icon: Icons.favorite_outline,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/achievements',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Achievements',
          description: 'Add your achievements and awards',
          icon: Icons.emoji_events_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/more-sections',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'More Sections',
          description: 'Additional profile sections',
          icon: Icons.more_horiz,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/visibility',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Profile Visibility',
          description: 'Control who can see your profile',
          icon: Icons.visibility_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/online-status',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Online Status',
          description: 'Show when you\'re active',
          icon: Icons.circle,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/last-seen',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Last Seen',
          description: 'Display last active time',
          icon: Icons.schedule_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/search-indexing',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Search Engine Indexing',
          description: 'Allow search engines to find you',
          icon: Icons.search,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/verification',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Verification Badge',
          description: 'Request profile verification',
          icon: Icons.verified_user_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/professional-title',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Professional Title',
          description: 'Your job title or role',
          icon: Icons.business_center_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/industry',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Industry',
          description: 'Your field of work',
          icon: Icons.domain_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/manage-sections',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Manage Sections',
          description: 'Show/hide profile sections',
          icon: Icons.grid_view_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/featured-content',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Featured Content',
          description: 'Pin posts or projects to your profile',
          icon: Icons.push_pin_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/highlights',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Highlights',
          description: 'Organize your story highlights',
          icon: Icons.highlight_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/theme',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Profile Theme',
          description: 'Customize your profile colors',
          icon: Icons.palette_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/layout',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Layout Style',
          description: 'Choose grid or list view',
          icon: Icons.view_module_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/qr-code',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const QRCodeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/share',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Share Profile',
          description: 'Share your profile link',
          icon: Icons.share_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/custom-url',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Profile URL',
          description: 'Customize your profile URL',
          icon: Icons.link,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/analytics',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Profile Analytics',
          description: 'View profile visits and insights',
          icon: Icons.analytics_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/archive',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Profile Archive',
          description: 'Hide old posts from your profile',
          icon: Icons.archive_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/download-data',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Download Profile Data',
          description: 'Export your profile information',
          icon: Icons.download_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/profile/deactivate',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Deactivate Profile',
          description: 'Temporarily hide your profile',
          icon: Icons.visibility_off_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Security Settings Routes
    GoRoute(
      path: '/settings/security',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const SecuritySettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/change-password',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const security.ChangePasswordScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/two-factor',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const TwoFactorAuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/active-sessions',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ActiveSessionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/login-activity',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const security_login.LoginActivityScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Security Coming Soon Routes
    GoRoute(
      path: '/settings/security/checkup',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Security Checkup',
          description: 'Review and improve your security settings',
          icon: Icons.security,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/auth-method',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Authentication Method',
          description: 'Choose your 2FA method',
          icon: Icons.smartphone_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/backup-codes',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Backup Codes',
          description: 'Generate recovery codes for 2FA',
          icon: Icons.backup_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/trusted-devices',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Trusted Devices',
          description: 'Manage devices that don\'t require 2FA',
          icon: Icons.devices_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/login-alerts',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Login Alerts',
          description: 'Get notified of new logins',
          icon: Icons.notification_important_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/security-notifications',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Security Notifications',
          description: 'Manage security alerts',
          icon: Icons.security_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/recovery-email',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Recovery Email',
          description: 'Update your recovery email address',
          icon: Icons.email_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/recovery-phone',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Recovery Phone',
          description: 'Update your recovery phone number',
          icon: Icons.phone_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/recovery-codes',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Recovery Codes',
          description: 'Download backup recovery codes',
          icon: Icons.download_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/biometric',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Biometric Authentication',
          description: 'Set up Face ID or fingerprint',
          icon: Icons.fingerprint,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/app-lock',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'App Lock',
          description: 'Require authentication to open app',
          icon: Icons.lock_clock_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/connected-apps',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Connected Apps',
          description: 'Manage third-party app access',
          icon: Icons.apps_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/security-logs',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Security Logs',
          description: 'View detailed security events',
          icon: Icons.description_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/security/report-issue',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Report Security Issue',
          description: 'Contact our security team',
          icon: Icons.report_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Notification Settings Routes
    GoRoute(
      path: '/settings/notifications',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const NotificationSettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/notifications/do-not-disturb',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const DoNotDisturbScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/notifications/advanced',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AdvancedNotificationsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/notifications/messages',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Message Notifications',
          description: 'Customize message notification settings',
          icon: Icons.message_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Message Settings Routes
    GoRoute(
      path: '/settings/messages',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const MessageSettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/messages/auto-download',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const AutoDownloadScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/messages/storage',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const StorageUsageScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/messages/backup',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ChatBackupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Message Settings Coming Soon Routes
    GoRoute(
      path: '/settings/messages/last-seen',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Last Seen',
          description: 'Control who can see your last active time',
          icon: Icons.access_time,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/messages/who-can-message',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Who Can Message You',
          description: 'Control who can send you messages',
          icon: Icons.person_add_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/messages/wallpaper',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Chat Wallpaper',
          description: 'Customize your chat background',
          icon: Icons.wallpaper_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Data & Privacy Settings Routes
    GoRoute(
      path: '/settings/privacy',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const DataPrivacyScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/download-data',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const privacy_download.DownloadDataScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/permissions',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const PermissionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/activity-log',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ActivityLogScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Privacy Coming Soon Routes
    GoRoute(
      path: '/settings/privacy/checkup',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Privacy Checkup',
          description: 'Review and improve your privacy settings',
          icon: Icons.privacy_tip,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/what-we-collect',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'What We Collect',
          description: 'See what data we collect',
          icon: Icons.dataset_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/how-we-use-data',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'How We Use Your Data',
          description: 'Learn about data usage',
          icon: Icons.insights_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/data-sharing',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Data Sharing',
          description: 'Third-party data sharing',
          icon: Icons.share_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/profile-privacy',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Profile Privacy',
          description: 'Control profile visibility',
          icon: Icons.visibility_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/post-privacy',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Post Privacy',
          description: 'Default post visibility',
          icon: Icons.post_add_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/comment-privacy',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Comment Privacy',
          description: 'Who can comment on your posts',
          icon: Icons.comment_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/delete-data',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Delete Specific Data',
          description: 'Remove selected data',
          icon: Icons.delete_outline,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/clear-history',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Clear Activity History',
          description: 'Wipe your activity log',
          icon: Icons.clear_all,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/ad-preferences',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Ad Preferences',
          description: 'Manage ad interests',
          icon: Icons.tune,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/off-platform-activity',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Off-Platform Activity',
          description: 'Activity from other websites',
          icon: Icons.link_off,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/location-services',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Location Services',
          description: 'Manage location access',
          icon: Icons.location_on_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/cookies',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Cookie Preferences',
          description: 'Manage cookie settings',
          icon: Icons.cookie_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/auto-delete',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Auto-Delete Activity',
          description: 'Automatically delete old activity',
          icon: Icons.auto_delete_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/content-retention',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Content Retention',
          description: 'Manage old content',
          icon: Icons.archive_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/connected-apps',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Connected Apps',
          description: 'Manage third-party app access',
          icon: Icons.apps_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/api-access',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'API Access',
          description: 'Developer access management',
          icon: Icons.api_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/your-rights',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Your Rights (GDPR)',
          description: 'Data protection rights',
          icon: Icons.shield_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/privacy-policy',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Privacy Policy',
          description: 'Read our privacy policy',
          icon: Icons.description_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/terms',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Terms of Service',
          description: 'Terms and conditions',
          icon: Icons.article_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    GoRoute(
      path: '/settings/privacy/data-request',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComingSoonScreen(
          title: 'Submit Data Request',
          description: 'Exercise your data rights',
          icon: Icons.request_page_outlined,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ),
    // Create Content Routes
    GoRoute(
      path: '/create/post',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CreatePostScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/create/poll',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CreatePollScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/create/article',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CreateArticleScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/create/reel',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CreateReelScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/create/story',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CreateStoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/status/:id',
      builder: (context, state) {
        final statusId = state.pathParameters['id'] ?? '';
        return StatusViewerScreen(statusId: statusId);
      },
    ),
    GoRoute(
      path: '/article/:id',
      builder: (context, state) {
        final articleId = state.pathParameters['id'] ?? '';
        final article = state.extra as Article?;
        return ArticleViewerScreen(
          articleId: articleId,
          article: article,
        );
      },
    ),
  ],
);

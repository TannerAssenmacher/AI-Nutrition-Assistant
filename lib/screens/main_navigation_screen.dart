import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrition_assistant/screens/chat_screen.dart';
import 'package:nutrition_assistant/screens/daily_log_calendar.dart';
import 'package:nutrition_assistant/screens/home_screen.dart';
import 'package:nutrition_assistant/screens/meal_analysis_screen.dart';
import 'package:nutrition_assistant/screens/food_search_screen.dart';
import 'package:nutrition_assistant/db/food.dart';
import 'package:nutrition_assistant/db/user.dart';
import 'package:nutrition_assistant/providers/auth_providers.dart';
import 'package:nutrition_assistant/providers/firestore_providers.dart';
import 'package:nutrition_assistant/widgets/fatsecret_attribution.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import '../theme/app_colors.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = navIndexHome});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  int? _pendingNavTarget;
  late final AnimationController _macroPreviewController;
  HomeMacroSnapshot? _previewFrom;
  HomeMacroSnapshot? _previewTo;
  HomeMacroSnapshot? _lastSnapshot;
  int _lastTodayCount = -1;
  bool _isMacroBaselinePrimed = false;
  bool _deferMacroPreviewUntilHome = false;
  String? _trackedUserId;
  OverlayEntry? _macroPreviewEntry;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Map nav index (1-5) to page index (0-4)
    _pageController = PageController(
      initialPage: _navIndexToPageIndex(_currentIndex),
    );
    _macroPreviewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _bindMacroPreviewControllerListeners();
  }

  @override
  void dispose() {
    _removeMacroPreviewOverlay();
    _macroPreviewController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _refreshMacroPreviewOverlay() {
    _macroPreviewEntry?.markNeedsBuild();
  }

  void _onMacroPreviewStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _removeMacroPreviewOverlay();
    }
  }

  void _bindMacroPreviewControllerListeners() {
    // Clear stale listeners first so hot-reload state cannot reference removed fields.
    _macroPreviewController.removeListener(_refreshMacroPreviewOverlay);
    _macroPreviewController.removeStatusListener(_onMacroPreviewStatusChanged);
    _macroPreviewController.addListener(_refreshMacroPreviewOverlay);
    _macroPreviewController.addStatusListener(_onMacroPreviewStatusChanged);
  }

  void _removeMacroPreviewOverlay() {
    _macroPreviewEntry?.remove();
    _macroPreviewEntry = null;
  }

  void _resetMacroAnimationStateForUser(String? userId) {
    _trackedUserId = userId;
    _isMacroBaselinePrimed = false;
    _deferMacroPreviewUntilHome = false;
    _lastTodayCount = -1;
    _lastSnapshot = null;
    _previewFrom = null;
    _previewTo = null;
    _macroPreviewController.stop();
    _removeMacroPreviewOverlay();
  }

  void _showMacroPreviewOverlay() {
    final overlayState = Overlay.of(context, rootOverlay: true);
    if (_previewFrom == null || _previewTo == null) {
      return;
    }

    final inheritedTheme = Theme.of(context);
    final inheritedTextStyle = DefaultTextStyle.of(context).style;

    _removeMacroPreviewOverlay();
    _macroPreviewEntry = OverlayEntry(
      builder: (overlayContext) {
        if (_previewFrom == null || _previewTo == null) {
          return const SizedBox.shrink();
        }

        final t = _macroPreviewController.value;
        final progressT = ((t - 0.2) / 0.6).clamp(0.0, 1.0);
        final easedT = Curves.easeOutCubic.transform(progressT);
        final animatedSnapshot = _lerpSnapshot(
          _previewFrom!,
          _previewTo!,
          easedT,
        );
        return Positioned.fill(
          child: Theme(
            data: inheritedTheme,
            child: DefaultTextStyle(
              style: inheritedTextStyle.copyWith(
                decoration: TextDecoration.none,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Opacity(
                        opacity: _previewOpacity(t),
                        child: Transform.scale(
                          scale: 0.98 + (0.02 * _previewOpacity(t)),
                          child: HomeMacroSummaryCard(
                            metrics: animatedSnapshot,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlayState.insert(_macroPreviewEntry!);
  }

  HomeMacroSnapshot _snapshot(HomeMacroSnapshot metrics) {
    return HomeMacroSnapshot(
      currentCalories: metrics.currentCalories,
      calorieGoal: metrics.calorieGoal,
      currentProtein: metrics.currentProtein,
      proteinGoal: metrics.proteinGoal,
      currentCarbs: metrics.currentCarbs,
      carbsGoal: metrics.carbsGoal,
      currentFat: metrics.currentFat,
      fatGoal: metrics.fatGoal,
      todayMealsCount: metrics.todayMealsCount,
    );
  }

  HomeMacroSnapshot _lerpSnapshot(
    HomeMacroSnapshot from,
    HomeMacroSnapshot to,
    double t,
  ) {
    double lerp(double a, double b) => a + (b - a) * t;
    return HomeMacroSnapshot(
      currentCalories: lerp(from.currentCalories, to.currentCalories),
      calorieGoal: to.calorieGoal,
      currentProtein: lerp(from.currentProtein, to.currentProtein),
      proteinGoal: to.proteinGoal,
      currentCarbs: lerp(from.currentCarbs, to.currentCarbs),
      carbsGoal: to.carbsGoal,
      currentFat: lerp(from.currentFat, to.currentFat),
      fatGoal: to.fatGoal,
      todayMealsCount: to.todayMealsCount,
    );
  }

  void _maybeAnimateMacroPreview(
    HomeMacroSnapshot snapshot, {
    required bool isDataReady,
  }) {
    if (!isDataReady) {
      return;
    }

    final todayCount = snapshot.todayMealsCount;
    if (!_isMacroBaselinePrimed || _lastTodayCount < 0) {
      _isMacroBaselinePrimed = true;
      _lastTodayCount = todayCount;
      _lastSnapshot = _snapshot(snapshot);
      return;
    }

    if (_deferMacroPreviewUntilHome &&
        _currentIndex == navIndexHome &&
        _previewFrom != null &&
        _previewTo != null &&
        !_macroPreviewController.isAnimating) {
      _bindMacroPreviewControllerListeners();
      _showMacroPreviewOverlay();
      _macroPreviewController.forward(from: 0);
      _deferMacroPreviewUntilHome = false;
    }

    if (todayCount > _lastTodayCount) {
      final from = _lastSnapshot ?? _snapshot(snapshot);
      final to = _snapshot(snapshot);
      _previewFrom = from;
      _previewTo = to;

      if (_currentIndex == navIndexCamera) {
        _deferMacroPreviewUntilHome = true;
      } else {
        _deferMacroPreviewUntilHome = false;
        _bindMacroPreviewControllerListeners();
        _showMacroPreviewOverlay();
        _macroPreviewController.forward(from: 0);
      }
    }

    _lastTodayCount = todayCount;
    _lastSnapshot = _snapshot(snapshot);
  }

  double _previewOpacity(double t) {
    if (t < 0.2) return t / 0.2;
    if (t < 0.8) return 1.0;
    return ((1.0 - t) / 0.2).clamp(0.0, 1.0);
  }

  // Convert nav index (1=chat, 2=history, 3=home, 4=search, 5=camera) to page index (0-4)
  int _navIndexToPageIndex(int navIndex) {
    return navIndex - 1;
  }

  // Convert page index (0-4) to nav index (1-5)
  int _pageIndexToNavIndex(int pageIndex) {
    return pageIndex + 1;
  }

  void _onNavBarTap(int navIndex) {
    _navigateToTab(navIndex, animate: true);
  }

  void _navigateToTab(int navIndex, {bool animate = true}) {
    final pageIndex = _navIndexToPageIndex(navIndex);
    if (_currentIndex == navIndex) return;

    // Keep active-tab state on the intended destination while animating,
    // so intermediate pages do not become active.
    _pendingNavTarget = navIndex;
    setState(() {
      _currentIndex = navIndex;
    });

    if (animate) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(pageIndex);
      _pendingNavTarget = null;
    }
  }

  void _onPageChanged(int pageIndex) {
    final navIndex = _pageIndexToNavIndex(pageIndex);

    // Ignore intermediate pages during an animated tab transition.
    if (_pendingNavTarget != null && navIndex != _pendingNavTarget) {
      return;
    }

    _pendingNavTarget = null;
    setState(() {
      _currentIndex = navIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    if (_trackedUserId != userId) {
      _resetMacroAnimationStateForUser(userId);
    }

    final userProfileAsync = userId == null
        ? const AsyncValue<AppUser?>.data(null)
        : ref.watch(firestoreUserProfileProvider(userId));
    final foodLogAsync = userId == null
        ? const AsyncValue<List<FoodItem>>.data(<FoodItem>[])
        : ref.watch(firestoreFoodLogProvider(userId));

    final profile = userProfileAsync.valueOrNull;
    final foodLog = foodLogAsync.valueOrNull ?? const <FoodItem>[];
    final snapshot = HomeMacroSnapshot.fromData(
      profile: profile,
      foodLog: foodLog,
    );
    final isDataReady =
        userId != null &&
        userProfileAsync.hasValue &&
        foodLogAsync.hasValue &&
        !userProfileAsync.isLoading &&
        !foodLogAsync.isLoading;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAnimateMacroPreview(snapshot, isDataReady: isDataReady);
    });

    return Scaffold(
      resizeToAvoidBottomInset: _currentIndex != navIndexSearch,
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          ChatScreen(isInPageView: true),
          DailyLogCalendarScreen(
            isInPageView: true,
            isActive: _currentIndex == navIndexHistory,
          ),
          HomeScreen(isInPageView: true),
          FoodSearchScreen(isInPageView: true),
          CameraScreen(
            isInPageView: true,
            isActive: _currentIndex == navIndexCamera,
            onNavigateHome: () => _navigateToTab(navIndexHome, animate: false),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentIndex == navIndexCamera)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.only(top: 2),
              child: const FatSecretAttribution(),
            ),
          NavBar(currentIndex: _currentIndex, onTap: _onNavBarTap),
        ],
      ),
    );
  }
}

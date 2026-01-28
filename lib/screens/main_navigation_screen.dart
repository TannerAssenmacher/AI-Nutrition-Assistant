import 'package:flutter/material.dart';
import 'package:nutrition_assistant/screens/chat_screen.dart';
import 'package:nutrition_assistant/screens/daily_log_calendar.dart';
import 'package:nutrition_assistant/screens/home_screen.dart';
import 'package:nutrition_assistant/screens/meal_analysis_screen.dart';
import 'package:nutrition_assistant/screens/profile_screen.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = navIndexHome,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Map nav index (1-5) to page index (0-4)
    _pageController =
        PageController(initialPage: _navIndexToPageIndex(_currentIndex));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Convert nav index (1=chat, 2=history, 3=home, 4=camera, 5=profile) to page index (0-4)
  int _navIndexToPageIndex(int navIndex) {
    return navIndex - 1;
  }

  // Convert page index (0-4) to nav index (1-5)
  int _pageIndexToNavIndex(int pageIndex) {
    return pageIndex + 1;
  }

  void _onNavBarTap(int navIndex) {
    final pageIndex = _navIndexToPageIndex(navIndex);
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int pageIndex) {
    setState(() {
      _currentIndex = _pageIndexToNavIndex(pageIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE2),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          ChatScreen(isInPageView: true),
          DailyLogCalendarScreen(isInPageView: true),
          HomeScreen(isInPageView: true),
          ProfilePage(isInPageView: true),
          CameraScreen(isInPageView: true),
        ],
      ),
      bottomNavigationBar: NavBar(
        currentIndex: _currentIndex,
        onTap: _onNavBarTap,
      ),
    );
  }
}

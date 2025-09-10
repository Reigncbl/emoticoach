import 'package:flutter/material.dart';

class LearningNavigationController extends ChangeNotifier {
  static final LearningNavigationController _instance =
      LearningNavigationController._internal();
  factory LearningNavigationController() => _instance;
  LearningNavigationController._internal();

  int _currentTabIndex = 0;

  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void goToScenarios() {
    setTabIndex(0);
  }

  void goToReadings() {
    setTabIndex(1);
  }
}

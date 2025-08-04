import 'package:flutter/material.dart';

class LearningController extends ChangeNotifier {
  int _currentTabIndex = 0; // Default to scenario tab (index 0)
  
  int get currentTabIndex => _currentTabIndex;
  
  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }
  
  void switchToScenarioTab() {
    setTabIndex(0);
  }
  
  void switchToReadingTab() {
    setTabIndex(1);
  }
  
  bool get isScenarioTab => _currentTabIndex == 0;
  bool get isReadingTab => _currentTabIndex == 1;
}
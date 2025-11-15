import 'package:flutter/material.dart';
import 'user_info_handler.dart';

mixin UserDataMixin<T extends StatefulWidget> on State<T> {
  String userName = 'User';
  bool isLoading = true;

  /// Loads user data and updates the state
  Future<void> loadUserData() async {
    try {
      final displayName = await UserInfoHandler.getDisplayName();
      if (mounted) {
        setState(() {
          userName = displayName;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Refreshes user data (useful for pull-to-refresh scenarios)
  Future<void> refreshUserData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }
    await loadUserData();
  }

  /// Returns a loading-aware display name
  String get displayName => isLoading ? 'Loading...' : userName;

  /// Returns a greeting with the user's name
  String get userGreeting => UserInfoHandler.getGreeting(userName);
}

// Example of how to use UserDataMixin in any screen

import 'package:flutter/material.dart';
import '../utils/user_data_mixin.dart';

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> with UserDataMixin {
  @override
  void initState() {
    super.initState();
    // Simply call loadUserData() to automatically load and manage user data
    loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Example Screen')),
      body: RefreshIndicator(
        // Use refreshUserData() for pull-to-refresh functionality
        onRefresh: refreshUserData,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Use displayName - it automatically shows "Loading..." when loading
            Text(
              'Welcome, $displayName!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Use userGreeting for time-based greetings
            Text(userGreeting, style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),

            // You can also access individual properties
            if (isLoading)
              CircularProgressIndicator()
            else
              Text('User loaded: $userName'),

            SizedBox(height: 16),
            ElevatedButton(
              onPressed: refreshUserData,
              child: Text('Refresh User Data'),
            ),
          ],
        ),
      ),
    );
  }
}

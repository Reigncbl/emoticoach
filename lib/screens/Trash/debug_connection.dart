import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DebugConnectionScreen extends StatefulWidget {
  const DebugConnectionScreen({Key? key}) : super(key: key);

  @override
  State<DebugConnectionScreen> createState() => _DebugConnectionScreenState();
}

class _DebugConnectionScreenState extends State<DebugConnectionScreen> {
  final APIService _apiService = APIService();
  String _status = 'Not tested';
  bool _isLoading = false;

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing connection...';
    });

    try {
      final success = await _apiService.testConnection();
      setState(() {
        _status = success ? 'Connection successful!' : 'Connection failed!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testStartEndpoint() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing /start endpoint...';
    });

    try {
      final response = await _apiService.startConversation();
      setState(() {
        _status =
            'Start endpoint: ${response.success ? 'Success' : 'Failed'}\n'
            'Character: ${response.characterName}\n'
            'Message: ${response.firstMessage}';
      });
    } catch (e) {
      setState(() {
        _status = 'Start endpoint error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Connection')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Backend URL: ${_apiService.baseUrl}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: const Text('Test Basic Connection'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _isLoading ? null : _testStartEndpoint,
              child: const Text('Test /start Endpoint'),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),

            const SizedBox(height: 20),

            const Text(
              'Troubleshooting Tips:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Make sure your backend server is running on port 8000\n'
              '2. For Android emulator, use 10.0.2.2:8000\n'
              '3. For web/desktop, use localhost:8000\n'
              '4. For physical device, use your computer\'s IP address\n'
              '5. Check that CORS is enabled in your backend',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

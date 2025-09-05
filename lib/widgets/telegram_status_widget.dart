import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';

class TelegramStatusWidget extends StatefulWidget {
  final String? userMobileNumber;
  final VoidCallback? onConnectPressed;
  final VoidCallback? onDisconnectPressed;

  const TelegramStatusWidget({
    super.key,
    this.userMobileNumber,
    this.onConnectPressed,
    this.onDisconnectPressed,
  });

  @override
  State<TelegramStatusWidget> createState() => _TelegramStatusWidgetState();
}

class _TelegramStatusWidgetState extends State<TelegramStatusWidget> {
  final APIService _apiService = APIService();

  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _telegramUser;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkTelegramStatus();
  }

  Future<void> _checkTelegramStatus() async {
    if (widget.userMobileNumber == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User mobile number not available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getTelegramStatus(
        widget.userMobileNumber!,
      );

      setState(() {
        _isAuthenticated = result['authenticated'] ?? false;
        _telegramUser = result['user'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to check Telegram status';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAuthenticated
              ? Colors.green.withOpacity(0.3)
              : kBrightBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isAuthenticated
                      ? Colors.green.withOpacity(0.1)
                      : kBrightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.telegram,
                  color: _isAuthenticated ? Colors.green : kBrightBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telegram Integration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_isLoading)
                      Text(
                        'Checking status...',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      )
                    else if (_isAuthenticated && _telegramUser != null)
                      Text(
                        'Connected as $_telegramUser',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Text(
                        'Not connected',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              // Status Indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isLoading
                      ? Colors.grey
                      : (_isAuthenticated ? Colors.green : Colors.grey[400]),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status Description
          if (_isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Checking Telegram connection...',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            )
          else if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else if (_isAuthenticated)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Telegram account verified',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Access to real Telegram contacts\n• Message analysis from actual conversations\n• Enhanced overlay features',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect your Telegram account to unlock:',
                  style: TextStyle(
                    fontSize: 14,
                    color: kBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Real contact integration\n• Actual message analysis\n• Smart conversation insights\n• Enhanced overlay features',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Action Button
          if (!_isLoading)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAuthenticated
                    ? widget.onDisconnectPressed
                    : widget.onConnectPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAuthenticated
                      ? Colors.grey[400]
                      : kBrightBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isAuthenticated ? Icons.link_off : Icons.link,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAuthenticated ? 'Disconnect' : 'Connect Telegram',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Refresh Button
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _checkTelegramStatus,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Retry', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

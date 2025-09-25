import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/telegram_service.dart';
import '../utils/colors.dart';
import '../utils/auth_utils.dart';

class TelegramVerificationWidget extends StatefulWidget {
  final String? userMobileNumber; // The user's app mobile number
  final VoidCallback? onVerificationSuccess;
  final VoidCallback? onCancel;

  const TelegramVerificationWidget({
    super.key,
    this.userMobileNumber,
    this.onVerificationSuccess,
    this.onCancel,
  });

  @override
  State<TelegramVerificationWidget> createState() =>
      _TelegramVerificationWidgetState();
}

class _TelegramVerificationWidgetState
    extends State<TelegramVerificationWidget> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _passwordRequired = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with user's mobile number if available
    if (widget.userMobileNumber != null) {
      _phoneController.text = widget.userMobileNumber!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _telegramService.dispose();
    super.dispose();
  }

  Future<void> _sendTelegramCode() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final phoneNumber = _phoneController.text.trim();

      // Get userId using safe method that prioritizes session data
      String? userId = await AuthUtils.getSafeUserId();

      if (userId == null || userId.isEmpty) {
        setState(() {
          _errorMessage = 'User not authenticated. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final result = await _telegramService.requestCode(
        userId: userId,
        phoneNumber: phoneNumber,
      );

      if (result['success'] == true) {
        setState(() {
          _codeSent = true;
          _successMessage = 'Verification code sent to your Telegram!';
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to send code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyTelegramCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Get userId using safe method that prioritizes session data
      String? userId = await AuthUtils.getSafeUserId();

      if (userId == null || userId.isEmpty) {
        setState(() {
          _errorMessage = 'User not authenticated. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final result = await _telegramService.verifyCode(
        userId: userId,
        code: _codeController.text.trim(),
      );

      if (result['success'] == true) {
        setState(() {
          _successMessage = 'Telegram connected successfully!';
        });

        // Call success callback after a brief delay
        await Future.delayed(const Duration(seconds: 1));
        if (widget.onVerificationSuccess != null) {
          widget.onVerificationSuccess!();
        }
      } else if (result['password_required'] == true) {
        setState(() {
          _passwordRequired = true;
          _errorMessage =
              'Two-factor authentication required. Please enter your password.';
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to verify code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetFlow() {
    setState(() {
      _codeSent = false;
      _passwordRequired = false;
      _errorMessage = null;
      _successMessage = null;
      _codeController.clear();
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kBrightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.telegram, color: kBrightBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Telegram',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlack,
                      ),
                    ),
                    Text(
                      'Verify your Telegram account for enhanced features',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (widget.onCancel != null)
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Phone Number Input (always visible)
          TextField(
            controller: _phoneController,
            enabled: !_codeSent,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter your Telegram phone number',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _codeSent ? Colors.grey[100] : Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          // Code Input (visible after code is sent)
          if (_codeSent) ...[
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Verification Code',
                hintText: 'Enter the code from Telegram',
                prefixIcon: const Icon(Icons.verified_user),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Password Input (visible if 2FA is required)
          if (_passwordRequired) ...[
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Two-Factor Password',
                hintText: 'Enter your Telegram 2FA password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Error Message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[600], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Success Message
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green[600], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          Row(
            children: [
              if (_codeSent) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _resetFlow,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_codeSent ? _verifyTelegramCode : _sendTelegramCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrightBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _codeSent ? 'Verify Code' : 'Send Code',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Helper Text
          const SizedBox(height: 16),
          Text(
            _codeSent
                ? 'Check your Telegram app for the verification code'
                : 'We\'ll send a verification code to your Telegram account',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

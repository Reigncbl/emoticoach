class User {
  final int userId;
  final String? firstName;
  final String? lastName;
  final String? mobileNumber;
  final DateTime? createdAt;

  User({
    required this.userId,
    this.firstName,
    this.lastName,
    this.mobileNumber,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['UserId'] ?? 0,
      firstName: json['FirstName'],
      lastName: json['LastName'],
      mobileNumber: json['MobileNumber'],
      createdAt: json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'UserId': userId,
      'FirstName': firstName,
      'LastName': lastName,
      'MobileNumber': mobileNumber,
      'CreatedAt': createdAt?.toIso8601String(),
    };
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return 'Unknown User';
  }

  @override
  String toString() {
    return 'User(userId: $userId, firstName: $firstName, lastName: $lastName, mobileNumber: $mobileNumber)';
  }
}

// Request models for authentication
class LoginRequest {
  final String mobileNumber;

  LoginRequest({required this.mobileNumber});

  Map<String, dynamic> toJson() {
    return {'mobile_number': mobileNumber};
  }
}

class OTPVerificationRequest {
  final String mobileNumber;
  final String otpCode;
  final String firstName;
  final String lastName;

  OTPVerificationRequest({
    required this.mobileNumber,
    required this.otpCode,
    required this.firstName,
    required this.lastName,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobile_number': mobileNumber,
      'otp_code': otpCode,
      'first_name': firstName,
      'last_name': lastName,
    };
  }
}

class SMSRequest {
  final String mobileNumber;

  SMSRequest({required this.mobileNumber});

  Map<String, dynamic> toJson() {
    return {'mobile_number': mobileNumber};
  }
}

// Response models
class AuthResponse {
  final bool success;
  final String? message;
  final User? user;
  final String? error;

  AuthResponse({required this.success, this.message, this.user, this.error});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: true, // If we get a response, assume success unless error
      user: User.fromJson(json),
    );
  }

  factory AuthResponse.error(String error) {
    return AuthResponse(success: false, error: error);
  }
}

class SMSResponse {
  final bool success;
  final String message;
  final String? mobileNumber;
  final String? otp; // Only for testing
  final String? error;

  SMSResponse({
    required this.success,
    required this.message,
    this.mobileNumber,
    this.otp,
    this.error,
  });

  factory SMSResponse.fromJson(Map<String, dynamic> json) {
    return SMSResponse(
      success: true,
      message: json['message'] ?? 'SMS sent successfully',
      mobileNumber: json['mobile_number'],
      otp: json['otp'], // For testing only
    );
  }

  factory SMSResponse.error(String error) {
    return SMSResponse(
      success: false,
      message: 'Failed to send SMS',
      error: error,
    );
  }
}

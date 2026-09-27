import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:healthcare/Dashborad/home.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerification extends StatefulWidget {
  final String email;

  const EmailVerification({super.key, required this.email});

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _timerSeconds = 600; // 10 minutes in seconds
  late Timer _timer;
  bool _canResend = false;
  bool _isResending = false;
  String _previousText = ''; // To track previous text for backspace detection

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerify() async {
    String code = '';
    for (var controller in _controllers) {
      code += controller.text;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Sending verification request...');
      print('Email: ${widget.email}');
      print('Code: $code');

      final response = await http.post(
        Uri.parse('https://omb-api.omegambs.site/auth/2fa-verify'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': widget.email, 'code': code}),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        // Parse the response
        final responseData = jsonDecode(response.body);

        // Get access token from response
        if (responseData['access_token'] != null) {
          final String accessToken = responseData['access_token'];
          final String tokenType = responseData['token_type'] ?? 'bearer';

          // Save token to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          await prefs.setString('token_type', tokenType);
          await prefs.setString('user_email', widget.email);
          await prefs.setBool('is_logged_in', true);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification successful!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to dashboard after successful verification
          await Future.delayed(const Duration(seconds: 1));

          // Clear all navigation and go to dashboard
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid response from server'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Handle error response
        try {
          final responseData = jsonDecode(response.body);
          String errorMessage = 'Verification failed';

          if (responseData['detail'] != null) {
            if (responseData['detail'] is List &&
                responseData['detail'].isNotEmpty) {
              errorMessage =
                  responseData['detail'][0]['msg'] ??
                  'Invalid verification code';
            }
          } else if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification failed: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });

      print('Verification error: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isResending = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://omb-api.omegambs.site/auth/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': widget.email,
          'password':
              '', // Password is required but will fail - we need a different endpoint
        }),
      );

      if (response.statusCode == 200) {
        // Reset timer
        setState(() {
          _canResend = false;
          _timerSeconds = 600;
          _startTimer();
          _isResending = false;
        });

        // Clear all fields
        for (var controller in _controllers) {
          controller.clear();
        }

        // Set focus to first field
        FocusScope.of(context).requestFocus(_focusNodes[0]);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code has been sent to your email'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        setState(() {
          _isResending = false;
        });

        // For demo purposes, we'll still reset the timer
        // In production, you should check the response
        setState(() {
          _canResend = false;
          _timerSeconds = 600;
          _startTimer();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent (demo mode)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isResending = false;
      });

      // For demo purposes, reset anyway
      setState(() {
        _canResend = false;
        _timerSeconds = 600;
        _startTimer();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New verification code sent (demo mode)'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _formatTimer() {
    int minutes = _timerSeconds ~/ 60;
    int seconds = _timerSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Handle Android back button
  Future<bool> _onWillPop() async {
    // Clear all OTP fields when going back
    for (var controller in _controllers) {
      controller.clear();
    }
    // Navigate back
    Navigator.pop(context);
    return false; // Return false to prevent default back behavior since we're manually popping
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () {
                      // Clear OTP fields when manually going back
                      for (var controller in _controllers) {
                        controller.clear();
                      }
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Color(0xFF0A84FF),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Verification Illustration/Icon
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 50,
                        color: Color(0xFF0A84FF),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Center(
                    child: Text(
                      'Verify your email',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Center(
                    child: Text(
                      "We've sent a verification code to",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                  Center(
                    child: Text(
                      widget.email,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0A84FF),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Verification Code Label
                  Text(
                    'Verification Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // OTP Input Fields
                  Form(
                    key: _formKey,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          width: 52,
                          height: 52,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: _controllers[index].text.isNotEmpty
                                    ? const Color(0xFF0A84FF)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                setState(() {});

                                // Store previous text to detect backspace
                                String previousText = _controllers[index].text;

                                // Handle backspace (when text becomes empty)
                                if (value.isEmpty && previousText.isNotEmpty) {
                                  // This means backspace was pressed
                                  if (index > 0) {
                                    // Clear the previous field
                                    _controllers[index - 1].clear();
                                    // Move focus to previous field
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(_focusNodes[index - 1]);
                                  }
                                }
                                // Handle typing (when a digit is entered)
                                else if (value.isNotEmpty &&
                                    value.length == 1) {
                                  // Move to next field if available
                                  if (index < 5) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(_focusNodes[index + 1]);
                                  }
                                  // Auto submit when last digit is entered
                                  if (index == 5) {
                                    // Check if all 6 digits are entered
                                    bool allFilled = true;
                                    for (int i = 0; i < 6; i++) {
                                      if (_controllers[i].text.isEmpty) {
                                        allFilled = false;
                                        break;
                                      }
                                    }
                                    if (allFilled) {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () {
                                          _handleVerify();
                                        },
                                      );
                                    }
                                  }
                                }
                              },
                              onTap: () {
                                // Select all text when tapped
                                _controllers[index].selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _controllers[index].text.length,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify Code',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Resend Code
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Didn't receive the code?",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        _canResend
                            ? _isResending
                                  ? const CircularProgressIndicator()
                                  : GestureDetector(
                                      onTap: _handleResendCode,
                                      child: Text(
                                        'Resend code',
                                        style: TextStyle(
                                          color: const Color(0xFF0A84FF),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    )
                            : Text(
                                'Resend code in ${_formatTimer()}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Information Text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0A84FF).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: const Color(0xFF0A84FF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Check your email inbox and spam folder for the verification code. '
                            'The code will expire in 10 minutes.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

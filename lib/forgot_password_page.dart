import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

// Supabase client instance
final _supabase = Supabase.instance.client;

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _email;
  bool _isCodeSent = false;
  bool _isCodeVerified = false;
  bool _isLoading = false;

  Future<void> _sendVerificationCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final response = await _supabase
          .from('mechanics')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        final random = Random();
        final code = (100000 + random.nextInt(900000)).toString();

        await _supabase.from('password_reset_tokens').upsert(
          {'email': email, 'verification_code': code, 'created_at': DateTime.now().toIso8601String()},
          onConflict: 'email',
        );

        // Call the Edge Function to send the email with the code.
        final functionResponse = await _supabase.functions.invoke(
          'send-password-reset-email', // Ensure this matches your function name
          body: {
            'toEmail': email,
            'verificationCode': code,
          },
        );

        if (functionResponse.status != 200) {
          final dynamic responseData = functionResponse.data;
          String errorMessage = 'Unknown error occurred.';

          if (responseData is Map<String, dynamic> && responseData.containsKey('error')) {
            errorMessage = responseData['error'] as String;
          } else {
            errorMessage = 'Failed to send email via Edge Function: Status ${functionResponse.status}';
          }

          throw Exception(errorMessage);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification code sent to $email. Please check your inbox.')),
        );

        setState(() {
          _isCodeSent = true;
          _email = email;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not found.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userEnteredCode = _codeController.text.trim();
      final response = await _supabase
          .from('password_reset_tokens')
          .select('verification_code, created_at')
          .eq('email', _email!)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired code.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final storedCode = response['verification_code'] as String;
      final createdAt = DateTime.parse(response['created_at'] as String);

      if (DateTime.now().difference(createdAt).inMinutes > 10) {
        await _supabase.from('password_reset_tokens').delete().eq('email', _email!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code has expired. Please resend.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (storedCode == userEnteredCode) {
        await _supabase.from('password_reset_tokens').delete().eq('email', _email!);
        setState(() {
          _isCodeVerified = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid verification code.')),
        );
      }
    } on PostgrestException catch (e) {
      if (e.message.contains('No rows found')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired code.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
    });

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Call your 'reset-password' Edge Function here.
      final functionResponse = await _supabase.functions.invoke(
        'reset-password',
        body: {
          'email': _email,
          'newPassword': _newPasswordController.text,
        },
      );

      if (functionResponse.status != 200) {
        final dynamic responseData = functionResponse.data;
        String errorMessage = 'Unknown error occurred.';

        if (responseData is Map<String, dynamic> && responseData.containsKey('error')) {
          errorMessage = responseData['error'] as String;
        } else {
          errorMessage = 'Failed to reset password via Edge Function: Status ${functionResponse.status}';
        }

        throw Exception(errorMessage);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting password: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isCodeSent) _buildEmailInput(),
              if (_isCodeSent && !_isCodeVerified) _buildCodeInput(),
              if (_isCodeVerified) _buildPasswordReset(),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailInput() {
    return Column(
      children: [
        const Text('Please enter your email id'),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _sendVerificationCode,
          child: const Text('Submit now'),
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return Column(
      children: [
        Text('Please enter the verification code sent to $_email'),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Verification Code',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _verifyCode,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildPasswordReset() {
    return Column(
      children: [
        const Text('Please enter your new password'),
        const SizedBox(height: 16),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm New Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _resetPassword,
          child: const Text('Change password'),
        ),
      ],
    );
  }
}
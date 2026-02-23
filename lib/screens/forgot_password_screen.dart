import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutrition_assistant/widgets/top_bar.dart';
import '../theme/app_colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _showValidationErrors = false;
  String? _error;

  void _clearErrorOnType() {
    if (_error != null) setState(() => _error = null);
    if (_showValidationErrors) _formKey.currentState?.validate();
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearErrorOnType);
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearErrorOnType);
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    setState(() => _showValidationErrors = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    
    //dynamic sizing for text that handles accessibility scaling
    final linkFontSize = (screenHeight * 0.022).clamp(16.0, 22.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const top_bar(),
          
          // Back Arrow: Placed brown and under the bar as requested
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.accentBrown,
                  size: 24,
                ),
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                // Prevents the keyboard from covering the email field
                padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock Icon
                    Icon(
                      Icons.lock_person_outlined,
                      size: (screenWidth * 0.28).clamp(80, 140),
                      color: AppColors.accentBrown,
                    ),
                    
                    SizedBox(height: screenHeight * 0.04),

                    // The White Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentBrown.withOpacity(0.12),
                              spreadRadius: 2,
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Reset your password',
                                textAlign: TextAlign.center,
                                // textScaler ensures accessibility users don't break the layout
                                textScaler: const TextScaler.linear(1.1),
                                style: TextStyle(
                                  fontSize: (screenWidth * 0.06).clamp(20, 28),
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentBrown,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Enter your email address and we\'ll send you a link to get back into your account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.3, // Tight line height for better scaling
                                  color: AppColors.accentBrown.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Email address',
                                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                                onTap: _clearErrorOnType,
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              _isLoading
                                  ? const CircularProgressIndicator(color: AppColors.brand)
                                  : ElevatedButton(
                                      onPressed: _resetPassword,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.brand,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        minimumSize: const Size(double.infinity, 54),
                                      ),
                                      child: Text(
                                        'Send Reset Link',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: linkFontSize
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // This flexible spacer pushes the card higher up
                    const SizedBox(height: 140), 
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
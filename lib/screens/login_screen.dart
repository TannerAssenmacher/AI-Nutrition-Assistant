import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutrition_assistant/widgets/top_bar.dart';
import 'package:nutrition_assistant/widgets/fatsecret_attribution.dart';
import '../theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showValidationErrors = false;
  String? _error;
  bool _accountDeletedMessageShown = false;

  // Listener that clears the top-level Firebase error as soon as the user types
  void _clearErrorOnType() {
    if (_error != null) setState(() => _error = null);
    if (_showValidationErrors) _formKey.currentState?.validate();
  }

  @override
  void initState() {
    super.initState();
    // Attach listeners so the error message disappears immediately on typing
    _emailController.addListener(_clearErrorOnType);
    _passwordController.addListener(_clearErrorOnType);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_accountDeletedMessageShown) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == 'accountDeleted') {
        _accountDeletedMessageShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.surface),
                    SizedBox(width: 10),
                    Text('Your account has been successfully deleted.'),
                  ],
                ),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 4),
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearErrorOnType);
    _passwordController.removeListener(_clearErrorOnType);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _showValidationErrors =
          true; // start showing field errors when login button is pressed
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Try to sign in with input email and password
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = result.user;

      // Check if user's email is verified before signing in
      if (user != null && !user.emailVerified) {
        await _showEmailVerificationDialog(user);
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Send to home page if user credentials are valid and account is verified
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.code}');
      setState(() => _error = 'Invalid email or password. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Show message for user email verification status
  Future<void> _showEmailVerificationDialog(User user) async {
    bool isVerified = user.emailVerified;
    bool stopChecking = false;

    Future<void> checkVerificationStatus() async {
      while (!stopChecking && !isVerified) {
        await Future.delayed(const Duration(seconds: 4));
        await user.reload();
        final refreshed = FirebaseAuth.instance.currentUser;
        if (refreshed != null && refreshed.emailVerified) {
          isVerified = true;
          stopChecking = true;
          if (mounted) {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/home');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email verified! Welcome back!')),
            );
          }
          break;
        }
      }
    }

    checkVerificationStatus();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Verify Your Email'),
            content: const Text(
              'We sent a verification email to your inbox. '
              'Once you verify it, this screen will automatically continue.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await user.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email sent again!'),
                    ),
                  );
                },
                child: const Text('Resend Email'),
              ),
              TextButton(
                onPressed: () {
                  stopChecking = true;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );

    stopChecking = true;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final logoHeight = (screenHeight * 0.15).clamp(90.0, 140.0).toDouble();
    final cardHorizontalPadding = (mediaQuery.size.width * 0.1)
        .clamp(20.0, 36.0)
        .toDouble();
    final titleFontSize = (screenHeight * 0.03).clamp(24.0, 34.0).toDouble();
    final linkFontSize = (screenHeight * 0.022).clamp(16.0, 22.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 24 + mediaQuery.viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const top_bar(),
              SizedBox(
                height: (screenHeight * 0.03).clamp(16.0, 28.0).toDouble(),
              ),
              SizedBox(
                height: logoHeight,
                child: Image.asset(
                  'lib/icons/WISERBITES.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(
                height: (screenHeight * 0.025).clamp(14.0, 24.0).toDouble(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: EdgeInsets.fromLTRB(
                    cardHorizontalPadding,
                    24,
                    cardHorizontalPadding,
                    20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(48),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.statusNone.withValues(alpha: 0.5),
                        spreadRadius: 4,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentBrown,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            prefixIcon: Icon(
                              Icons.email,
                              color: AppColors.textHint,
                            ),
                            hintStyle: TextStyle(color: AppColors.divider),
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                          onTap: _clearErrorOnType,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: Icon(
                              Icons.lock,
                              color: AppColors.textHint,
                            ),
                            hintStyle: TextStyle(color: AppColors.divider),
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(double.infinity, 52),
                                ),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: (screenHeight * 0.024)
                                        .clamp(18.0, 24.0)
                                        .toDouble(),
                                    color: AppColors.surface,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/forgot');
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: linkFontSize,
                              decoration: TextDecoration.underline,
                              color: AppColors.accentBrown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: (screenHeight * 0.02).clamp(12.0, 20.0).toDouble(),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text(
                  "Don't have an account? Sign Up!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: linkFontSize,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentBrown,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const FatSecretAttribution(showBadge: true),
            ],
          ),
        ),
      ),
    );
  }
}

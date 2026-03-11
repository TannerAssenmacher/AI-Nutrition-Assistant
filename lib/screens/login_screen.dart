import 'package:nutrition_assistant/widgets/fatsecret_attribution.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import '../theme/style_guideline.dart';

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
            AppSnackBar.success(
              context,
              'Your account has been successfully deleted.',
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
            AppSnackBar.success(context, 'Email verified! Welcome back!');
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
                  AppSnackBar.success(context, 'Verification email sent again!');
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
    final titleFontSize = (screenHeight * 0.03).clamp(24.0, 30.0).toDouble();
    final linkFontSize = (screenHeight * 0.022).clamp(16.0, 22.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(vertical: StyleGuideline.cardPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: logoHeight,
                      child: Image.asset(
                        'lib/assets/icons/WISERBITES.png',
                        fit: BoxFit.contain,
                        color: AppColors.brand,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(
                      height: (screenHeight * 0.025)
                          .clamp(14.0, 24.0)
                          .toDouble(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.46,
                        constraints: const BoxConstraints(maxWidth: 520),
                        padding: EdgeInsets.fromLTRB(
                          24, 24, 24, 24
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(StyleGuideline.cardBorderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.08),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Welcome to\nWiserBites.',

                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textPrimary,
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
                                  hintStyle: TextStyle(
                                    color: AppColors.divider,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(StyleGuideline.inputFieldBorderRadius),
                                    borderSide: const BorderSide(
                                      color: AppColors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(StyleGuideline.inputFieldBorderRadius),
                                    borderSide: const BorderSide(
                                      color: AppColors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                    ? 'Please enter your email'
                                    : null,
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
                                  hintStyle: TextStyle(
                                    color: AppColors.divider,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(StyleGuideline.inputFieldBorderRadius),
                                    borderSide: const BorderSide(
                                      color: AppColors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(StyleGuideline.inputFieldBorderRadius),
                                    borderSide: const BorderSide(
                                      color: AppColors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                    ? 'Please enter your password'
                                    : null,
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
                               SizedBox(height: 24),
                              _isLoading
                                  ? Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ElevatedButton(
                                      onPressed: _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.brand,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(StyleGuideline.inputFieldBorderRadius, ),
                                        ),
                                        minimumSize: Size(
                                          double.infinity,
                                          70,
                                        ),
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
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/forgot'),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: linkFontSize,
                                    color: AppColors.blueLink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Divider(color: AppColors.borderLight, thickness: 1, height: 1),
          Container(
            constraints: const BoxConstraints(minHeight: 100),
            width: double.infinity,
            color: AppColors.background,
            padding: EdgeInsets.only(
              top: 25,
              bottom: 25 + mediaQuery.padding.bottom,
              left: 20,
              right: 20,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  "Don't have an account?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: linkFontSize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentBrown,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  child: Text(
                    "Sign Up.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: linkFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blueLink,
                      decorationColor: AppColors.blueLink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const FatSecretAttribution(showBadge: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

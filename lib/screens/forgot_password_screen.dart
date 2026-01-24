import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutrition_assistant/widgets/top_bar.dart';

// Screen to reset password with Firebase Auth functions

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
    setState(() {
      _showValidationErrors = true; // enable field error display
    });

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
          const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} → ${e.message}');
      String msg = 'Error: ${e.message ?? e.code}';
      if (e.code == 'user-not-found') msg = 'No user found with that email.';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5EDE2),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          top_bar(),
          Padding(padding: EdgeInsets.all(50)),
          Text(
            'Oh No! Forgot Your Password?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A3A2A),
            )
          ),
          Padding(padding:  EdgeInsets.all(50)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  //height: MediaQuery.of(context).size.height * 0.3,
                  padding: const EdgeInsets.fromLTRB(30, 50, 30, 50),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.5),
                        spreadRadius: 4,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Form(
                      key: _formKey,
                  child: Column(children: [
                    const SizedBox(height: 10), //padding but for inside containers
                    const Text(
                      'We\'ll send you an email to reset your password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF967460),
                      )
                    ),

                    const SizedBox(height: 20), //padding but for inside containers
                    TextFormField( //the enter email field
                      controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                            
                            hintText: 'Email',
                            prefixIcon: Icon(Icons.email, color: Colors.grey[600],),
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F1E8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
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

                    const SizedBox(height: 25),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 25),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF5F9735),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Send Reset Email',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),),
                      Padding(padding: EdgeInsets.all(20),),
                  ]))
      )],),
          Padding(padding: EdgeInsets.all(30),),
          TextButton(

            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            child: Text(
            '< Back to Login',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              color: Color(0xFF4A3A2A),
            )
          ),
          ),
      ],)
    );
  }


  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Forgot your password?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Enter your email and we’ll send you a password reset link.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (!_showValidationErrors) return null;
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                      onTap: _clearErrorOnType,
                    ),
                    const SizedBox(height: 25),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 25),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Send Reset Email',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }*/
}

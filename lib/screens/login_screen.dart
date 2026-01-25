import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutrition_assistant/widgets/top_bar.dart';

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
  void dispose() {
    _emailController.removeListener(_clearErrorOnType);
    _passwordController.removeListener(_clearErrorOnType);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _showValidationErrors = true; // start showing field errors when login button is pressed
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
                    const SnackBar(content: Text('Verification email sent again!')),
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
    return Scaffold(
      backgroundColor: const Color (0xFFF5EDE2),
      body: Column(
        children: [ SingleChildScrollView(
          //padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (event) {
              if (event.isKeyPressed(LogicalKeyboardKey.enter) ||
                  event.isKeyPressed(LogicalKeyboardKey.numpadEnter)) {
                _login();
              }
            },
            child: Column(
              //mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const top_bar(), //bar at the top of the screen for design
                Padding(padding: const EdgeInsets.only(top: 40)),

                SizedBox( //this is the logo image 
                  //width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.15,
                  child: Image.asset(
                    'lib/icons/WISERBITES.png',
                    fit: BoxFit.contain,
                  )
                ),
                Padding(padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.02)),

                /*const Text( //text
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),*/

                //heres where the new login card is
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  //height: MediaQuery.of(context).size.height * 0.3,
                  padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width * 0.1, 
                                                MediaQuery.of(context).size.width * 0.05, 
                                                MediaQuery.of(context).size.width * 0.1, 
                                                MediaQuery.of(context).size.width * 0.05),
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
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02), //padding but for inside containers
                    Text(
                      'Welcome!',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.height * 0.03,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF967460),
                      )
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height * 0.02), //padding but for inside containers
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
                              horizontal: 10,
                              vertical: 5,
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

                    SizedBox(height: MediaQuery.of(context).size.height * 0.02), //padding but for inside containers
                    TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: Icon(Icons.lock, color: Colors.grey[600],),
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
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),


                        if (_error != null)
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF5F9735),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              //minimumSize: Size(double.infinity, MediaQuery.of( context).size.height * 0.07),
                              //maximumSize: Size(double.infinity, MediaQuery.of( context).size.height * 0.07),
                              fixedSize: Size(MediaQuery.of(context).size.width * 0.8, MediaQuery.of(context).size.height * 0.05),
                            ),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: MediaQuery.of( context).size.height * 0.025,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
  
                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                          TextButton( //forgot password text link
                            onPressed: () {
                              Navigator.pushNamed(context, '/forgot');
                            },
                            child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.height * 0.026,
                              decoration: TextDecoration.underline,
                              color: const Color(0xFF967460),
                            ),
                          ))
                  ],)
                ),),


                //SizedBox(height: MediaQuery.of(context).size.height * 0.02), //here is where the old login card is
                
                /*Card(
                  
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(120),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField( //email field
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                            onTap: _clearErrorOnType,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            onFieldSubmitted: (_) => _login(),
                            validator: (value) {
                              if (!_showValidationErrors) return null;
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
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
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text(
                              'Login',
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
                ),*/
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text("Don't have an account? Sign Up!",
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.height * 0.026,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF967460),
                    ),
                  ),
                ),
                /*TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/forgot');
                  },
                  child: const Text('Forgot Password?'),
                ),*/
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

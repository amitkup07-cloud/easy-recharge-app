import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'firebase_options.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EasyRechargeApp());
}

const Color appMasterColor = Color(0xFF00BFFF);
const Color appBackground = Color(0xFFF7F9FB);
const Color appCardColor = Colors.white;
const Color appTextColor = Colors.black87;
const Color appSubTextColor = Colors.grey;

class EasyRechargeApp extends StatelessWidget {
  const EasyRechargeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Easy Recharge 2026',
      theme: ThemeData(
        scaffoldBackgroundColor: appBackground,
        primaryColor: appMasterColor,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: appMasterColor,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndFingerprint();
  }

  Future<void> _checkAuthAndFingerprint() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      bool authenticated = false;
      try {
        setState(() {
          _isAuthenticating = true;
        });
        authenticated = await auth.authenticate(
          localizedReason: 'App unlock karne ke liye apna Fingerprint lagayein',
        );
        setState(() {
          _isAuthenticating = false;
        });
      } on PlatformException catch (_) {
        setState(() {
          _isAuthenticating = false;
        });
      }

      if (!mounted) return;

      if (authenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        });
      } else {
        FirebaseAuth.instance.signOut();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        });
      }
    } else {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: appMasterColor),
            const SizedBox(height: 20),
            Text(
              _isAuthenticating
                  ? 'Fingerprint verify ho raha hai...'
                  : 'Checking Security...',
              style: const TextStyle(
                fontSize: 18,
                color: appSubTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    String mobile = _mobileController.text.trim();
    String password = _passwordController.text.trim();

    if (mobile.length == 10 && password.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      String dummyEmail = "$mobile@easyrecharge.com";

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: dummyEmail,
          password: password,
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMsg = "Login Failed! Sahi details daalein.";
        if (e.code == 'user-not-found') {
          errorMsg = "Number register nahi hai! Pehle account banayein.";
        } else if (e.code == 'wrong-password') {
          errorMsg = "Galat Password!";
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sahi 10-digit Number aur Password daalein!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 25.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                const Icon(Icons.phone_iphone, size: 80, color: appMasterColor),
                const SizedBox(height: 20),
                const Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: appTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sign in to your Easy Recharge account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: appSubTextColor),
                ),
                const SizedBox(height: 60),
                _buildInput(
                  controller: _mobileController,
                  label: 'Registered Mobile Number',
                  hint: '10-digit number',
                  icon: Icons.phone_android,
                  isPhone: true,
                ),
                const SizedBox(height: 20),
                _buildInput(
                  controller: _passwordController,
                  label: 'Your Password',
                  hint: 'Minimum 6 characters',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),

                // 🔥 NAYA CODE: Forgot Password Button Yahan Lagaya Hai
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: appMasterColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appMasterColor,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'LOGIN SECURELY',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  ),
                  child: const Text(
                    "New User? Let's Register",
                    style: TextStyle(
                      fontSize: 16,
                      color: appMasterColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPhone = false,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: appMasterColor.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        maxLength: isPhone ? 10 : null,
        obscureText: isPassword,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          prefixIcon: Icon(icon, color: appMasterColor),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(22),
          labelStyle: const TextStyle(color: appSubTextColor),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    String mobile = _mobileController.text.trim();
    String password = _passwordController.text.trim();
    String name = _nameController.text.trim();

    if (mobile.length == 10 && password.length >= 6 && name.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      String dummyEmail = "$mobile@easyrecharge.com";

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: dummyEmail,
              password: password,
            );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'name': name,
              'mobile': mobile,
              'walletBalance': 0.0,
              'createdAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account Successfully Created! Ab Login karein.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String errorMsg = "Registration Failed!";
        if (e.code == 'email-already-in-use') {
          errorMsg = "Yeh Number pehle se register hai!";
        } else if (e.code == 'weak-password') {
          errorMsg = "Password thoda strong rakhiye (min 6 characters).";
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Name, 10-digit Number aur Password daalna zaroori hai!',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Register Account',
          style: TextStyle(color: appTextColor, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: appMasterColor),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              _buildInput(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your name',
                icon: Icons.person,
              ),
              const SizedBox(height: 20),
              _buildInput(
                controller: _mobileController,
                label: 'Your Mobile Number',
                hint: '10-digit number',
                icon: Icons.phone_android,
                isPhone: true,
              ),
              const SizedBox(height: 20),
              _buildInput(
                controller: _passwordController,
                label: 'Create Strong Password',
                hint: 'Min 6 characters',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appMasterColor,
                  foregroundColor: Colors.white,
                  elevation: 5,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPhone = false,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: appMasterColor.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        maxLength: isPhone ? 10 : null,
        obscureText: isPassword,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          prefixIcon: Icon(icon, color: appMasterColor),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(22),
          labelStyle: const TextStyle(color: appSubTextColor),
        ),
      ),
    );
  }
}

// ============================================================================
// 🔥 NAYA CODE: Forgot Password (OTP) Screens Niche Hain
// ============================================================================

// ============================================================================
// 🔥 NAYA CODE: Forgot Password (OTP) Screens Niche Hain
// ============================================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _mobileController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOTP() async {
    String mobile = _mobileController.text.trim();
    if (mobile.length == 10) {
      setState(() => _isLoading = true);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$mobile',
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP bhejne mein error: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OTPScreen(verificationId: verificationId, mobile: mobile),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sahi 10-digit number daalein'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
          style: TextStyle(color: appTextColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: appMasterColor),
      ),
      // 🔥 VIP FIX: Center + SingleChildScrollView
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, size: 80, color: appMasterColor),
                const SizedBox(height: 20),
                const Text(
                  "Password bhool gaye?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Apna registered mobile number daalein, hum OTP bhejenge.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: appSubTextColor),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: const Icon(
                      Icons.phone_android,
                      color: appMasterColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appMasterColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SEND OTP",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String mobile;
  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.mobile,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOTP() async {
    String otp = _otpController.text.trim();
    if (otp.length == 6) {
      setState(() => _isLoading = true);
      try {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: otp,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CreateNewPasswordScreen(mobile: widget.mobile),
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Galat OTP! Kripya dobara check karein.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sahi 6-digit OTP daalein'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP', style: TextStyle(color: appTextColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: appMasterColor),
      ),
      // 🔥 VIP FIX: Center + SingleChildScrollView
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.message, size: 80, color: appMasterColor),
                const SizedBox(height: 20),
                Text(
                  "OTP bheja gaya hai: +91 ${widget.mobile}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10),
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appMasterColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "VERIFY OTP",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateNewPasswordScreen extends StatefulWidget {
  final String mobile;
  const CreateNewPasswordScreen({super.key, required this.mobile});

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _newPasswordController = TextEditingController();

  void _saveNewPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Password Reset Requested"),
        content: const Text(
          "Aapka number verify ho gaya hai. Naya password set karne ke liye kripya Admin se sampark karein.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            child: const Text("OK", style: TextStyle(color: appMasterColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create New Password',
          style: TextStyle(color: appTextColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: appMasterColor),
      ),
      // 🔥 VIP FIX: Center + SingleChildScrollView
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security, size: 80, color: appMasterColor),
                const SizedBox(height: 20),
                const Text(
                  "Naya Password Banayein",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock, color: appMasterColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _saveNewPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appMasterColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "SAVE PASSWORD",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

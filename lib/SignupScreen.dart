import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⭐ Needed for inputFormatters
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'LoginScreen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  void showTopSnackbar(String message, Color bgColor) {
    final overlay = Overlay.of(context);

    OverlayEntry entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 40,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2)).then((_) => entry.remove());
  }


  Future<void> signup() async {
    final name = nameController.text.trim();
    final mobile = mobileController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || mobile.isEmpty || password.isEmpty) {
      showTopSnackbar("Please fill all fields", Colors.red);
      return;
    }


    if (mobile.length != 10) {
      showTopSnackbar("Enter a valid 10-digit mobile number", Colors.red);
      return;
    }

    setState(() => loading = true);

    try {
      final url = Uri.parse("https://stafftally.com/api/signup");

      final response = await http.post(url, body: {
        "name": name,
        "mobile": mobile,
        "password": password,
      });

      final data = json.decode(response.body);

      setState(() => loading = false);

      if (response.statusCode == 201) {
        showTopSnackbar("Signup Successful!", Colors.green);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        showTopSnackbar(data["message"] ?? "Signup Failed", Colors.red);
      }
    } catch (e) {
      setState(() => loading = false);
      showTopSnackbar("Network error, please try again", Colors.red);
    }
  }

  // ---------------- MAIN UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FF),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
        child: Column(
          children: [
            Image.asset(
              "assets/staff.png",
              width: 230,
              height: 230,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 0),

            const Text(
              "Create New Account",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B2A),
              ),
            ),

            const SizedBox(height: 35),


            _inputField(
              controller: nameController,
              icon: Icons.person_outline,
              hint: "Enter your name",
            ),
            const SizedBox(height: 20),


            _inputField(
              controller: mobileController,
              icon: Icons.phone_android,
              hint: "Enter your mobile number",
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // only numbers
                LengthLimitingTextInputFormatter(10), // max 10 digits
              ],
            ),
            const SizedBox(height: 20),


            _inputField(
              controller: passwordController,
              icon: Icons.lock_outline,
              hint: "Enter your password",
              isPassword: true,
            ),

            const SizedBox(height: 35),


            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text(
                "Already have an account? Login",
                style: TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }


  Widget _inputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Color(0xFF1E88E5)),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 12),

          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Color(0xFF1E88E5),
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          )
              : null,
        ),
      ),
    );
  }
}

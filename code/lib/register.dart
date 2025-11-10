import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_test/password_strength_indicator.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();
  String gender = 'Khác';
  bool _isLoading = false;

  // Xử lý công việc đăng ký
  Future<void> register() async {
    // Validation
    if (emailController.text.trim().isEmpty || 
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng điền đầy đủ email và mật khẩu')),
      );
      return;
    }

    // Kiểm tra độ mạnh mật khẩu
    final passwordStrength = PasswordStrengthChecker.check(passwordController.text);
    if (passwordStrength.strength == PasswordStrength.weak) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mật khẩu quá yếu! Vui lòng chọn mật khẩu mạnh hơn.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mật khẩu phải có ít nhất 6 ký tự')),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Tạo tài khoản
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Tạo document trong Firestore với thông tin đầy đủ
      final user = credential.user!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': nameController.text.trim(),
        'email': user.email,
        'photoUrl': null,
        'phone': '',
        'gender': gender,
        'role': 'user', // Mặc định là user, admin phải được cấp quyền thủ công
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'passwordStrength': passwordStrength.label, // Lưu độ mạnh mật khẩu
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
      
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Email đã được sử dụng';
          break;
        case 'invalid-email':
          msg = 'Email không hợp lệ';
          break;
        case 'weak-password':
          msg = 'Mật khẩu quá yếu';
          break;
        case 'operation-not-allowed':
          msg = 'Đăng ký tài khoản bị vô hiệu hóa';
          break;
        default:
          msg = e.message ?? 'Lỗi đăng ký';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi không xác định: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Xây dựng giao diện
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Đăng ký tài khoản"),
        backgroundColor: Colors.indigo,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.app_registration,
                      size: 100,
                      color: Colors.amber[700],
                    ),
                    SizedBox(height: 30),
                    
                    // Tên hiển thị (không bắt buộc)
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Tên hiển thị (không bắt buộc)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Email field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Password field với strength indicator
                    PasswordFieldWithStrength(
                      controller: passwordController,
                      labelText: "Mật khẩu *",
                      helperText: "Tối thiểu 6 ký tự",
                      showStrengthIndicator: true,
                    ),
                    SizedBox(height: 16),
                    
                    // Confirm password field
                    TextField(
                      controller: confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: "Xác nhận mật khẩu *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 16),
                    
                    // Giới tính
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: InputDecoration(
                        labelText: 'Giới tính',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: ['Nam', 'Nữ', 'Khác'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          gender = newValue!;
                        });
                      },
                    ),
                    SizedBox(height: 24),
                    
                    // Register button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          "Đăng ký",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Back to login
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Đã có tài khoản? Đăng nhập",
                        style: TextStyle(color: Colors.indigo),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nameController.dispose();
    super.dispose();
  }
}
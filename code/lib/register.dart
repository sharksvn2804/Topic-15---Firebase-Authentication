import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatelessWidget {
  // Cac bien dung de nhap email va mat khau:
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Xu li cong viec dang ki:
  Future<void> register(BuildContext context) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký thành công!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      if (e.code == 'email-already-in-use') {
        msg = 'Email đã tồn tại!';
      } else if (e.code == 'invalid-email') {
        msg = 'Email không hợp lệ!';
      } else {
        msg = e.message ?? 'Lỗi đăng ký!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }
  //...

  // Xay dung giao dien:
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              "Đăng ký tài khoản"
          ),
          backgroundColor: Colors.indigo,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 60),
            Icon (
              Icons.app_registration,
              size: 150,
              color: const Color.fromARGB(255, 205, 195, 9),
            ),
            SizedBox(height: 30),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Mật khẩu"),
              obscureText: true,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              child: Text(
                  "Đăng ký",
                  style: TextStyle(
                    color: Colors.indigo,
                    fontSize: 16
                  ),
              ),
              onPressed: () {
                register(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
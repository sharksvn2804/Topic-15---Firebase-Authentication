import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register.dart';

class LoginPage extends StatelessWidget {
  // Cac bien dung de nhap email va mat khau:
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Xu li cong viec dang nhap:
  Future<void> login(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword (
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đăng nhập thành công!')));
    } on FirebaseAuthException catch (e) {
      String msg;
      print(e.code);
      if (e.code == 'invalid-credential') {
        msg = 'Email hoặc mật khẩu không đúng!';
      } else if (e.code == 'invalid-email') {
        msg = 'Định dạng email không hợp lệ!';
      } else {
        msg = 'Lỗi đăng nhập không xác định!';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
  //... (tiep tuc)

  // Xu li dang nhap voi Google:
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn (
        scopes: ['email'],
        serverClientId: '444657505753-v6hbilr753l7k3hmmkgilbsdtcd4ibro.apps.googleusercontent.com'
      );
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng nhập Google bị hủy')),
        );
        return;
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      // Tạo credential cho Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập Google thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập Google: $e')),
      );
    }
  }
  //...

  // Xu li dang nhap voi Facebook:
  Future<void> signInWithFacebook(BuildContext context) async {
    try {
      final result = await FacebookAuth.instance.login();
      final accessToken = result.accessToken?.tokenString;
      if (accessToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng nhập Facebook bị hủy hoặc lỗi token')),
        );
        return;
      }
      final credential = FacebookAuthProvider.credential(accessToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập Facebook thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập Facebook: $e')),
      );
    }
  }
  //...

  // Xay dung giao dien:
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Đăng nhập vào ứng dụng"),
          backgroundColor: Colors.indigo,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 60),
            Icon (
              Icons.lock,
              size: 150,
              color: const Color.fromARGB(255, 205, 195, 9),
            ),
            SizedBox(height: 30),
            TextField (
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Mật khẩu"),
              obscureText: true,
            ),
            SizedBox(height: 60),
            ElevatedButton (
              child: Text(
                  "Đăng nhập",
                  style: TextStyle(
                      color: Colors.indigo,
                      fontSize: 16
                  ),
              ),
              onPressed: () {
                login(context);
              },
            ),
            SizedBox(height: 20),
            TextButton (
              child: Text(
                "Không có tài khoản? Đăng ký",
                style: TextStyle(
                    color: Colors.indigo,
                    fontSize: 16
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterPage()),
                );
              },
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Căn đều khoảng cách
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.login),
                    label: Text(
                      "Google",
                      style: TextStyle(
                          fontSize: 16
                      ),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 247, 207, 207)),
                    onPressed: () => signInWithGoogle(context),
                  ),
                ),
                SizedBox(width: 20), // Khoảng cách giữa 2 nút
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.facebook),
                    label: Text(
                      "Facebook", 
                      style: TextStyle(
                          fontSize: 16
                      ),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 178, 213, 239)),
                    onPressed: () => signInWithFacebook(context),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
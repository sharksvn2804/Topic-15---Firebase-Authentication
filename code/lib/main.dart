import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_test/firebase_options.dart';
import 'package:firebase_test/login.dart';
import 'package:firebase_test/profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chương trình thử - Khánh + Tâm',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Kiểm tra trạng thái đăng nhập
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Đang tải
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Đã đăng nhập - kiểm tra xem tài khoản có bị xóa không
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (context, userDoc) {
                if (userDoc.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                // Kiểm tra tài khoản có bị xóa/disable không
                if (userDoc.hasData && userDoc.data != null) {
                  final userData = userDoc.data!.data() as Map<String, dynamic>?;
                  
                  if (userData != null && userData['deleted'] == true) {
                    // Tài khoản đã bị xóa - đăng xuất và hiển thị thông báo
                    return DeletedAccountPage(user: snapshot.data!);
                  }
                  
                  // Tài khoản bình thường
                  return ProfilePage(user: snapshot.data!);
                }
                
                // Không tìm thấy data - tạo mới
                return ProfilePage(user: snapshot.data!);
              },
            );
          }
          
          // Chưa đăng nhập
          return LoginPage();
        },
      ),
    );
  }
}

// Trang thông báo tài khoản đã bị xóa
class DeletedAccountPage extends StatelessWidget {
  final User user;
  
  const DeletedAccountPage({Key? key, required this.user}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    // Tự động đăng xuất sau khi hiển thị thông báo
    Future.delayed(Duration(milliseconds: 100), () async {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Text('Tài khoản đã bị xóa'),
            ],
          ),
          content: Text(
            'Tài khoản của bạn đã bị quản trị viên xóa hoặc vô hiệu hóa.\n\n'
            'Bạn không thể tiếp tục sử dụng tài khoản này.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Đã hiểu'),
            ),
          ],
        ),
      );
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 100,
              color: Colors.red,
            ),
            SizedBox(height: 20),
            Text(
              'Tài khoản đã bị xóa',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Tài khoản của bạn đã bị quản trị viên xóa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
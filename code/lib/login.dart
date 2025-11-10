import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:firebase_test/profile.dart';
import 'package:firebase_test/register.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

  // Login attempt monitoring
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const int MAX_ATTEMPTS = 3;
  static const Duration LOCKOUT_DURATION = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadLoginAttempts();
  }

  // Tải thông tin về số lần đăng nhập sai từ Firestore
  Future<void> _loadLoginAttempts() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('login_attempts')
          .doc(email)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final lockoutTimestamp = data['lockoutUntil'] as Timestamp?;

        setState(() {
          _failedAttempts = data['failedAttempts'] ?? 0;
          if (lockoutTimestamp != null) {
            _lockoutUntil = lockoutTimestamp.toDate();

            if (_lockoutUntil!.isBefore(DateTime.now())) {
              _failedAttempts = 0;
              _lockoutUntil = null;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading login attempts: $e');
    }
  }

  bool _isLockedOut() {
    if (_lockoutUntil == null) return false;
    return DateTime.now().isBefore(_lockoutUntil!);
  }

  String _getRemainingLockoutTime() {
    if (_lockoutUntil == null) return '';

    final remaining = _lockoutUntil!.difference(DateTime.now());
    if (remaining.isNegative) return '';

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes phút $seconds giây';
  }

  Future<void> _recordFailedAttempt(String email) async {
    _failedAttempts++;

    DateTime? lockoutTime;
    if (_failedAttempts >= MAX_ATTEMPTS) {
      lockoutTime = DateTime.now().add(LOCKOUT_DURATION);
      setState(() {
        _lockoutUntil = lockoutTime;
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection('login_attempts')
          .doc(email)
          .set({
        'email': email,
        'failedAttempts': _failedAttempts,
        'lastFailedAt': FieldValue.serverTimestamp(),
        'lockoutUntil': lockoutTime != null ? Timestamp.fromDate(lockoutTime) : null,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('security_logs')
          .add({
        'event': 'login_failed',
        'email': email,
        'timestamp': FieldValue.serverTimestamp(),
        'failedAttempts': _failedAttempts,
        'ipAddress': 'N/A',
      });

      if (_failedAttempts >= MAX_ATTEMPTS) {
        await _sendSecurityAlert(email);
      }
    } catch (e) {
      print('Error recording failed attempt: $e');
    }
  }

  Future<void> _sendSecurityAlert(String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('security_alerts')
          .add({
        'type': 'multiple_failed_login',
        'email': email,
        'failedAttempts': _failedAttempts,
        'lockoutUntil': _lockoutUntil != null ? Timestamp.fromDate(_lockoutUntil!) : null,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

      print('Security alert sent for: $email');
    } catch (e) {
      print('Error sending security alert: $e');
    }
  }

  Future<void> _resetLoginAttempts(String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('login_attempts')
          .doc(email)
          .delete();

      setState(() {
        _failedAttempts = 0;
        _lockoutUntil = null;
      });

      await FirebaseFirestore.instance
          .collection('security_logs')
          .add({
        'event': 'login_success',
        'email': email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error resetting login attempts: $e');
    }
  }

  // Xử lý profile user cho cả email và social login
  Future<void> handleUserProfile(User user, {String? loginMethod}) async {
    final usersRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await usersRef.get();

    if (!doc.exists) {
      // Tạo mới user
      await usersRef.set({
        'name': user.displayName ?? '',
        'email': user.email,
        'photoUrl': user.photoURL,
        'phone': '',
        'gender': 'Khác',
        'role': 'user',
        'loginMethod': loginMethod ?? 'email',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'deleted': false,
      });
    } else {
      // Cập nhật thông tin nếu user đã tồn tại
      final data = doc.data()!;

      // Kiểm tra xem tài khoản có bị xóa không
      if (data['deleted'] == true) {
        throw Exception('account_deleted');
      }

      // Cập nhật lastLogin và thông tin mới từ social (nếu có)
      Map<String, dynamic> updateData = {
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Cập nhật loginMethod nếu đăng nhập bằng social
      if (loginMethod != null && loginMethod != 'email') {
        updateData['loginMethod'] = loginMethod;
      }

      // Cập nhật photo và name nếu social login có thông tin mới
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        updateData['photoUrl'] = user.photoURL;
      }
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        updateData['name'] = user.displayName;
      }

      await usersRef.update(updateData);
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập email để đặt lại mật khẩu')),
      );
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email không hợp lệ')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.email, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Đặt lại mật khẩu'),
          ],
        ),
        content: Text(
          'Chúng tôi sẽ gửi email đặt lại mật khẩu đến:\n\n$email\n\nBạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: Text('Gửi email'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      setState(() => _isLoading = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Thành công'),
            ],
          ),
          content: Text(
            'Email đặt lại mật khẩu đã được gửi đến $email.\n\n'
                'Vui lòng kiểm tra hộp thư (kể cả thư rác) và làm theo hướng dẫn để đặt lại mật khẩu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đã hiểu'),
            ),
          ],
        ),
      );

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String errorMsg = 'Lỗi gửi email';

      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'Email này chưa được đăng ký';
          break;
        case 'invalid-email':
          errorMsg = 'Email không hợp lệ';
          break;
        default:
          errorMsg = e.message ?? 'Lỗi gửi email đặt lại mật khẩu';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi không xác định: $e')),
      );
    }
  }

  // Đăng nhập bằng email/password
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập email và mật khẩu')),
      );
      return;
    }

    if (_isLockedOut()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tài khoản tạm thời bị khóa do đăng nhập sai quá nhiều lần.\n'
                'Vui lòng thử lại sau: ${_getRemainingLockoutTime()}',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;

      await _resetLoginAttempts(email);

      await Future.wait([
        handleUserProfile(user, loginMethod: 'email'),
        Future.delayed(Duration(milliseconds: 400)),
      ]);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Đăng nhập thất bại';

      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'Email chưa được đăng ký';
          break;
        case 'wrong-password':
          errorMsg = 'Mật khẩu không đúng';
          await _recordFailedAttempt(email);

          if (_failedAttempts >= MAX_ATTEMPTS - 1 && _failedAttempts < MAX_ATTEMPTS) {
            errorMsg += '\n\nCảnh báo: Bạn còn ${MAX_ATTEMPTS - _failedAttempts} lần thử. '
                'Sau đó tài khoản sẽ bị khóa ${LOCKOUT_DURATION.inMinutes} phút.';
          } else if (_failedAttempts >= MAX_ATTEMPTS) {
            errorMsg = 'Đã đăng nhập sai $MAX_ATTEMPTS lần!\n'
                'Tài khoản bị khóa trong ${LOCKOUT_DURATION.inMinutes} phút.';
          }
          break;
        case 'invalid-email':
          errorMsg = 'Email không hợp lệ';
          break;
        case 'user-disabled':
          errorMsg = 'Tài khoản đã bị vô hiệu hóa';
          break;
        default:
          errorMsg = e.message ?? 'Đăng nhập thất bại';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
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

// Đăng nhập bằng Google - FIXED
  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Sử dụng clientId khác nhau tùy theo platform
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        // Đối với Web: sử dụng Web Client ID
        // Đối với Android/iOS: không cần clientId (lấy từ config)
        clientId: kIsWeb
            ? '444657505753-cbb4580e7bb816feff35c8.apps.googleusercontent.com' // Web Client ID từ firebase_options.dart
            : null,
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng nhập Google bị hủy')),
        );
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      // Xử lý profile
      try {
        await handleUserProfile(user, loginMethod: 'google');
      } catch (e) {
        if (e.toString().contains('account_deleted')) {
          await FirebaseAuth.instance.signOut();
          await googleSignIn.signOut();

          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tài khoản đã bị vô hiệu hóa bởi quản trị viên'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        rethrow;
      }

      // Ghi log đăng nhập thành công
      await FirebaseFirestore.instance
          .collection('security_logs')
          .add({
        'event': 'login_success_google',
        'email': user.email,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập Google thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập Google: $e')),
      );
    }
  }

  // Đăng nhập bằng Facebook
  Future<void> signInWithFacebook() async {
    setState(() => _isLoading = true);

    try {
      final result = await FacebookAuth.instance.login();
      final accessToken = result.accessToken?.tokenString;

      if (accessToken == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng nhập Facebook bị hủy hoặc lỗi token')),
        );
        return;
      }

      final credential = FacebookAuthProvider.credential(accessToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      // Xử lý profile
      try {
        await handleUserProfile(user, loginMethod: 'facebook');
      } catch (e) {
        if (e.toString().contains('account_deleted')) {
          await FirebaseAuth.instance.signOut();
          await FacebookAuth.instance.logOut();

          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tài khoản đã bị vô hiệu hóa bởi quản trị viên'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        rethrow;
      }

      // Ghi log đăng nhập thành công
      await FirebaseFirestore.instance
          .collection('security_logs')
          .add({
        'event': 'login_success_facebook',
        'email': user.email,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập Facebook thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập Facebook: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLockedOut = _isLockedOut();

    return Scaffold(
      appBar: AppBar(
        title: Text('Đăng nhập'),
        backgroundColor: Colors.indigo,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon đăng nhập
                    Icon(
                      Icons.login,
                      size: 100,
                      color: Colors.indigo,
                    ),
                    SizedBox(height: 30),

                    // Cảnh báo khóa tài khoản
                    if (isLockedOut)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_clock, color: Colors.red[700]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tài khoản tạm khóa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[900],
                                    ),
                                  ),
                                  Text(
                                    'Thời gian còn lại: ${_getRemainingLockoutTime()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Cảnh báo số lần thử
                    if (_failedAttempts > 0 && !isLockedOut)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange[700]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Đã đăng nhập sai $_failedAttempts/${MAX_ATTEMPTS} lần. '
                                    'Còn ${MAX_ATTEMPTS - _failedAttempts} lần thử.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Email field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      onChanged: (value) {
                        if (value.contains('@')) {
                          _loadLoginAttempts();
                        }
                      },
                    ),
                    SizedBox(height: 16),

                    // Password field
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || isLockedOut) ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isLockedOut ? 'Tài khoản đang bị khóa' : 'Đăng nhập',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Forgot password button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : forgotPassword,
                        child: Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Register button
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RegisterPage()),
                        );
                      },
                      child: Text(
                        'Chưa có tài khoản? Đăng ký ngay',
                        style: TextStyle(
                          color: Colors.indigo,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'HOẶC',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(thickness: 1)),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Social login buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.login, color: Colors.red[700]),
                            label: Text(
                              'Google',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[50],
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.red[200]!),
                            ),
                            onPressed: _isLoading ? null : signInWithGoogle,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.facebook, color: Colors.blue[700]),
                            label: Text(
                              'Facebook',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[50],
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.blue[200]!),
                            ),
                            onPressed: _isLoading ? null : signInWithFacebook,
                          ),
                        ),
                      ],
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
    super.dispose();
  }
}

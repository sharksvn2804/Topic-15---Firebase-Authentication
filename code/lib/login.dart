import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_test/profile.dart';
import 'package:firebase_test/register.dart';

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
            
            // Nếu đã hết thời gian khóa, reset
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

  // Kiểm tra xem tài khoản có đang bị khóa không
  bool _isLockedOut() {
    if (_lockoutUntil == null) return false;
    return DateTime.now().isBefore(_lockoutUntil!);
  }

  // Tính thời gian còn lại của khóa
  String _getRemainingLockoutTime() {
    if (_lockoutUntil == null) return '';
    
    final remaining = _lockoutUntil!.difference(DateTime.now());
    if (remaining.isNegative) return '';
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes phút $seconds giây';
  }

  // Ghi log đăng nhập thất bại
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
      // Lưu vào Firestore
      await FirebaseFirestore.instance
          .collection('login_attempts')
          .doc(email)
          .set({
        'email': email,
        'failedAttempts': _failedAttempts,
        'lastFailedAt': FieldValue.serverTimestamp(),
        'lockoutUntil': lockoutTime != null ? Timestamp.fromDate(lockoutTime) : null,
      }, SetOptions(merge: true));

      // Ghi log vào collection riêng để phân tích
      await FirebaseFirestore.instance
          .collection('security_logs')
          .add({
        'event': 'login_failed',
        'email': email,
        'timestamp': FieldValue.serverTimestamp(),
        'failedAttempts': _failedAttempts,
        'ipAddress': 'N/A', // Có thể thêm IP nếu có
      });

      // Nếu đạt ngưỡng, gửi cảnh báo (có thể tích hợp email ở đây)
      if (_failedAttempts >= MAX_ATTEMPTS) {
        await _sendSecurityAlert(email);
      }
    } catch (e) {
      print('Error recording failed attempt: $e');
    }
  }

  // Gửi cảnh báo bảo mật
  Future<void> _sendSecurityAlert(String email) async {
    try {
      // Lưu cảnh báo vào Firestore để admin có thể xem
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

      // TODO: Tích hợp Firebase Functions để gửi email thực tế
      // Ví dụ: await sendEmailAlert(email, _failedAttempts);
      
      print('Security alert sent for: $email');
    } catch (e) {
      print('Error sending security alert: $e');
    }
  }

  // Reset số lần đăng nhập sai sau khi đăng nhập thành công
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

      // Ghi log đăng nhập thành công
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

  Future<void> handleUserProfile(User user) async {
    final usersRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await usersRef.get();

    if (!doc.exists) {
      await usersRef.set({
        'name': user.displayName ?? '',
        'email': user.email,
        'photoUrl': user.photoURL,
        'phone': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      await usersRef.update({'lastLogin': FieldValue.serverTimestamp()});
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

    // Hiển thị dialog xác nhận
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
      
      // Hiển thị dialog thành công
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

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // Validation
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập email và mật khẩu')),
      );
      return;
    }

    // Kiểm tra lockout
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
      
      // Reset login attempts sau khi đăng nhập thành công
      await _resetLoginAttempts(email);
      
      // Tối ưu tốc độ bằng Future.wait
      await Future.wait([
        handleUserProfile(user),
        Future.delayed(Duration(milliseconds: 400)),
      ]);

      if (!mounted) return;
      
      // Navigator sẽ tự động chuyển trang vì StreamBuilder trong main.dart
      // nhưng để đảm bảo, ta vẫn có thể dùng:
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
          // Ghi log đăng nhập thất bại
          await _recordFailedAttempt(email);
          
          // Hiển thị cảnh báo nếu gần đạt ngưỡng
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
                        // Tải thông tin login attempts khi email thay đổi
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
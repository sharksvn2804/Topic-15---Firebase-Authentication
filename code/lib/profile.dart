import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_test/admin_users_list.dart';
import 'package:firebase_test/login.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  String? photoUrl;
  String gender = 'Khác';
  String role = 'user';
  bool isLoading = true;
  bool isUpdatingEmail = false;
  bool isVerifyingEmail = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? '';
        phoneController.text = data['phone'] ?? '';
        photoUrl = data['photoUrl'];
        
        // Load thông tin
        gender = data['gender'] ?? 'Khác';
        role = data['role'] ?? 'user';
      } else {
        await docRef.set({
          'name': widget.user.displayName ?? '',
          'email': widget.user.email,
          'photoUrl': widget.user.photoURL,
          'phone': '',
          'gender': 'Khác',
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        photoUrl = widget.user.photoURL;
      }

      emailController.text = widget.user.email ?? '';

      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thông tin: $e')),
        );
      }
    }
  }

  
    

  Future<void> updateProfile() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

      await docRef.update({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'gender': gender,
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật hồ sơ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e')),
        );
      }
    }
  }

  Future<void> updateEmail() async {
    final newEmail = emailController.text.trim();

    if (newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập email mới')),
      );
      return;
    }

    if (!newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email không hợp lệ')),
      );
      return;
    }

    if (newEmail == widget.user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email mới trùng với email hiện tại')),
      );
      return;
    }

    final password = await _showPasswordDialog();
    if (password == null) return;

    setState(() => isUpdatingEmail = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: password,
      );
      
      await widget.user.reauthenticateWithCredential(credential);
      await widget.user.verifyBeforeUpdateEmail(newEmail);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'email': newEmail,
        'emailVerified': false,
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => isUpdatingEmail = false);
        
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
              'Email xác thực đã được gửi đến $newEmail.\n\n'
              'Vui lòng kiểm tra hộp thư và nhấn vào link xác thực.\n\n'
              'Sau khi xác thực, vui lòng đăng nhập lại.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  logout();
                },
                child: Text('Đăng xuất ngay'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => isUpdatingEmail = false);
      
      String errorMsg = 'Lỗi cập nhật email';
      switch (e.code) {
        case 'wrong-password':
          errorMsg = 'Mật khẩu không đúng';
          break;
        case 'email-already-in-use':
          errorMsg = 'Email này đã được sử dụng';
          break;
        case 'invalid-email':
          errorMsg = 'Email không hợp lệ';
          break;
        case 'requires-recent-login':
          errorMsg = 'Vui lòng đăng xuất và đăng nhập lại trước khi đổi email';
          break;
        default:
          errorMsg = e.message ?? 'Lỗi cập nhật email';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      setState(() => isUpdatingEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi không xác định: $e')),
      );
    }
  }

  Future<void> sendVerificationEmail() async {
    if (widget.user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email đã được xác thực')),
      );
      return;
    }

    setState(() => isVerifyingEmail = true);

    try {
      await widget.user.sendEmailVerification();
      
      if (mounted) {
        setState(() => isVerifyingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email xác thực đã được gửi đến ${widget.user.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => isVerifyingEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi email: $e')),
      );
    }
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác thực danh tính'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vui lòng nhập mật khẩu hiện tại để xác thực:'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận đăng xuất'),
        content: Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> deleteAccount() async {
    // Hiển thị dialog xác nhận
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Xóa tài khoản'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản này?\n\n'
          'Hành động này KHÔNG THỂ hoàn tác!\n'
          'Tất cả dữ liệu của bạn sẽ bị xóa vĩnh viễn.',
          style: TextStyle(color: Colors.red[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Xóa tài khoản'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Yêu cầu nhập mật khẩu để xác thực
    final password = await _showPasswordDialog();
    if (password == null) return;

    setState(() => _isLoading = true);

    try {
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: password,
      );
      
      await widget.user.reauthenticateWithCredential(credential);

      // Xóa document trong Firestore trước
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .delete();

      // Xóa tài khoản Firebase Auth
      await widget.user.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tài khoản đã được xóa thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Chuyển về màn hình đăng nhập
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      
      String errorMsg = 'Lỗi xóa tài khoản';
      switch (e.code) {
        case 'wrong-password':
          errorMsg = 'Mật khẩu không đúng';
          break;
        case 'requires-recent-login':
          errorMsg = 'Vui lòng đăng xuất và đăng nhập lại trước khi xóa tài khoản';
          break;
        default:
          errorMsg = e.message ?? 'Lỗi xóa tài khoản';
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Hồ sơ người dùng"),
          backgroundColor: Colors.indigo,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Hồ sơ cá nhân"),
        backgroundColor: Colors.indigo,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          // Nút Admin (chỉ hiện nếu là admin)
          if (role == 'admin')
            IconButton(
              icon: Icon(Icons.admin_panel_settings, color: Colors.amber),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminUsersListPage()),
                );
              },
              tooltip: 'Quản lý người dùng',
            ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 20),
                  
                  // Avatar và vai trò
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                            ? NetworkImage(photoUrl!)
                            : null,
                        child: (photoUrl == null || photoUrl!.isEmpty)
                            ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                            : null,
                      ),
                      if (role == 'admin')
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  SizedBox(height: 10),
                  
                  // Badge vai trò
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: role == 'admin' ? Colors.amber[100] : Colors.blue[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: role == 'admin' ? Colors.amber[700]! : Colors.blue[700]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                          size: 16,
                          color: role == 'admin' ? Colors.amber[900] : Colors.blue[900],
                        ),
                        SizedBox(width: 6),
                        Text(
                          role == 'admin' ? 'Quản trị viên' : 'Người dùng',
                          style: TextStyle(
                            color: role == 'admin' ? Colors.amber[900] : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Tên hiển thị
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Tên hiển thị',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
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
                  SizedBox(height: 16),
                  
                  // Số điện thoại
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Email với nút cập nhật
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.edit, color: Colors.indigo),
                        onPressed: isUpdatingEmail ? null : updateEmail,
                        tooltip: 'Cập nhật email',
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Trạng thái xác thực email
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.user.emailVerified 
                          ? Colors.green[50] 
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.user.emailVerified 
                            ? Colors.green[200]! 
                            : Colors.orange[200]!
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.user.emailVerified 
                              ? Icons.verified 
                              : Icons.warning_amber,
                          color: widget.user.emailVerified 
                              ? Colors.green[700] 
                              : Colors.orange[700],
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.user.emailVerified
                                ? 'Email đã được xác thực ✓'
                                : 'Email chưa được xác thực',
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.user.emailVerified 
                                  ? Colors.green[900] 
                                  : Colors.orange[900],
                            ),
                          ),
                        ),
                        if (!widget.user.emailVerified)
                          TextButton(
                            onPressed: isVerifyingEmail ? null : sendVerificationEmail,
                            child: Text('Gửi email xác thực'),
                          ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Nút lưu thông tin
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: updateProfile,
                      icon: Icon(Icons.save),
                      label: Text("Lưu thay đổi"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Thông tin tài khoản
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông tin tài khoản',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.verified_user, size: 20, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Email đã xác thực: ${widget.user.emailVerified ? "Có" : "Chưa"}'),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.fingerprint, size: 20, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ID: ${widget.user.uid}',
                                  style: TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Nút xóa tài khoản (màu đỏ, nguy hiểm)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red[700]),
                            SizedBox(width: 12),
                            Text(
                              'Vùng nguy hiểm',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[900],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : deleteAccount,
                            icon: Icon(Icons.delete_forever),
                            label: Text("Xóa tài khoản vĩnh viễn"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Hành động này không thể hoàn tác!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Loading overlay
          if (isUpdatingEmail || isVerifyingEmail || _isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      isUpdatingEmail 
                          ? 'Đang cập nhật email...' 
                          : isVerifyingEmail 
                              ? 'Đang gửi email...'
                              : 'Đang xóa tài khoản...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }
}
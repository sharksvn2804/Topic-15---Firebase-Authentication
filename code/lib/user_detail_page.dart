import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const UserDetailPage({
    Key? key,
    required this.userId,
    required this.userData,
  }) : super(key: key);

  @override
  _UserDetailPageState createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late Map<String, dynamic> userData;
  bool isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data()!;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  Future<void> toggleUserRole() async {
    final currentRole = userData['role'] ?? 'user';
    final newRole = currentRole == 'admin' ? 'user' : 'admin';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận thay đổi vai trò'),
        content: Text(
          currentRole == 'admin'
              ? 'Bạn có chắc chắn muốn hạ quyền người dùng này xuống User?'
              : 'Bạn có chắc chắn muốn cấp quyền Admin cho người dùng này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newRole == 'admin' ? Colors.amber : Colors.blue,
            ),
            child: Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'role': newRole});

      if (mounted) {
        setState(() {
          userData['role'] = newRole;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thay đổi vai trò thành ${newRole == 'admin' ? 'Admin' : 'User'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thay đổi vai trò: $e')),
        );
      }
    }
  }

  Future<void> deleteUser() async {
    final userName = userData['name'] ?? 'người dùng này';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Xóa người dùng'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản "$userName"?\n\n'
          'Tài khoản sẽ bị vô hiệu hóa và không thể đăng nhập.\n'
          'Dữ liệu sẽ được đánh dấu là đã xóa.',
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
            child: Text('Xóa người dùng'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      // Đánh dấu tài khoản là đã bị xóa trong Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã vô hiệu hóa tài khoản "$userName"'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Quay lại trang danh sách
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa người dùng: $e')),
        );
      }
    }
  }

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Chưa có thông tin';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Lỗi định dạng';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Chi tiết người dùng'),
          backgroundColor: Colors.indigo,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = userData['name'] ?? 'Chưa có tên';
    final email = userData['email'] ?? 'Chưa có email';
    final phone = userData['phone'] ?? 'Chưa cập nhật';
    final role = userData['role'] ?? 'user';
    final photoUrl = userData['photoUrl'];
    final gender = userData['gender'] ?? 'Chưa cập nhật';
    final createdAt = userData['createdAt'];
    final lastLogin = userData['lastLogin'];
    final lastUpdate = userData['lastUpdate'];
    final emailVerified = userData['emailVerified'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết người dùng'),
        backgroundColor: Colors.indigo,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              role == 'admin' ? Icons.remove_moderator : Icons.admin_panel_settings,
              color: Colors.white,
            ),
            onPressed: _isDeleting ? null : toggleUserRole,
            tooltip: role == 'admin' ? 'Hạ quyền xuống User' : 'Cấp quyền Admin',
          ),
          IconButton(
            icon: Icon(Icons.delete_forever, color: Colors.red[300]),
            onPressed: _isDeleting ? null : deleteUser,
            tooltip: 'Xóa người dùng',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar và vai trò
            Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.toString().isEmpty)
                      ? Icon(Icons.person, size: 70, color: Colors.grey[600])
                      : null,
                ),
                if (role == 'admin')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Tên
            Text(
              name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 8),
            
            // Badge vai trò
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: role == 'admin' ? Colors.amber[100] : Colors.blue[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: role == 'admin' ? Colors.amber[700]! : Colors.blue[700]!,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                    size: 18,
                    color: role == 'admin' ? Colors.amber[900] : Colors.blue[900],
                  ),
                  SizedBox(width: 8),
                  Text(
                    role == 'admin' ? 'Quản trị viên' : 'Người dùng',
                    style: TextStyle(
                      color: role == 'admin' ? Colors.amber[900] : Colors.blue[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 30),
            
            // Thông tin cá nhân
            _buildInfoCard(
              'Thông tin cá nhân',
              Icons.person_outline,
              Colors.blue,
              [
                _buildInfoRow(Icons.email, 'Email', email),
                _buildInfoRow(Icons.phone, 'Số điện thoại', phone),
                _buildInfoRow(Icons.wc, 'Giới tính', gender),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Thông tin tài khoản
            _buildInfoCard(
              'Thông tin tài khoản',
              Icons.security,
              Colors.green,
              [
                _buildInfoRow(
                  emailVerified ? Icons.verified_user : Icons.warning_amber,
                  'Trạng thái email',
                  emailVerified ? 'Đã xác thực' : 'Chưa xác thực',
                  valueColor: emailVerified ? Colors.green : Colors.orange,
                ),
                _buildInfoRow(Icons.fingerprint, 'User ID', widget.userId),
                _buildInfoRow(Icons.calendar_today, 'Ngày tạo', formatDate(createdAt)),
                _buildInfoRow(Icons.access_time, 'Đăng nhập gần nhất', formatDate(lastLogin)),
                if (lastUpdate != null)
                  _buildInfoRow(Icons.update, 'Cập nhật gần nhất', formatDate(lastUpdate)),
              ],
            ),
            
            SizedBox(height: 30),
            
            // Nút thay đổi vai trò
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : toggleUserRole,
                icon: Icon(
                  role == 'admin' ? Icons.remove_moderator : Icons.admin_panel_settings,
                ),
                label: Text(
                  role == 'admin' ? 'Hạ quyền xuống User' : 'Cấp quyền Admin',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: role == 'admin' ? Colors.orange : Colors.amber,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Nút xóa người dùng
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
                      onPressed: _isDeleting ? null : deleteUser,
                      icon: Icon(Icons.delete_forever),
                      label: Text("Xóa người dùng này vĩnh viễn"),
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
      
      // Loading overlay
      if (_isDeleting)
        Container(
          color: Colors.black45,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Đang xóa người dùng...',
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

  Widget _buildInfoCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
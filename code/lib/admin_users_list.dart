import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_test/user_detail_page.dart';

class AdminUsersListPage extends StatefulWidget {
  const AdminUsersListPage({Key? key}) : super(key: key);

  @override
  _AdminUsersListPageState createState() => _AdminUsersListPageState();
}

class _AdminUsersListPageState extends State<AdminUsersListPage> {
  String searchQuery = '';
  String filterRole = 'all'; // all, admin, user
  String filterStatus = 'active'; // active, deleted, all

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = filterRole == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[700]),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            filterRole = value;
          });
        }
      },
      selectedColor: Colors.indigo,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
    );
  }

  Widget _buildStatusFilterChip(String label, String value, IconData icon, Color color) {
    final isSelected = filterStatus == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            filterStatus = value;
          });
        }
      },
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý người dùng'),
        backgroundColor: Colors.indigo,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm và filter
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Tìm kiếm
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên hoặc email...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
                SizedBox(height: 12),
                
                // Filter theo vai trò
                Row(
                  children: [
                    Text('Vai trò: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Tất cả', 'all', Icons.people),
                            SizedBox(width: 8),
                            _buildFilterChip('Admin', 'admin', Icons.admin_panel_settings),
                            SizedBox(width: 8),
                            _buildFilterChip('User', 'user', Icons.person),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                
                // Filter theo trạng thái
                Row(
                  children: [
                    Text('Trạng thái: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusFilterChip('Hoạt động', 'active', Icons.check_circle, Colors.green),
                            SizedBox(width: 8),
                            _buildStatusFilterChip('Vô hiệu hóa', 'deleted', Icons.block, Colors.red),
                            SizedBox(width: 8),
                            _buildStatusFilterChip('Tất cả', 'all', Icons.view_list, Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Danh sách người dùng
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có người dùng nào',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Lọc dữ liệu
                var users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final role = data['role'] ?? 'user';
                  final deleted = data['deleted'] ?? false;
                  
                  // Lọc theo trạng thái
                  bool matchesStatus = false;
                  if (filterStatus == 'active') {
                    matchesStatus = !deleted;
                  } else if (filterStatus == 'deleted') {
                    matchesStatus = deleted;
                  } else {
                    matchesStatus = true; // all
                  }
                  
                  // Lọc theo search query
                  bool matchesSearch = searchQuery.isEmpty ||
                      name.contains(searchQuery) ||
                      email.contains(searchQuery);
                  
                  // Lọc theo role
                  bool matchesRole = filterRole == 'all' || role == filterRole;
                  
                  return matchesSearch && matchesRole && matchesStatus;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Không tìm thấy người dùng nào',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;
                    
                    return UserListItem(
                      userId: userId,
                      userData: userData,
                      onRestore: () {
                        // Refresh danh sách sau khi khôi phục
                        setState(() {});
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UserListItem extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final VoidCallback? onRestore;

  const UserListItem({
    Key? key,
    required this.userId,
    required this.userData,
    this.onRestore,
  }) : super(key: key);

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> restoreUser(BuildContext context) async {
    final name = userData['name'] ?? 'người dùng này';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.green),
            SizedBox(width: 8),
            Text('Khôi phục tài khoản'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn khôi phục tài khoản "$name"?\n\n'
          'Người dùng sẽ có thể đăng nhập lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'deleted': false,
        'restoredAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã khôi phục tài khoản "$name" thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Gọi callback để refresh
        if (onRestore != null) {
          onRestore!();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khôi phục tài khoản: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = userData['name'] ?? 'Chưa có tên';
    final email = userData['email'] ?? 'Chưa có email';
    final role = userData['role'] ?? 'user';
    final photoUrl = userData['photoUrl'];
    final gender = userData['gender'] ?? 'Chưa rõ';
    final deleted = userData['deleted'] ?? false;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: deleted ? Colors.red[50] : Colors.white,
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: deleted ? Colors.grey[400] : Colors.grey[300],
              backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty && !deleted)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.toString().isEmpty || deleted)
                  ? Icon(
                      deleted ? Icons.block : Icons.person, 
                      color: deleted ? Colors.red[700] : Colors.grey[600]
                    )
                  : null,
            ),
            if (role == 'admin' && !deleted)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            if (deleted)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: deleted ? TextDecoration.lineThrough : null,
                  color: deleted ? Colors.grey[600] : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (deleted)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Vô hiệu hóa',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'admin' ? Colors.amber[100] : Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  role == 'admin' ? 'Admin' : 'User',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: role == 'admin' ? Colors.amber[900] : Colors.blue[900],
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, size: 14, color: deleted ? Colors.grey[500] : Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: deleted ? Colors.grey[500] : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.wc, size: 14, color: deleted ? Colors.grey[500] : Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  gender,
                  style: TextStyle(
                    fontSize: 12, 
                    color: deleted ? Colors.grey[500] : Colors.grey[700]
                  ),
                ),
              ],
            ),
            if (deleted && userData['deletedAt'] != null)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.red[700]),
                    SizedBox(width: 4),
                    Text(
                      'Bị xóa: ${formatDate(userData['deletedAt'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: deleted
            ? IconButton(
                icon: Icon(Icons.restore, color: Colors.green),
                onPressed: () => restoreUser(context),
                tooltip: 'Khôi phục tài khoản',
              )
            : IconButton(
                icon: Icon(Icons.arrow_forward_ios, size: 16),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailPage(
                        userId: userId,
                        userData: userData,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
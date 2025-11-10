import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_test/security_service.dart';

class SecurityAlertsPage extends StatefulWidget {
  const SecurityAlertsPage({Key? key}) : super(key: key);

  @override
  _SecurityAlertsPageState createState() => _SecurityAlertsPageState();
}

class _SecurityAlertsPageState extends State<SecurityAlertsPage> {
  Map<String, dynamic> stats = {};
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await SecurityService.getSecurityStats();
    setState(() {
      stats = data;
      isLoadingStats = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cảnh báo Bảo mật'),
        backgroundColor: Colors.red[700],
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Column(
        children: [
          // Thống kê tổng quan
          if (isLoadingStats)
            LinearProgressIndicator()
          else
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                children: [
                  Text(
                    'Thống kê 24h qua',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Đăng nhập sai',
                          stats['failedLogins24h']?.toString() ?? '0',
                          Icons.error_outline,
                          Colors.red,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Đăng nhập OK',
                          stats['successLogins24h']?.toString() ?? '0',
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Cảnh báo mới',
                          stats['unreadAlerts']?.toString() ?? '0',
                          Icons.notifications_active,
                          Colors.orange,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Tài khoản khóa',
                          stats['lockedAccounts']?.toString() ?? '0',
                          Icons.lock,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Danh sách cảnh báo
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: SecurityService.getUnreadSecurityAlerts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security,
                          size: 80,
                          color: Colors.green,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Không có cảnh báo mới! ✅',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Hệ thống đang hoạt động bình thường',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final alerts = snapshot.data!.docs;

                return ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alertDoc = alerts[index];
                    final alertData = alertDoc.data() as Map<String, dynamic>;
                    
                    return SecurityAlertCard(
                      alertId: alertDoc.id,
                      alertData: alertData,
                      onDismiss: () {
                        _loadStats(); // Refresh stats
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SecurityAlertCard extends StatelessWidget {
  final String alertId;
  final Map<String, dynamic> alertData;
  final VoidCallback? onDismiss;

  const SecurityAlertCard({
    Key? key,
    required this.alertId,
    required this.alertData,
    this.onDismiss,
  }) : super(key: key);

  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _markAsRead(BuildContext context) async {
    try {
      await SecurityService.markAlertAsRead(alertId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đánh dấu đã đọc'),
          backgroundColor: Colors.green,
        ),
      );
      
      if (onDismiss != null) {
        onDismiss!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = alertData['email'] ?? 'N/A';
    final failedAttempts = alertData['failedAttempts'] ?? 0;
    final timestamp = alertData['timestamp'];
    final emailSent = alertData['emailSent'] ?? false;
    final lockoutUntil = alertData['lockoutUntil'];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.red[50],
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red[700],
          child: Icon(Icons.warning, color: Colors.white, size: 20),
        ),
        title: Text(
          email,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red[900],
          ),
        ),
        subtitle: Text(
          '$failedAttempts lần đăng nhập sai • ${formatTimestamp(timestamp)}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: emailSent
            ? Tooltip(
                message: 'Email đã gửi',
                child: Icon(Icons.email, color: Colors.green[700], size: 20),
              )
            : Tooltip(
                message: 'Đang gửi email...',
                child: Icon(Icons.schedule_send, color: Colors.orange, size: 20),
              ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  Icons.email,
                  'Email',
                  email,
                ),
                _buildDetailRow(
                  Icons.error_outline,
                  'Số lần thất bại',
                  failedAttempts.toString(),
                ),
                _buildDetailRow(
                  Icons.access_time,
                  'Thời gian',
                  formatTimestamp(timestamp),
                ),
                if (lockoutUntil != null)
                  _buildDetailRow(
                    Icons.lock_clock,
                    'Khóa đến',
                    formatTimestamp(lockoutUntil),
                  ),
                _buildDetailRow(
                  emailSent ? Icons.check_circle : Icons.pending,
                  'Trạng thái email',
                  emailSent ? 'Đã gửi' : 'Đang xử lý',
                  valueColor: emailSent ? Colors.green[700] : Colors.orange[700],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _markAsRead(context),
                      icon: Icon(Icons.check, size: 16),
                      label: Text('Đánh dấu đã đọc'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
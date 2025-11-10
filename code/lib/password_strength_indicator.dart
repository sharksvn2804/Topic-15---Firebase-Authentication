import 'package:flutter/material.dart';

enum PasswordStrength { weak, medium, strong }

class PasswordStrengthResult {
  final PasswordStrength strength;
  final double score; // 0.0 to 1.0
  final List<String> suggestions;
  final Color color;
  final String label;

  PasswordStrengthResult({
    required this.strength,
    required this.score,
    required this.suggestions,
    required this.color,
    required this.label,
  });
}

class PasswordStrengthChecker {
  static PasswordStrengthResult check(String password) {
    if (password.isEmpty) {
      return PasswordStrengthResult(
        strength: PasswordStrength.weak,
        score: 0.0,
        suggestions: ['Vui lòng nhập mật khẩu'],
        color: Colors.grey,
        label: 'Chưa có',
      );
    }

    int score = 0;
    List<String> suggestions = [];

    // Kiểm tra độ dài
    if (password.length >= 8) {
      score += 20;
    } else {
      suggestions.add('Tăng độ dài lên ít nhất 8 ký tự');
    }

    if (password.length >= 12) {
      score += 10;
    }

    // Kiểm tra chữ thường
    if (password.contains(RegExp(r'[a-z]'))) {
      score += 15;
    } else {
      suggestions.add('Thêm chữ thường (a-z)');
    }

    // Kiểm tra chữ hoa
    if (password.contains(RegExp(r'[A-Z]'))) {
      score += 15;
    } else {
      suggestions.add('Thêm chữ in hoa (A-Z)');
    }

    // Kiểm tra số
    if (password.contains(RegExp(r'[0-9]'))) {
      score += 15;
    } else {
      suggestions.add('Thêm số (0-9)');
    }

    // Kiểm tra ký tự đặc biệt
    if (password.contains(RegExp(r'[!@#\$%\^&\*\(\),\.\?":\{\}\|<>\_\-\+=\[\]\\\/;`~]'))) {
      score += 25;
    } else {
      suggestions.add('Thêm ký tự đặc biệt (!@#\$%^&*...)');
    } 

    // Điểm thưởng cho mật khẩu rất dài
    if (password.length >= 16) {
      score += 10;
    }

    // Trừ điểm nếu có ký tự lặp liên tiếp
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
      score -= 10;
      suggestions.add('Tránh lặp ký tự quá nhiều');
    }

    // Trừ điểm nếu có số tuần tự
    if (RegExp(r'(012|123|234|345|456|567|678|789|890)').hasMatch(password)) {
      score -= 10;
      suggestions.add('Tránh dùng số tuần tự (123, 456...)');
    }

    // Giới hạn score từ 0-100
    score = score.clamp(0, 100);
    double normalizedScore = score / 100.0;

    // Xác định độ mạnh
    PasswordStrength strength;
    Color color;
    String label;

    if (score < 40) {
      strength = PasswordStrength.weak;
      color = Colors.red;
      label = 'Yếu';
    } else if (score < 70) {
      strength = PasswordStrength.medium;
      color = Colors.orange;
      label = 'Trung bình';
    } else {
      strength = PasswordStrength.strong;
      color = Colors.green;
      label = 'Mạnh';
      if (suggestions.isEmpty) {
        suggestions.add('Mật khẩu đủ mạnh! 💪');
      }
    }

    return PasswordStrengthResult(
      strength: strength,
      score: normalizedScore,
      suggestions: suggestions,
      color: color,
      label: label,
    );
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showSuggestions;

  const PasswordStrengthIndicator({
    Key? key,
    required this.password,
    this.showSuggestions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final result = PasswordStrengthChecker.check(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: result.score,
                  backgroundColor: Colors.grey[300],
                  color: result.color,
                  minHeight: 8,
                ),
              ),
            ),
            SizedBox(width: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: result.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: result.color, width: 1.5),
              ),
              child: Text(
                result.label,
                style: TextStyle(
                  color: result.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        
        // Suggestions
        if (showSuggestions && result.suggestions.isNotEmpty && password.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: result.strength == PasswordStrength.strong 
                    ? Colors.green[50] 
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: result.strength == PasswordStrength.strong 
                      ? Colors.green[200]! 
                      : Colors.orange[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        result.strength == PasswordStrength.strong 
                            ? Icons.check_circle 
                            : Icons.lightbulb_outline,
                        size: 16,
                        color: result.strength == PasswordStrength.strong 
                            ? Colors.green[700] 
                            : Colors.orange[700],
                      ),
                      SizedBox(width: 6),
                      Text(
                        result.strength == PasswordStrength.strong 
                            ? 'Tuyệt vời!' 
                            : 'Gợi ý cải thiện:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: result.strength == PasswordStrength.strong 
                              ? Colors.green[900] 
                              : Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  ...result.suggestions.map((suggestion) => Padding(
                    padding: EdgeInsets.only(left: 22, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 11,
                            color: result.strength == PasswordStrength.strong 
                                ? Colors.green[800] 
                                : Colors.orange[800],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 11,
                              color: result.strength == PasswordStrength.strong 
                                  ? Colors.green[800] 
                                  : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Widget TextField với password strength indicator tích hợp
class PasswordFieldWithStrength extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final bool showStrengthIndicator;
  final ValueChanged<String>? onChanged;

  const PasswordFieldWithStrength({
    Key? key,
    required this.controller,
    this.labelText = 'Mật khẩu',
    this.helperText,
    this.showStrengthIndicator = true,
    this.onChanged,
  }) : super(key: key);

  @override
  _PasswordFieldWithStrengthState createState() => _PasswordFieldWithStrengthState();
}

class _PasswordFieldWithStrengthState extends State<PasswordFieldWithStrength> {
  bool _obscureText = true;
  String _password = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _password = widget.controller.text;
    });
    if (widget.onChanged != null) {
      widget.onChanged!(_password);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPasswordChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          decoration: InputDecoration(
            labelText: widget.labelText,
            helperText: widget.helperText,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
          ),
        ),
        if (widget.showStrengthIndicator && _password.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: PasswordStrengthIndicator(
              password: _password,
              showSuggestions: true,
            ),
          ),
      ],
    );
  }
}
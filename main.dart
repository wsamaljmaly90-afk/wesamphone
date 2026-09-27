// =============================================================================
// WesamPhone - تطبيق الدردشة الجماعية (النسخة المحلية - بدون Firebase)
// جميع البيانات مخزنة محلياً على الجهاز باستخدام SharedPreferences
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

// =============================================================================
// أدوات مساعدة للتخزين المحلي
// =============================================================================
class LocalDB {
  static const _kUsers = 'wp_users_v1';
  static const _kSession = 'wp_session_v1';
  static const _kMessages = 'wp_messages_v1';

  // تشفير كلمة المرور باستخدام SHA-256 مع salt
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecondsSinceEpoch % 1000).toString();
  }

  // جلب قائمة المستخدمين
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveUsers(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsers, json.encode(users));
  }

  // حفظ/جلب الجلسة الحالية
  static Future<void> setSession(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_kSession);
    } else {
      await prefs.setString(_kSession, json.encode(user));
    }
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  // الرسائل
  static Future<List<Map<String, dynamic>>> getMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMessages);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMessages, json.encode(messages));
  }
}

// =============================================================================
// نقطة الانطلاق
// =============================================================================
void main() {
  runApp(const WesamPhoneApp());
}

class WesamPhoneApp extends StatelessWidget {
  const WesamPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WesamPhone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5AE0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF6A5AE0),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A5AE0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthWrapper(),
    );
  }
}

// =============================================================================
// مُغلف المصادقة - التحقق التلقائي من الجلسة
// =============================================================================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Map<String, dynamic>? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await LocalDB.getSession();
    if (mounted) {
      setState(() {
        _session = session;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6A5AE0).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 40,
                  color: Color(0xFF6A5AE0),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Color(0xFF6A5AE0)),
              const SizedBox(height: 16),
              Text('جاري التحميل...',
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      );
    }
    if (_session != null) {
      return ChatScreen(session: _session!);
    }
    return const AuthScreen();
  }
}

// =============================================================================
// شاشة تسجيل الدخول / إنشاء حساب
// =============================================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    try {
      final users = await LocalDB.getUsers();

      if (_isLogin) {
        // تسجيل دخول
        final user = users.firstWhere(
          (u) => u['email'] == email,
          orElse: () => {},
        );
        if (user.isEmpty) {
          _showError('لا يوجد حساب مرتبط بهذا البريد الإلكتروني');
          return;
        }
        final hashed = LocalDB.hashPassword(password, user['salt'] ?? '');
        if (hashed != user['password']) {
          _showError('كلمة المرور غير صحيحة');
          return;
        }
        // نجح الدخول
        final session = {
          'uid': user['uid'],
          'email': user['email'],
          'username': user['username'],
        };
        await LocalDB.setSession(session);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ChatScreen(session: session)),
          );
        }
      } else {
        // إنشاء حساب
        final exists = users.any((u) => u['email'] == email);
        if (exists) {
          _showError('هذا البريد الإلكتروني مستخدم بالفعل');
          return;
        }
        final salt = LocalDB.generateSalt();
        final hashed = LocalDB.hashPassword(password, salt);
        final uid = DateTime.now().millisecondsSinceEpoch.toString();
        final newUser = {
          'uid': uid,
          'email': email,
          'username': username,
          'password': hashed,
          'salt': salt,
          'createdAt': DateTime.now().toIso8601String(),
        };
        users.add(newUser);
        await LocalDB.saveUsers(users);

        final session = {
          'uid': uid,
          'email': email,
          'username': username,
        };
        await LocalDB.setSession(session);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ChatScreen(session: session)),
          );
        }
      }
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A5AE0).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 48,
                        color: Color(0xFF6A5AE0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'WesamPhone',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A5AE0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _isLogin ? 'سجّل دخولك للمتابعة' : 'أنشئ حسابك الجديد',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء إدخال اسم المستخدم';
                        }
                        if (v.trim().length < 2) {
                          return 'اسم المستخدم قصير جداً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'الرجاء إدخال البريد الإلكتروني';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'البريد الإلكتروني غير صالح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'الرجاء إدخال كلمة المرور';
                      }
                      if (v.length < 4) {
                        return 'كلمة المرور قصيرة جداً (4 أحرف على الأقل)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _formKey.currentState?.reset();
                                });
                              },
                        child: Text(_isLogin ? 'إنشاء حساب' : 'تسجيل الدخول'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// شاشة غرفة الدردشة
// =============================================================================
class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const ChatScreen({super.key, required this.session});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // تحديث تلقائي كل ثانية لمحاكاة الرسائل المباشرة
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await LocalDB.getMessages();
    if (mounted) {
      setState(() {
        _messages = msgs;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final newMsg = {
      'uid': widget.session['uid'],
      'username': widget.session['username'],
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final msgs = await LocalDB.getMessages();
      msgs.add(newMsg);
      // نحتفظ بآخر 500 رسالة فقط
      if (msgs.length > 500) {
        msgs.removeRange(0, msgs.length - 500);
      }
      await LocalDB.saveMessages(msgs);
      _messageController.clear();
      await _loadMessages();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الرسالة: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await LocalDB.setSession(null);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.isNegative) return 'الآن';
      if (diff.inSeconds < 30) return 'الآن';
      if (diff.inMinutes < 1) return 'قبل لحظات';
      if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
      if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = widget.session['uid'] ?? '';
    final currentUsername = widget.session['username'] ?? 'مستخدم';

    // ترتيب الرسائل تنازلياً (الأحدث أولاً)
    final sortedMessages = List<Map<String, dynamic>>.from(_messages)
      ..sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'WesamPhone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A5AE0),
              ),
            ),
            Text(
              'غرفة الدردشة العامة',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF6A5AE0).withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFF6A5AE0)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مرحباً بك، $currentUsername',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6A5AE0),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sortedMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد رسائل بعد',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'كن أول من يبدأ المحادثة!',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: sortedMessages.length,
                      itemBuilder: (context, index) {
                        final msg = sortedMessages[index];
                        final isMe = (msg['uid'] ?? '').toString() == currentUid;
                        return MessageBubble(
                          text: (msg['text'] ?? '').toString(),
                          username: (msg['username'] ?? 'مستخدم').toString(),
                          timestamp: msg['timestamp']?.toString() ?? '',
                          isMe: isMe,
                          timeFormatter: _formatTime,
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك هنا...',
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF6A5AE0),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sendMessage,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// فقاعة الرسالة
// =============================================================================
class MessageBubble extends StatelessWidget {
  final String text;
  final String username;
  final String timestamp;
  final bool isMe;
  final String Function(String?) timeFormatter;

  const MessageBubble({
    super.key,
    required this.text,
    required this.username,
    required this.timestamp,
    required this.isMe,
    required this.timeFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF6A5AE0);
    final alignment =
        isMe ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd;
    final bubbleColor = isMe ? primary : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;
    final timeColor =
        isMe ? Colors.white.withOpacity(0.75) : Colors.grey.shade500;

    final radius = isMe
        ? const BorderRadius.only(
            topRight: Radius.circular(16),
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(16),
            topLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  username,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: radius,
                ),
                child: Text(
                  text,
                  style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  timeFormatter(timestamp),
                  style: TextStyle(fontSize: 10, color: timeColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

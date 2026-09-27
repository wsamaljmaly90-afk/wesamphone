// =============================================================================
// WesamPhone & Academy - المنصة الرقمية المتكاملة للبرمجة والتعليم
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ota_update/OtaUpdate.dart';

void main() {
  runApp(const WesamEnterpriseApp());
}

class WesamEnterpriseApp extends StatelessWidget {
  const WesamEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شركة وسام للبرمجة والتعليم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C3BFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF4F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF5C3BFF), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5C3BFF),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
// إدارة البيانات الجلسات والـ PIN التلقائي
// =============================================================================
class LocalDB {
  static const _kUsers = 'wp_users_v2';
  static const _kSession = 'wp_session_v2';
  static const _kMessages = 'wp_messages_v2';
  static const _kPinCode = 'wp_user_pin';

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

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

  static Future<void> setPinCode(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinCode, pin);
  }

  static Future<String?> getPinCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPinCode);
  }

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
// بوابة التحقق والتحقق بـ PIN
// =============================================================================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Map<String, dynamic>? _session;
  String? _pinCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await LocalDB.getSession();
    final pin = await LocalDB.getPinCode();
    if (mounted) {
      setState(() {
        _session = session;
        _pinCode = pin;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF5C3BFF))),
      );
    }
    if (_session != null) {
      if (_pinCode != null) {
        return PinLockScreen(session: _session!, savedPin: _pinCode!);
      }
      return MainNavigationScreen(session: _session!);
    }
    return const AuthScreen();
  }
}

// =============================================================================
// شاشة تأكيد الـ PIN للدخول السريع
// =============================================================================
class PinLockScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final String savedPin;
  const PinLockScreen({super.key, required this.session, required this.savedPin});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _pinController = TextEditingController();

  void _verifyPin() {
    if (_pinController.text == widget.savedPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainNavigationScreen(session: widget.session)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز السر غير صحيح!'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 80, color: Color(0xFF5C3BFF)),
              const SizedBox(height: 16),
              Text('أهلاً بعودتك، ${widget.session['username']}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('أدخل رمز السر الخاص بك للدخول للحساب'),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(hintText: '••••'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifyPin,
                  child: const Text('دخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// شاشة إنشاء الحساب والدخول التلقائي بجوجل
// =============================================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final session = {
          'uid': googleUser.id,
          'email': googleUser.email,
          'username': googleUser.displayName ?? 'طالب جديد',
          'role': 'Student',
        };
        await LocalDB.setSession(session);
        _registerNewInstallNotification(googleUser.displayName ?? 'مستخدم جديد');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainNavigationScreen(session: session)),
          );
        }
      }
    } catch (e) {
      _showError('خطأ أثناء الاتصال بحساب جوجل: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _registerNewInstallNotification(String name) async {
    final users = await LocalDB.getUsers();
    users.add({
      'name': name,
      'date': DateTime.now().toIso8601String(),
      'status': 'نشط ومثبت حديثاً'
    });
    await LocalDB.saveUsers(users);
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();
    final pin = _pinController.text.trim();

    try {
      if (_isRegister) {
        if (pin.length < 4) {
          _showError('الرجاء إدخال رمز سر مكون من 4 أرقام');
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
        };

        final users = await LocalDB.getUsers();
        users.add(newUser);
        await LocalDB.saveUsers(users);
        await LocalDB.setPinCode(pin);

        final session = {'uid': uid, 'email': email, 'username': username};
        await LocalDB.setSession(session);
        _registerNewInstallNotification(username);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainNavigationScreen(session: session)),
          );
        }
      } else {
        final users = await LocalDB.getUsers();
        final user = users.firstWhere((u) => u['email'] == email, orElse: () => {});
        if (user.isEmpty) {
          _showError('الحساب غير موجود!');
          return;
        }
        final hashed = LocalDB.hashPassword(password, user['salt'] ?? '');
        if (hashed != user['password']) {
          _showError('كلمة المرور خاطئة');
          return;
        }
        final session = {'uid': user['uid'], 'email': user['email'], 'username': user['username']};
        await LocalDB.setSession(session);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainNavigationScreen(session: session)),
          );
        }
      }
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                height: 100,
                width: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFEAFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.code_rounded, size: 50, color: Color(0xFF5C3BFF)),
              ),
              const SizedBox(height: 16),
              const Text(
                'شركة وسام للبرمجة والتعليم',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5C3BFF)),
              ),
              const SizedBox(height: 8),
              const Text(
                'منصتك الذكية لتطوير التطبيقات والتعلم الأكاديمي',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              if (_isRegister) ...[
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 12),
              if (_isRegister) ...[
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'تعيين رمز السر (PIN للوصول السريع)',
                    prefixIcon: Icon(Icons.pin),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: Text(_isRegister ? 'إنشاء حساب جديد' : 'تسجيل الدخول'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                label: const Text('تسجيل الدخول بقوقل (للطلاب مباشرة)'),
                onPressed: _isLoading ? null : _signInWithGoogle,
              ),
              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister ? 'لديك حساب بالفعل؟ سجل دخولك' : 'تريد إنشاء حساب جديد؟ اضغط هنا'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// الشاشة الرئيسية المتكاملة والشريط السفلي
// =============================================================================
class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const MainNavigationScreen({super.key, required this.session});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeDialog());
  }

  // رسالة ترحيب تلقائية عند فتح التطبيق
  void _showWelcomeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF5C3BFF)),
            SizedBox(width: 8),
            Text('مرحباً بك!'),
          ],
        ),
        content: Text(
          'أهلاً بك في شركة وسام للبرمجة والتعليم البرمجي.\nيسعدنا انضمامك معنا للاستفادة من خدماتنا التكنولوجية والكورسات التعليمية.',
          style: TextStyle(color: Colors.grey.shade800),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ابدأ الاستكشاف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ChatTab(session: widget.session),
      const LearningTab(),
      const PortfolioTab(),
      const TeamTab(),
      const UsersDashboardTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('شركة وسام للبرمجة', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5C3BFF))),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await LocalDB.setSession(null);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF5C3BFF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'الدردشة'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'التعليم'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'أعمالنا'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'الفريق'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'المشتركون'),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. قسم الدردشة والتواصل
// =============================================================================
class ChatTab extends StatefulWidget {
  final Map<String, dynamic> session;
  const ChatTab({super.key, required this.session});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _msgController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final msgs = await LocalDB.getMessages();
    setState(() => _messages = msgs);
  }

  void _send() async {
    if (_msgController.text.trim().isEmpty) return;
    final msgs = await LocalDB.getMessages();
    msgs.add({
      'username': widget.session['username'],
      'text': _msgController.text.trim(),
      'time': DateTime.now().toString().substring(11, 16)
    });
    await LocalDB.saveMessages(msgs);
    _msgController.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(m['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5C3BFF))),
                  subtitle: Text(m['text'] ?? ''),
                  trailing: Text(m['time'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: 'اكتب استفسارك هنا...'))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.send, color: Color(0xFF5C3BFF)), onPressed: _send),
            ],
          ),
        )
      ],
    );
  }
}

// =============================================================================
// 2. قسم تعليم أساسيات البرمجة
// =============================================================================
class LearningTab extends StatelessWidget {
  const LearningTab({super.key});

  @override
  Widget build(BuildContext context) {
    final courses = [
      {'title': 'أساسيات Flutter & Dart', 'level': 'مبتدئ', 'lessons': '12 درس', 'icon': Icons.flutter_dash},
      {'title': 'أساسيات البرمجة بـ C++', 'level': 'مبتدئ إلى متوسط', 'lessons': '20 درس', 'icon': Icons.code},
      {'title': 'قواعد البيانات SQL & Oracle', 'level': 'متوسط', 'lessons': '15 درس', 'icon': Icons.storage},
      {'title': 'تطوير تطبيقات الويب React', 'level': 'متقدم', 'lessons': '18 درس', 'icon': Icons.web},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courses.length,
      itemBuilder: (context, i) {
        final c = courses[i];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFEFEAFF), child: Icon(c['icon'] as IconData, color: const Color(0xFF5C3BFF))),
            title: Text(c['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('المستوى: ${c['level']} • ${c['lessons']}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم فتح مسار: ${c['title']}')),
              );
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// 3. قسم أعمالنا
// =============================================================================
class PortfolioTab extends StatelessWidget {
  const PortfolioTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نظام إدارة المستشفيات والمراكز الطبية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5C3BFF))),
                SizedBox(height: 8),
                Text('نظام متكامل لإدارة العيادات، الطوارئ، الصيدليات وقواعد البيانات الضخمة.'),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تطبيق WesamPhone للشبكات المحلية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5C3BFF))),
                SizedBox(height: 8),
                Text('تطبيق محادثة ونقل بيانات متطور يعتمد التخزين المحلي الآمن.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 4. قسم الفريق المختص
// =============================================================================
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    final team = [
      {'name': 'وسام محمد الجمالي', 'role': 'كبير مهندسي البرمجيات والمؤسس', 'tech': 'Flutter, C++, Oracle'},
      {'name': 'فريق الدعم الفني والتعليم', 'role': 'إشراف ومتابعة الطلاب', 'tech': 'Python, SQL, Web'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: team.length,
      itemBuilder: (context, i) {
        final t = team[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(t['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${t['role']}\nالتقنيات: ${t['tech']}'),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 5. شاشة المشتركين الجدد والتحقق من التثبيت
// =============================================================================
class UsersDashboardTab extends StatefulWidget {
  const UsersDashboardTab({super.key});

  @override
  State<UsersDashboardTab> createState() => _UsersDashboardTabState();
}

class _UsersDashboardTabState extends State<UsersDashboardTab> {
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    final users = await LocalDB.getUsers();
    setState(() => _users = users);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _users.isEmpty
          ? const Center(child: Text('لا يوجد مشتركين مسجلين حالياً'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, i) {
                final u = _users[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_user, color: Colors.green),
                    title: Text(u['name'] ?? u['username'] ?? 'مستخدم جديد'),
                    subtitle: Text('حالة التثبيت: ${u['status'] ?? 'مسجل ومثبت التطبيق'}'),
                  ),
                );
              },
            ),
    );
  }
}

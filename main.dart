import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

void main() {
  runApp(const WesamEnterpriseApp());
}

class WesamEnterpriseApp extends StatelessWidget {
  const WesamEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وسام للتطوير البرمجي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF00CEC9),
          surface: const Color(0xFFF8F9FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
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

/* ==================== قاعدة البيانات المحلية ==================== */
class LocalDB {
  static const _kUsers = 'wp_users_v4';
  static const _kSession = 'wp_session_v4';
  static const _kMessages = 'wp_messages_v4';

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() => DateTime.now().millisecondsSinceEpoch.toString();

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

/* ==================== محدد الجلسة ==================== */
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
    _check();
  }

  void _check() async {
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
      );
    }
    if (_session != null) {
      return MainDashboardScreen(session: _session!);
    }
    return const GlassAuthScreen();
  }
}

/* ==================== شاشة تسجيل الدخول الاحترافية ==================== */
class GlassAuthScreen extends StatefulWidget {
  const GlassAuthScreen({super.key});

  @override
  State<GlassAuthScreen> createState() => _GlassAuthScreenState();
}

class _GlassAuthScreenState extends State<GlassAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegister = false;

  void _quickGuestLogin() async {
    final session = {
      'uid': 'guest_${DateTime.now().millisecondsSinceEpoch}',
      'email': 'guest@wesam.dev',
      'username': 'زائر مميز',
    };
    await LocalDB.setSession(session);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainDashboardScreen(session: session)),
      );
    }
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال جميع البيانات المطلوبة')),
      );
      return;
    }

    if (_isRegister) {
      final salt = LocalDB.generateSalt();
      final hashed = LocalDB.hashPassword(password, salt);
      final uid = DateTime.now().millisecondsSinceEpoch.toString();

      final users = await LocalDB.getUsers();
      users.add({
        'uid': uid,
        'email': email,
        'username': name.isEmpty ? 'مستخدم جديد' : name,
        'password': hashed,
        'salt': salt,
      });
      await LocalDB.saveUsers(users);

      final session = {'uid': uid, 'email': email, 'username': name.isEmpty ? 'مستخدم جديد' : name};
      await LocalDB.setSession(session);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainDashboardScreen(session: session)),
        );
      }
    } else {
      final users = await LocalDB.getUsers();
      final user = users.firstWhere((u) => u['email'] == email, orElse: () => {});
      if (user.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الحساب غير موجود! يمكنك الدخول كزائر أو إنشاء حساب')),
        );
        return;
      }
      final hashed = LocalDB.hashPassword(password, user['salt'] ?? '');
      if (hashed != user['password']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كلمة المرور غير صحيحة')),
        );
        return;
      }
      final session = {'uid': user['uid'], 'email': user['email'], 'username': user['username']};
      await LocalDB.setSession(session);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainDashboardScreen(session: session)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE), Color(0xFF00CEC9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C5CE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'وسام للتطوير البرمجي',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.black, color: Color(0xFF2D3436)),
                    ),
                    const Text(
                      'Wesam Software Solutions',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 28),
                    if (_isRegister) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'الاسم الكامل',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'البريد الإلكتروني',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                        ),
                        onPressed: _submit,
                        child: Text(
                          _isRegister ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _quickGuestLogin,
                        icon: const Icon(Icons.rocket_launch, color: Color(0xFF6C5CE7)),
                        label: const Text('دخول سريع تجريبي', style: TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister ? 'لديك حساب بالفعل؟ سجل دخولك' : 'ليس لديك حساب؟ انقر هنا للتسجيل',
                        style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ==================== الشاشة الرئيسية الخرافية ==================== */
class MainDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const MainDashboardScreen({super.key, required this.session});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(session: widget.session),
      const ServicesTab(),
      ChatTab(session: widget.session),
      const ProfileTab(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF6C5CE7),
          unselectedItemColor: Colors.grey.shade400,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Colors.transparent,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.widgets_rounded), label: 'الخدمات'),
            BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'المحادثة'),
            BottomNavigationBarItem(icon: Icon(Icons.person_pin_rounded), label: 'الملف الشخصي'),
          ],
        ),
      ),
    );
  }
}

/* ==================== تبويب الرئيسية ==================== */
class HomeTab extends StatelessWidget {
  final Map<String, dynamic> session;
  const HomeTab({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مرحباً بك 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          session['username'] ?? 'الزائر',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                      child: const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Color(0xFF6C5CE7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // بطاقة إحصائيات زجاجية
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(number: '+15', label: 'مشروع ناجح'),
                      _StatDivider(),
                      _StatItem(number: '100%', label: 'دعم فني'),
                      _StatDivider(),
                      _StatItem(number: 'v1.0', label: 'الإصدار'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const Text('خدماتنا السريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _QuickCard(icon: Icons.mobile_friendly, title: 'تطبيقات الجوال', color: const Color(0xFF00CEC9))),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickCard(icon: Icons.computer, title: 'أنظمة سطح المكتب', color: const Color(0xFFFF7675))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _QuickCard(icon: Icons.storage_rounded, title: 'قواعد البيانات', color: const Color(0xFF6C5CE7))),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickCard(icon: Icons.school_rounded, title: 'الدورات البرمجية', color: const Color(0xFFFDCB6E))),
                ],
              ),
              const SizedBox(height: 28),
              const Text('أحدث الأعمال والأنظمة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const SizedBox(height: 14),
              _ProjectCard(
                title: 'تطبيق WesamPhone المحلي',
                desc: 'تطبيق درشات وأنظمة متكاملة تعمل بدون الحاجة لإنترنت خارجي وبأعلى معايير الأمان.',
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF6C5CE7),
              ),
              const SizedBox(height: 12),
              _ProjectCard(
                title: 'نظام إدارة المراكز والمستشفيات',
                desc: 'نظام إلكتروني شامل لإدارة المستشفيات، العيادات، الطوارئ والحسابات.',
                icon: Icons.local_hospital_outlined,
                color: const Color(0xFF00CEC9),
              ),
            ]),
          ),
        )
      ],
    );
  }
}

/* ==================== عناصر الواجهة الصغيرة ==================== */
class _StatItem extends StatelessWidget {
  final String number;
  final String label;
  const _StatItem({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(number, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) {
    return Container(height: 24, width: 1, color: Colors.white30);
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _QuickCard({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const _ProjectCard({required this.title, required this.desc, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/* ==================== باقي التبويبات ==================== */
class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخدمات والكورسات', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _serviceTile('تطوير البرمجيات بحسب الطلب', 'تصميم وبناء كافة التطبيقات والمواقع بأعلى جودة.', Icons.code_rounded),
          _serviceTile('دورات تعليمية في C++ & Flutter', 'شروحات أكاديمية وتطبيقات عملية متكاملة.', Icons.school_rounded),
          _serviceTile('تصميم واستعلامات SQL & Oracle', 'بناء وتصميم الجداول والمخططات وقواعد البيانات.', Icons.storage_rounded),
        ],
      ),
    );
  }

  Widget _serviceTile(String title, String sub, IconData icon) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.1), child: Icon(icon, color: const Color(0xFF6C5CE7))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
      ),
    );
  }
}

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
    return Scaffold(
      appBar: AppBar(title: const Text('غرفة المحادثة المحلية', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isMe = m['username'] == widget.session['username'];
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF6C5CE7) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['username'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isMe ? Colors.white70 : const Color(0xFF6C5CE7))),
                        const SizedBox(height: 4),
                        Text(m['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF6C5CE7),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(radius: 45, backgroundColor: Color(0xFF6C5CE7), child: Icon(Icons.person, size: 50, color: Colors.white)),
              const SizedBox(height: 16),
              const Text('وسام محمد الجمالي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('مطوّر ومبتكر أنظمة برمجية', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await LocalDB.setSession(null);
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const GlassAuthScreen()), (route) => false);
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

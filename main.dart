import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// === الاستيرادات المهمة التي كانت مفقودة وتسببت بالخطأ ===
import 'package:firebase_core/firebase_core.dart';
import 'package0:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

/* ==================== دالة التشغيل الرئيسية ==================== */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('ملاحظة: تعذر تهيئة Firebase: $e');
  }

  runApp(const WesamEnterpriseApp());
}

/* ==================== كلاس التسجيل التلقائي في الخادم ==================== */
class ServerLogger {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<void> autoRegisterDevice(String username) async {
    try {
      String deviceModel = 'غير معروف';
      String deviceBrand = 'غير معروف';
      String androidVersion = 'غير معروف';
      String deviceId = DateTime.now().millisecondsSinceEpoch.toString();

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        deviceBrand = androidInfo.brand;
        androidVersion = androidInfo.version.release;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
        deviceBrand = 'Apple';
        androidVersion = iosInfo.systemVersion;
        deviceId = iosInfo.identifierForVendor ?? deviceId;
      }

      await _db.collection('app_users').doc(deviceId).set({
        'username': username,
        'deviceBrand': deviceBrand,
        'deviceModel': deviceModel,
        'osVersion': androidVersion,
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'installedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('خطأ في مزامنة البيانات: $e');
    }
  }

  static Future<void> syncProfileToServer(Map<String, String> profile) async {
    try {
      String deviceId = '';
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      }

      if (deviceId.isNotEmpty) {
        await _db.collection('app_users').doc(deviceId).set({
          'profileData': profile,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('خطأ في تحديث البروفايل: $e');
    }
  }
}

/* ==================== التطبيق الرئيسي والتنسيق ==================== */
class WesamEnterpriseApp extends StatelessWidget {
  const WesamEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مؤسسة وسام البرمجية الشاملة',
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

/* ==================== إدارة البيانات والجلسة ==================== */
class LocalDB {
  static const _kSession = 'wp_session_v6';
  static const _kProfile = 'wp_profile_v6';

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

  static Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfile);
    if (raw == null || raw.isEmpty) {
      return {
        'name': 'مستخدم جديد',
        'email': 'user@example.com',
        'role': 'مطور / أخصائي أنظمة',
        'phone': '+967 000000000',
        'bio': 'الحلول البرمجية، أنظمة سطح المكتب، قواعد البيانات وتطبيقات الجوال.',
      };
    }
    try {
      return Map<String, String>.from(json.decode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveProfile(Map<String, String> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, json.encode(profile));
    ServerLogger.syncProfileToServer(profile);
  }
}

/* ==================== قاعدة معرفية للبحث الشامل ==================== */
class KnowledgeBase {
  static final List<Map<String, String>> articles = [
    {
      'title': 'أساسيات C++ والمؤشرات (Pointers)',
      'category': 'لغات البرمجة',
      'target': 'ل للمبتدئين والطلاب',
      'content': 'تغطي لغة C++ إدارة الذاكرة المباشرة عبر الـ Pointers والـ Dynamic Memory Allocation.'
    },
    {
      'title': 'تطوير التطبيقات عبر Flutter & Dart',
      'category': 'تطوير الجوال',
      'target': 'للمتوسطين والمحترفين',
      'content': 'إطار عمل Flutter يسمح لك ببناء تطبيقات ذات كود موحد يعمل على Android و iOS و Desktop.'
    },
    {
      'title': 'تصميم قواعد البيانات العلاقية (RDBMS & SQL)',
      'category': 'قواعد البيانات',
      'target': 'للجميع',
      'content': 'شرح المخططات الهيكلية (ERD)، العلاقات (1-to-N, N-to-M)، صياغة المفاتيح الأساسية والأجنبية.'
    },
    {
      'title': 'الذكاء الاصطناعي وتعلم الآلة (Python AI)',
      'category': 'الذكاء الاصطناعي',
      'target': 'للباحثين والدكاترة',
      'content': 'استخدام مكتبات Python المتقدمة مثل NumPy, Pandas, Scikit-Learn و TensorFlow.'
    },
    {
      'title': 'أنظمة إدارة الصيدليات والمستشفيات',
      'category': 'أنظمة المؤسسات',
      'target': 'للمستخدمين والشركات',
      'content': 'حلول برمجية لإدارة السجلات الطبية، المبيعات، المخزون، والفواتير.'
    },
    {
      'title': 'الربط الشبكي المحلي وبروتوكولات Socket',
      'category': 'الشبكات والأمان',
      'target': 'للمتقدمين والمهندسين',
      'content': 'بناء تطبيقات محادثة ونقل بيانات داخل الشبكات المغلقة (LAN) باستخدام TCP/IP Sockets.'
    },
  ];

  static List<Map<String, String>> search(String query) {
    if (query.trim().isEmpty) return articles;
    final q = query.toLowerCase();
    return articles.where((a) {
      return a['title']!.toLowerCase().contains(q) ||
             a['category']!.toLowerCase().contains(q) ||
             a['content']!.toLowerCase().contains(q) ||
             a['target']!.toLowerCase().contains(q);
    }).toList();
  }
}

/* ==================== محدد التوثيق والتثبيت ==================== */
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

  void _checkSession() async {
    final session = await LocalDB.getSession();
    if (session != null) {
      ServerLogger.autoRegisterDevice(session['username'] ?? 'مستخدم محلي');
    }
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

/* ==================== شاشة الدخول والتسجيل ==================== */
class GlassAuthScreen extends StatefulWidget {
  const GlassAuthScreen({super.key});

  @override
  State<GlassAuthScreen> createState() => _GlassAuthScreenState();
}

class _GlassAuthScreenState extends State<GlassAuthScreen> {
  final _userController = TextEditingController(text: 'wesam');

  void _login() async {
    final username = _userController.text.trim().isEmpty ? 'المستخدم' : _userController.text.trim();
    
    final session = {
      'uid': 'usr_enterprise',
      'username': username,
      'loginAt': DateTime.now().toString(),
    };
    
    await LocalDB.setSession(session);
    await ServerLogger.autoRegisterDevice(username);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainDashboardScreen(session: session)),
      );
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
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(color: Color(0xFF6C5CE7), shape: BoxShape.circle),
                      child: const Icon(Icons.business_center_rounded, size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('منصة وسام العملاقة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2D3436))),
                    const SizedBox(height: 6),
                    const Text('مرجع الطلاب، الدكاترة، المطورين والمستخدمين', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم أو المعرف',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _login,
                        child: const Text('دخول المنصة الشاملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
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

/* ==================== لوحة التحكم والتنقل الرئيسي ==================== */
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
      HomeTab(session: widget.session, onNavigateToProfile: () => setState(() => _currentIndex = 4)),
      const UniversalSearchTab(),
      const ServicesTab(),
      const AIChatTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
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
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'البحث الشامل'),
            BottomNavigationBarItem(icon: Icon(Icons.apps_rounded), label: 'الأنظمة والخدمات'),
            BottomNavigationBarItem(icon: Icon(Icons.psychology_rounded), label: 'الرد الآلي والدعم'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'الملف الشخصي'),
          ],
        ),
      ),
    );
  }
}

/* ==================== الشاشة الرئيسية ==================== */
class HomeTab extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onNavigateToProfile;

  const HomeTab({super.key, required this.session, required this.onNavigateToProfile});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
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
                        const Text('مرحباً بك في الشركة الشاملة 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(
                          session['username'] ?? 'wesam',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: onNavigateToProfile,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                        child: const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF6C5CE7)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(number: '24/7', label: 'فريق معتمد'),
                      _StatDivider(),
                      _StatItem(number: '100%', label: 'دقة الرد الآلي'),
                      _StatDivider(),
                      _StatItem(number: 'شامل', label: 'كل التخصصات'),
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
              const Text('أقسام المنصة الرئيسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _InteractiveQuickCard(
                      icon: Icons.school_rounded,
                      title: 'مسارات الطلاب والمبتدئين',
                      color: const Color(0xFF00CEC9),
                      onTap: () => _openCategory(context, 'المبتدئين والطلاب'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InteractiveQuickCard(
                      icon: Icons.code_rounded,
                      title: 'أدوات المطورين والمتوسطين',
                      color: const Color(0xFFFF7675),
                      onTap: () => _openCategory(context, 'المطورين'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InteractiveQuickCard(
                      icon: Icons.biotech_rounded,
                      title: 'أبحاث الدكاترة والمتقدمين',
                      color: const Color(0xFF6C5CE7),
                      onTap: () => _openCategory(context, 'الدكاترة والباحثين'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InteractiveQuickCard(
                      icon: Icons.support_agent_rounded,
                      title: 'خدمات المستخدمين والفريق',
                      color: const Color(0xFFFDCB6E),
                      onTap: () => _openCategory(context, 'الفريق والدعم'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text('الأعمال والحلول المتاحة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const SizedBox(height: 14),
              _InteractiveProjectCard(
                title: 'نظام WesamPhone الشبكي العملاق',
                desc: 'تطبيق وإدارة محادثات كاملة تعمل داخل الأنظمة والمؤسسات بدون إنترنت مع أمان فائق.',
                icon: Icons.security_rounded,
                color: const Color(0xFF6C5CE7),
                onTap: () => _openDetail(context, 'نظام WesamPhone', 'نظام محادثات وشبكات محلية ضخم مخصص للمؤسسات والمستشفيات والجامعات.'),
              ),
              const SizedBox(height: 12),
              _InteractiveProjectCard(
                title: 'مكتبة الأكواد والمشاريع المكتملة',
                desc: 'شروحات وأكواد جاهزة للبناء والتنفيذ لمشاريع التخرج والأنظمة التجارية.',
                icon: Icons.folder_special_rounded,
                color: const Color(0xFF00CEC9),
                onTap: () => _openDetail(context, 'مكتبة المشاريع', 'تضم أكثر من 100 مشروع مكتمل بـ Flutter, C++, Python, SQL.'),
              ),
            ]),
          ),
        )
      ],
    );
  }

  void _openCategory(BuildContext context, String cat) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailScreen(categoryName: cat)));
  }

  void _openDetail(BuildContext context, String title, String desc) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(title: title, content: desc)));
  }
}

/* ==================== محرك البحث الشامل ==================== */
class UniversalSearchTab extends StatefulWidget {
  const UniversalSearchTab({super.key});

  @override
  State<UniversalSearchTab> createState() => _UniversalSearchTabState();
}

class _UniversalSearchTabState extends State<UniversalSearchTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = KnowledgeBase.search(_query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('محرك البحث الشامل لكافة المجالات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن أي شيء (C++, Flutter, SQL, أبحاث, أنظمة...)...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6C5CE7)),
                filled: true,
                fillColor: const Color(0xFFF4F6F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('لم يتم العثور على نتائج، جرب كلمات أخرى مثل: C++ أو SQL'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final item = results[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Chip(label: Text(item['category']!, style: const TextStyle(fontSize: 10)), backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.1)),
                                  const SizedBox(width: 8),
                                  Chip(label: Text(item['target']!, style: const TextStyle(fontSize: 10)), backgroundColor: const Color(0xFF00CEC9).withOpacity(0.1)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(item['content']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => DetailScreen(title: item['title']!, content: item['content']!)),
                            );
                          },
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

/* ==================== الخدمات والأنظمة المتكاملة ==================== */
class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جميع الأنظمة والخدمات المتاحة', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildServiceCard(context, 'تطبيقات الجوال الذكية', 'بناء تطبيقات متكاملة مع الربط بالمستودعات والخوادم.', Icons.phone_android),
          _buildServiceCard(context, 'أنظمة سطح المكتب المتقدمة', 'برامج إدارة المبيعات والمستشفيات والجامعات.', Icons.desktop_windows),
          _buildServiceCard(context, 'هيكلة واستعلامات قواعد البيانات', 'تصميم ERD واستعلامات SQL سريعة وآمنة.', Icons.storage),
          _buildServiceCard(context, 'استشارات ومشاريع تخرج الأكاديمية', 'مساعدة الطلاب والدكاترة في التحليل والتنفيذ.', Icons.grade),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String desc, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.1), child: Icon(icon, color: const Color(0xFF6C5CE7))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(title: title, content: '$desc\n\nيوفر فريقنا المعتمد خدمة كاملة لهذه التقنية بضمان وبأعلى جودة.')));
        },
      ),
    );
  }
}

/* ==================== الرد الآلي والدعم الفني المعتمد ==================== */
class AIChatTab extends StatefulWidget {
  const AIChatTab({super.key});

  @override
  State<AIChatTab> createState() => _AIChatTabState();
}

class _AIChatTabState extends State<AIChatTab> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text': 'مرحباً بك! أنا الرد الآلي المباشر لمؤسسة وسام البرمجية. اسألني عن أي لغة، مشروع، أو خدمة وسأجيبك فوراً أو أصلك بالفريق المعتمد!'
    }
  ];

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': t});
      _controller.clear();
    });

    Timer(const Duration(milliseconds: 500), () {
      String ans = 'تم استلام استفسارك حول: "$t". يقوم محرك الرد الآلي بفهرسة الإجابة وسنقوم بتزويدك بتفاصيلها.';
      if (t.contains('برمجة') || t.contains('كود')) {
        ans = 'لدينا قسم كامل للبرمجة يشمل C++, Flutter, Python, و SQL. يمكنك استخدام محرك البحث الشامل للوصول لكافة الشروحات!';
      } else if (t.contains('فريق') || t.contains('دعم')) {
        ans = 'فريقنا المعتمد متواجد 24/7 لخدمتك وتلبية احتياجاتك البرمجية والجامعية.';
      }

      setState(() {
        _messages.add({'sender': 'bot', 'text': ans});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرد الآلي والدعم الفني المعتمد', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF6C5CE7) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                    ),
                    child: Text(m['text']!, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'اسأل الرد الآلي عن أي شيء...',
                      filled: true,
                      fillColor: const Color(0xFFF4F6F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF6C5CE7)),
                  onPressed: _send,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

/* ==================== الملف الشخصي المتكامل ==================== */
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, String> _prof = {};
  bool _loading = true;

  final _nameC = TextEditingController();
  final _roleC = TextEditingController();
  final _phoneC = TextEditingController();
  final _bioC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final p = await LocalDB.getProfile();
    setState(() {
      _prof = p;
      _nameC.text = p['name'] ?? '';
      _roleC.text = p['role'] ?? '';
      _phoneC.text = p['phone'] ?? '';
      _bioC.text = p['bio'] ?? '';
      _loading = false;
    });
  }

  void _save() async {
    final updated = {
      'name': _nameC.text,
      'role': _roleC.text,
      'phone': _phoneC.text,
      'email': _prof['email'] ?? '',
      'bio': _bioC.text,
    };
    await LocalDB.saveProfile(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات ملفك الشخصي بنجاح!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي والبيانات', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Color(0xFF6C5CE7), child: Icon(Icons.person, size: 45, color: Colors.white)),
            const SizedBox(height: 16),
            TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(controller: _roleC, decoration: const InputDecoration(labelText: 'الصفة / التخصص', prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 12),
            TextField(controller: _phoneC, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextField(controller: _bioC, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة أو الاهتمامات', prefixIcon: Icon(Icons.info_outline))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _save,
                child: const Text('حفظ البيانات والتغيرات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/* ==================== شاشات التفاصيل الفرعية ==================== */
class CategoryDetailScreen extends StatelessWidget {
  final String categoryName;
  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('قسم $categoryName')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.category_rounded, size: 60, color: Color(0xFF6C5CE7)),
              const SizedBox(height: 16),
              Text('أهلاً بك في قسم $categoryName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('يضم هذا القسم كافة الأدوات، الدروس، الشروحات، وموارد الفريق المعتمد المخصصة لخدمتك.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final String title;
  final String content;

  const DetailScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
            const SizedBox(height: 16),
            Text(content, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF2D3436))),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.headset_mic_rounded, color: Colors.white),
                label: const Text('طلب استشارة من الفريق المعتمد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع استفسارك للإنضباط والفريق المعتمد!')));
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

/* ==================== عناصر التصميم السريع ==================== */
class _StatItem extends StatelessWidget {
  final String number;
  final String label;
  const _StatItem({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(number, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
    return Container(height: 20, width: 1, color: Colors.white30);
  }
}

class _InteractiveQuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _InteractiveQuickCard({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _InteractiveProjectCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InteractiveProjectCard({required this.title, required this.desc, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
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
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

const String kSupabaseUrl = "https://fzerbvhdaqifaeabdjkj.supabase.co";
const String kSupabaseAnonKey = "sb_publishable_ajo-GdO4PcqhQDTcde9m7w_Ib6kzaVM";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  runApp(const StarShopsApp());
}

// ==========================================
// THEME & COLOR PALETTE
// ==========================================
class AppColors {
  // Light Mode Colors
  static const Color lightBg = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightTextDark = Color(0xFF111827);
  static const Color lightTextSub = Color(0xFF6B7280);
  static const Color lightGreen = Color(0xFF059669);
  static const Color lightAmber = Color(0xFFB45309);
  static const Color lightAmberBg = Color(0xFFFFFBEB);
  static const Color lightAmberBorder = Color(0xFFFDE68A);

  // 1% Elite Metallic Gold Mode (High-Discount Active)
  static const Color darkBg = Color(0xFF050505);
  static const Color darkCard = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF111111);
  static const Color goldLight = Color(0xFFFCF6BA);
  static const Color goldMedium = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFAA771C);
  static const Color goldBorder = Color(0x66D4AF37);
  
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFBF953F), Color(0xFFFCF6BA), Color(0xFFB38728), Color(0xFFFBF5B7), Color(0xFFAA771C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient reclaimGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFB45309)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ==========================================
// DATA MODELS
// ==========================================
class MerchantModel {
  final dynamic id;
  final String shopName;
  final String category;
  final String address;
  final String phone;
  final String description;
  final String offerText;
  final String imageUrl;
  final double? latitude;
  final double? longitude;
  final bool isOpenToday;
  final String pin;

  MerchantModel({
    required this.id,
    required this.shopName,
    required this.category,
    required this.address,
    required this.phone,
    required this.description,
    required this.offerText,
    required this.imageUrl,
    this.latitude,
    this.longitude,
    required this.isOpenToday,
    required this.pin,
  });

  factory MerchantModel.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lon;
    if (json['latitude'] != null) {
      lat = double.tryParse(json['latitude'].toString());
    }
    if (json['longitude'] != null) {
      lon = double.tryParse(json['longitude'].toString());
    }
    if (lat == null && json['location'] != null && json['location'].toString().contains(',')) {
      final parts = json['location'].toString().split(',');
      lat = double.tryParse(parts[0].trim());
      lon = double.tryParse(parts[1].trim());
    }

    return MerchantModel(
      id: json['id'],
      shopName: json['shop_name'] ?? json['store_name'] ?? 'दुकान',
      category: json['category'] ?? 'SALON',
      address: json['address'] ?? json['location'] ?? 'दिल्ली',
      phone: json['phone'] ?? json['mobile'] ?? 'उपलब्ध नहीं',
      description: json['description'] ?? 'सबसे सही दाम और शानदार काम',
      offerText: json['offer_text'] ?? (json['offer_details'] != null ? json['offer_details']['discount'] : null) ?? 'विशेष छूट उपलब्ध',
      imageUrl: json['profile_image_url'] ?? json['image_url'] ?? json['display_image'] ?? '',
      latitude: lat,
      longitude: lon,
      isOpenToday: json['is_open_today'] ?? true,
      pin: json['secret_pin']?.toString() ?? '1234',
    );
  }
}

class PostModel {
  final dynamic id;
  final dynamic merchantId;
  final String storeName;
  final String category;
  final String avatarUrl;
  final String postImageUrl;
  final String caption;
  final String musicUrl;
  final String address;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.merchantId,
    required this.storeName,
    required this.category,
    required this.avatarUrl,
    required this.postImageUrl,
    required this.caption,
    required this.musicUrl,
    required this.address,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json, MerchantModel? merchant) {
    return PostModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      storeName: merchant?.shopName ?? 'Star Shops Merchant',
      category: merchant?.category ?? 'General',
      avatarUrl: merchant?.imageUrl ?? '',
      postImageUrl: json['post_image_url'] ?? json['image_url'] ?? '',
      caption: json['caption'] ?? json['description'] ?? '✨ बेहतरीन सर्विस, सबसे सही दाम',
      musicUrl: json['music_url'] ?? '',
      address: merchant?.address ?? 'दिल्ली',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ReelModel {
  final dynamic id;
  final dynamic merchantId;
  final String storeName;
  final String videoUrl;
  final String caption;
  final String musicUrl;
  final String avatarUrl;
  final String address;
  final double? lat;
  final double? lon;
  int ratingCount;
  int likeCount;

  ReelModel({
    required this.id,
    required this.merchantId,
    required this.storeName,
    required this.videoUrl,
    required this.caption,
    required this.musicUrl,
    required this.avatarUrl,
    required this.address,
    this.lat,
    this.lon,
    required this.ratingCount,
    required this.likeCount,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json, MerchantModel? merchant) {
    return ReelModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      storeName: merchant?.shopName ?? 'Star Shops Store',
      videoUrl: json['reel_url'] ?? json['video_url'] ?? '',
      caption: json['caption'] ?? json['description'] ?? merchant?.offerText ?? 'विशेष छूट',
      musicUrl: json['music_url'] ?? '',
      avatarUrl: merchant?.imageUrl ?? '',
      address: merchant?.address ?? 'दिल्ली',
      lat: merchant?.latitude,
      lon: merchant?.longitude,
      ratingCount: int.tryParse(json['rating_count']?.toString() ?? '0') ?? 0,
      likeCount: int.tryParse(json['like_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class ClaimHistoryRecord {
  final String store;
  final String saved;
  final String rawDate;
  final String date;

  ClaimHistoryRecord({
    required this.store,
    required this.saved,
    required this.rawDate,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'store': store,
    'saved': saved,
    'rawDate': rawDate,
    'date': date,
  };

  factory ClaimHistoryRecord.fromJson(Map<String, dynamic> json) => ClaimHistoryRecord(
    store: json['store'] ?? '',
    saved: json['saved'] ?? '',
    rawDate: json['rawDate'] ?? '',
    date: json['date'] ?? '',
  );
}

class SavedDealRecord {
  final String key;
  final String store;
  final String location;
  final String offer;
  final String mediaUrl;
  final String expires;

  SavedDealRecord({
    required this.key,
    required this.store,
    required this.location,
    required this.offer,
    required this.mediaUrl,
    required this.expires,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'store': store,
    'location': location,
    'offer': offer,
    'mediaUrl': mediaUrl,
    'expires': expires,
  };

  factory SavedDealRecord.fromJson(Map<String, dynamic> json) => SavedDealRecord(
    key: json['key'] ?? '',
    store: json['store'] ?? '',
    location: json['location'] ?? '',
    offer: json['offer'] ?? '',
    mediaUrl: json['mediaUrl'] ?? '',
    expires: json['expires'] ?? 'आज रात 12:00 बजे',
  );
}

// ==========================================
// APP ROOT
// ==========================================
class StarShopsApp extends StatelessWidget {
  const StarShopsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Star Shops',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.lightBg,
      ),
      home: const DeviceShellScreen(),
    );
  }
}

// ==========================================
// MAIN DEVICE SHELL (Mobile Frame + Nav)
// ==========================================
class DeviceShellScreen extends StatefulWidget {
  const DeviceShellScreen({super.key});

  @override
  State<DeviceShellScreen> createState() => _DeviceShellScreenState();
}

class _DeviceShellScreenState extends State<DeviceShellScreen> {
  int _currentTabIndex = 0;
  bool _highDiscountUnlocked = false;
  int _currentSteps = 0;
  final int _targetSteps = 2000;
  int _userFootprints = 0;

  String _userName = "लोड हो रहा है...";
  String _userPhone = "";
  String _deviceUuid = "";
  String _currentSelectedArea = "इलाका चुनें";

  Position? _currentPosition;
  bool _gpsResolved = false;

  List<MerchantModel> _allMerchants = [];
  List<PostModel> _allPosts = [];
  List<ReelModel> _allReels = [];
  List<ClaimHistoryRecord> _claimHistory = [];
  List<SavedDealRecord> _savedDeals = [];

  String _selectedCategory = 'ALL';
  String _storeSearchQuery = '';

  // Smart Savings Calculator variables
  String _calcDisplay = "0";

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();

    // Device UUID
    String? uuid = prefs.getString('starshops_device_uuid');
    if (uuid == null) {
      uuid = 'user_${math.Random().nextInt(999999999)}';
      await prefs.setString('starshops_device_uuid', uuid);
    }
    _deviceUuid = uuid;

    // Load User Auth
    String? userRaw = prefs.getString('starshops_consumer_user');
    if (userRaw != null) {
      final map = jsonDecode(userRaw);
      setState(() {
        _userName = map['name'] ?? 'उपयोगकर्ता';
        _userPhone = map['phone'] ?? '';
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAuthDialog();
      });
    }

    // Step Goal & Date checks
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('star_user_steps_date');
    if (savedDate != todayStr) {
      _currentSteps = 0;
      _highDiscountUnlocked = false;
      await prefs.setString('star_user_steps_date', todayStr);
      await prefs.setString('star_user_steps_goal', jsonEncode({
        'currentSteps': 0,
        'unlockedHighDiscount': false,
      }));
    } else {
      final stepsRaw = prefs.getString('star_user_steps_goal');
      if (stepsRaw != null) {
        final map = jsonDecode(stepsRaw);
        _currentSteps = map['currentSteps'] ?? 0;
        _highDiscountUnlocked = map['unlockedHighDiscount'] ?? false;
      }
    }

    // Footprints
    _userFootprints = prefs.getInt('starshops_total_footprints') ?? 0;
    if (_userFootprints < _currentSteps) {
      _userFootprints = _currentSteps;
      await prefs.setInt('starshops_total_footprints', _userFootprints);
    }

    // Load Local Claims
    final localClaimsRaw = prefs.getString('starshops_local_claims');
    if (localClaimsRaw != null) {
      final list = jsonDecode(localClaimsRaw) as List;
      _claimHistory = list.map((e) => ClaimHistoryRecord.fromJson(e)).toList();
    }

    // Load Saved Deals
    final savedDealsRaw = prefs.getString('starshops_saved_deals');
    if (savedDealsRaw != null) {
      final list = jsonDecode(savedDealsRaw) as List;
      _savedDeals = list.map((e) => SavedDealRecord.fromJson(e)).toList();
    }

    setState(() {});
    _requestGpsPosition();
    await _fetchDataFromSupabase();
  }

  Future<void> _fetchDataFromSupabase() async {
    try {
      final client = Supabase.instance.client;

      final merchantsData = await client.from('merchants').select('*');
      final postsData = await client.from('merchant_posts').select('*');
      final reelsData = await client.from('merchant_reels').select('*');

      final List<MerchantModel> parsedMerchants = (merchantsData as List)
          .map((item) => MerchantModel.fromJson(item))
          .toList();

      final Map<String, MerchantModel> merchantMap = {
        for (var m in parsedMerchants) m.id.toString(): m
      };

      final List<PostModel> parsedPosts = (postsData as List)
          .map((item) => PostModel.fromJson(item, merchantMap[item['merchant_id']?.toString()]))
          .toList();

      final List<ReelModel> parsedReels = (reelsData as List)
          .map((item) => ReelModel.fromJson(item, merchantMap[item['merchant_id']?.toString()]))
          .toList();

      setState(() {
        _allMerchants = parsedMerchants;
        _allPosts = parsedPosts;
        _allReels = parsedReels;
      });
    } catch (e) {
      debugPrint("Supabase fetch error: $e");
    }
  }

  Future<void> _requestGpsPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      setState(() {
        _currentPosition = pos;
        _gpsResolved = true;
      });
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=hi');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String locality = data['locality'] ?? data['localityName'] ?? 'रोहिणी';
        setState(() {
          _currentSelectedArea = "$locality, दिल्ली";
        });
      }
    } catch (_) {
      setState(() {
        _currentSelectedArea = "बेगमपुर, दिल्ली";
      });
    }
  }

  int _getDailyClaimCount(String storeName) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _claimHistory.where((c) => c.store == storeName && c.rawDate.startsWith(todayStr)).length;
  }

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  void _onCategorySelected(String cat) {
    setState(() {
      _selectedCategory = cat;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _storeSearchQuery = query;
    });
  }

  void _showAuthDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "वेलकम तू Star Shops ⭐",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("कृपया अपना नाम और मोबाइल नंबर दर्ज करें",
                style: TextStyle(fontSize: 12, color: AppColors.lightTextSub)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: "आपका पूरा नाम",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "मोबाइल नंबर",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().length >= 2 && phoneCtrl.text.trim().length >= 10) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                    'starshops_consumer_user',
                    jsonEncode({
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                    }));
                setState(() {
                  _userName = nameCtrl.text.trim();
                  _userPhone = phoneCtrl.text.trim();
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("शुरू करें 🚀", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _onCalcPress(String btn) {
    setState(() {
      if (btn == 'C') {
        _calcDisplay = "0";
      } else if (btn == 'DEL') {
        if (_calcDisplay.length > 1) {
          _calcDisplay = _calcDisplay.substring(0, _calcDisplay.length - 1);
        } else {
          _calcDisplay = "0";
        }
      } else if (btn == '=') {
        try {
          String sanitized = _calcDisplay.replaceAll('×', '*').replaceAll('÷', '/');
          // Simplified basic math eval
          _calcDisplay = _evalBasicMath(sanitized);
        } catch (_) {
          _calcDisplay = "Error";
        }
      } else {
        if (_calcDisplay == "0" && btn != '.') {
          _calcDisplay = btn;
        } else {
          _calcDisplay += btn;
        }
      }
    });
  }

  String _evalBasicMath(String expr) {
    // Basic parser for + - * /
    List<String> tokens = [];
    String curr = "";
    for (int i = 0; i < expr.length; i++) {
      String ch = expr[i];
      if (['+', '-', '*', '/'].contains(ch)) {
        tokens.add(curr);
        tokens.add(ch);
        curr = "";
      } else {
        curr += ch;
      }
    }
    tokens.add(curr);

    double val = double.tryParse(tokens[0]) ?? 0;
    for (int i = 1; i < tokens.length; i += 2) {
      String op = tokens[i];
      double next = double.tryParse(tokens[i + 1]) ?? 0;
      if (op == '+') val += next;
      if (op == '-') val -= next;
      if (op == '*') val *= next;
      if (op == '/') val = next != 0 ? val / next : 0;
    }
    return val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
  }

  void _showPINVerificationModal(MerchantModel store) {
    int claimCount = _getDailyClaimCount(store.shopName);
    if (claimCount >= 2) {
      _showNoticeDialog("स्टोर लिमिट समाप्त", "आप इस दुकान पर आज के 2 क्लेम पूरे कर चुके हैं।");
      return;
    }

    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _highDiscountUnlocked ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _highDiscountUnlocked ? const BorderSide(color: AppColors.goldMedium) : BorderSide.none,
        ),
        title: Text(
          "${store.shopName} डिस्काउंट क्लेम",
          style: TextStyle(
            color: _highDiscountUnlocked ? Colors.white : AppColors.lightTextDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "काउंटर पर उपलब्ध 4-अंकों का पिन दर्ज करें",
              style: TextStyle(color: _highDiscountUnlocked ? Colors.grey : AppColors.lightTextSub, fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: pinCtrl,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 22,
                letterSpacing: 8,
                color: _highDiscountUnlocked ? AppColors.goldLight : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: "",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("रद्द करें", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _highDiscountUnlocked ? AppColors.goldMedium : Colors.amber.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (pinCtrl.text.trim() == store.pin) {
                Navigator.pop(ctx);
                await _executeSuccessfulClaim(store);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("गलत पिन! पुनः प्रयास करें")),
                );
              }
            },
            child: const Text("वेरीफ़ाई करें", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSuccessfulClaim(MerchantModel store) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final newRecord = ClaimHistoryRecord(
      store: store.shopName,
      saved: store.offerText,
      rawDate: now.toIso8601String(),
      date: "${now.day}/${now.month}/${now.year}",
    );

    _claimHistory.insert(0, newRecord);
    await prefs.setString('starshops_local_claims', jsonEncode(_claimHistory.map((e) => e.toJson()).toList()));

    // Step Simulation
    _currentSteps = math.min(_targetSteps, _currentSteps + 500);
    if (_currentSteps >= _targetSteps && !_highDiscountUnlocked) {
      _highDiscountUnlocked = true;
    }

    _userFootprints += 500;
    await prefs.setInt('starshops_total_footprints', _userFootprints);
    await prefs.setString('star_user_steps_goal', jsonEncode({
      'currentSteps': _currentSteps,
      'unlockedHighDiscount': _highDiscountUnlocked,
    }));

    setState(() {});
    _showNoticeDialog("सफलता!", "🎉 बधाई हो! ${store.shopName} का ऑफर सफलतापूर्वक क्लेम हो गया है!");
  }

  void _showNoticeDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _highDiscountUnlocked ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _highDiscountUnlocked ? const BorderSide(color: AppColors.goldMedium) : BorderSide.none,
        ),
        title: Text(title,
            style: TextStyle(
                color: _highDiscountUnlocked ? AppColors.goldLight : Colors.black, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: _highDiscountUnlocked ? Colors.white70 : Colors.black87)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _highDiscountUnlocked ? AppColors.goldMedium : AppColors.lightGreen,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ठीक है (OK)", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _highDiscountUnlocked;
    final themeBg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: themeBg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Stack(
              children: [
                Column(
                  children: [
                    // TOP BAR
                    if (_currentTabIndex != 1) _buildTopHeader(isDark),

                    // TAB SCREENS (1 of 5)
                    Expanded(
                      child: IndexedStack(
                        index: _currentTabIndex,
                        children: [
                          _buildHomeTab(isDark),
                          _buildReelsTab(isDark),
                          _buildImagePostsTab(isDark),
                          _buildAlertsTab(isDark),
                          _buildProfileTab(isDark),
                        ],
                      ),
                    ),
                  ],
                ),

                // FIXED BOTTOM NAVIGATION
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomNav(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP BAR WIDGET
  // ==========================================
  Widget _buildTopHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xD90F0F0F) : const Color(0xD9FFFFFF),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text("★ ", style: TextStyle(color: Color(0xFFF59E0B), fontSize: 18)),
                Text(
                  "STAR SHOPS",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    foreground: isDark
                        ? (Paint()
                          ..shader = AppColors.goldGradient.createShader(const Rect.fromLTWH(0, 0, 150, 20)))
                        : null,
                    color: isDark ? null : AppColors.lightTextDark,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _requestGpsPosition,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111111) : AppColors.lightAmberBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.goldBorder : AppColors.lightAmberBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Text("📍 ", style: TextStyle(fontSize: 12)),
                    Text(
                      _currentSelectedArea,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.goldLight : AppColors.lightAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION
  // ==========================================
  Widget _buildBottomNav(bool isDark) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xD90F0F0F) : const Color(0xD9FFFFFF),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.storefront, "दुकानें", isDark),
          _navItem(1, Icons.play_circle_outline, "रील्स", isDark),
          _navItem(2, Icons.photo_library_outlined, "पोस्ट्स", isDark),
          _navItem(3, Icons.notifications_none, "अलर्ट्स", isDark),
          _navItem(4, Icons.person_outline, "प्रोफ़ाइल", isDark),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    final bool isSelected = _currentTabIndex == index;
    final color = isDark
        ? (isSelected ? AppColors.goldLight : Colors.grey)
        : (isSelected ? AppColors.lightTextDark : AppColors.lightTextSub);

    return InkWell(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isSelected ? 24 : 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: color),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: HOME STORES FEED
  // ==========================================
  Widget _buildHomeTab(bool isDark) {
    final filteredStores = _allMerchants.where((m) {
      if (_selectedCategory == 'OPENTODAY' && !m.isOpenToday) return false;
      if (_selectedCategory == 'PARLOR' && !m.category.toUpperCase().contains('PARLOR')) return false;
      if (_selectedCategory == 'SALON' && !m.category.toUpperCase().contains('SALON')) return false;

      if (_storeSearchQuery.isNotEmpty) {
        final q = _storeSearchQuery.toLowerCase();
        final match = m.shopName.toLowerCase().contains(q) ||
            m.address.toLowerCase().contains(q) ||
            m.category.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.goldBorder : AppColors.lightBorder),
          ),
          child: TextField(
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              icon: Icon(Icons.search, size: 20, color: Colors.grey),
              hintText: "दुकान, लोकेशन, 'high' या 'claimed' खोजें...",
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
              border: InputBorder.none,
            ),
          ),
        ),

        // Categories Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildCategoryChip('ALL', 'ALL', isDark),
              _buildCategoryChip('OPENTODAY', '⚡ OPEN TODAY', isDark),
              if (_highDiscountUnlocked)
                _buildCategoryChip('HIGHDISCOUNT', '★ VERIFIED MERCHANT', isDark),
              _buildCategoryChip('SALON', 'SALON', isDark),
              _buildCategoryChip('PARLOR', 'PARLOR', isDark),
            ],
          ),
        ),

        // Dynamic Stores Count/List
        if (filteredStores.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                "कोई दुकान उपलब्ध नहीं है।",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ...filteredStores.map((store) => _buildStoreCard(store, isDark)),
      ],
    );
  }

  Widget _buildCategoryChip(String key, String label, bool isDark) {
    final bool isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => _onCategorySelected(key),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.goldMedium : AppColors.lightTextDark)
              : (isDark ? const Color(0xFF0F0F0F) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.goldBorder : AppColors.lightBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? AppColors.goldMedium : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreCard(MerchantModel store, bool isDark) {
    int claimCount = _getDailyClaimCount(store.shopName);
    bool isClaimed = claimCount == 1;
    bool isExhausted = claimCount >= 2;

    String distStr = store.address;
    if (_currentPosition != null && store.latitude != null && store.longitude != null) {
      double m = _calculateDistanceMeters(
          _currentPosition!.latitude, _currentPosition!.longitude, store.latitude!, store.longitude!);
      distStr = "${(m / 1000).toStringAsFixed(1)} किमी दूर • ${store.address}";
    }

    int percent = math.min(100, ((_currentSteps / _targetSteps) * 100).round());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimed
              ? Colors.amber.shade700
              : (isDark ? AppColors.goldBorder : AppColors.lightBorder),
          width: isClaimed ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image & Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: store.imageUrl.isNotEmpty
                      ? Image.network(
                          store.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900),
                        )
                      : Container(color: Colors.grey.shade900),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text("⚡ लाइव डील", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text("★ VERIFIED PARTNER", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      store.shopName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.lightTextDark,
                      ),
                    ),
                    Text(
                      distStr,
                      style: const TextStyle(fontSize: 11, color: AppColors.lightAmber, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: store.isOpenToday ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    store.isOpenToday ? "दुकान खुली है (आज)" : "दुकान बंद है",
                    style: TextStyle(
                      color: store.isOpenToday ? const Color(0xFF15803D) : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Steps Progress
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151515) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("🎯 2000 कदम लक्ष्य", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text("$_currentSteps/2000 ($percent%)", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent / 100.0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          minHeight: 6,
                        ),
                      )
                    ],
                  ),
                ),

                const Divider(height: 20),

                // Claim Action & Discount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.offerText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.goldLight : AppColors.lightGreen,
                          ),
                        ),
                        const Text("काउंटर पर विशेष छूट", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExhausted
                            ? Colors.grey
                            : (isClaimed
                                ? Colors.amber.shade800
                                : (isDark ? AppColors.goldMedium : AppColors.lightGreen)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isExhausted ? null : () => _showPINVerificationModal(store),
                      child: Text(
                        isExhausted
                            ? "✓ लिमिट पूरी"
                            : (isClaimed ? "🔄 रीक्लेम करें" : "⚡ क्लेम करें"),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: DEDICATED FULL SCREEN REELS (TikTok / Reels Style)
  // ==========================================
  Widget _buildReelsTab(bool isDark) {
    if (_allReels.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text("रील्स लोड हो रही हैं...", style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _allReels.length,
        itemBuilder: (context, index) {
          final reel = _allReels[index];
          return FullScreenReelItem(
            reel: reel,
            onLike: () {
              setState(() {
                reel.likeCount++;
              });
            },
            onSave: () async {
              final record = SavedDealRecord(
                key: 'reel_${reel.id}',
                store: reel.storeName,
                location: reel.address,
                offer: reel.caption,
                mediaUrl: reel.videoUrl,
                expires: 'आज रात 12:00 बजे',
              );
              _savedDeals.insert(0, record);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('starshops_saved_deals', jsonEncode(_savedDeals.map((e) => e.toJson()).toList()));
              _showNoticeDialog("सुरक्षित!", "ऑफ़र सुरक्षित हुआ! आपकी तिजोरी में ताला लगा दिया गया है।");
            },
            onShare: () {
              Share.share("🔥 ${reel.storeName} का ऑफ़र: ${reel.caption}\n${reel.videoUrl}");
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 3: IMAGE POSTS FEED
  // ==========================================
  Widget _buildImagePostsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            "📰 मर्चेंट फीड",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightTextDark,
            ),
          ),
        ),
        if (_allPosts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text("पोस्ट्स लोड हो रही हैं...", style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._allPosts.map((post) => _buildPostCard(post, isDark)),
      ],
    );
  }

  Widget _buildPostCard(PostModel post, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.goldBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.avatarUrl.isNotEmpty ? NetworkAppImage(post.avatarUrl) : null,
                  backgroundColor: Colors.amber,
                  child: post.avatarUrl.isEmpty ? const Icon(Icons.store, color: Colors.white) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.storeName,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      ),
                      Text("📍 ${post.address}", style: const TextStyle(fontSize: 11, color: AppColors.lightAmber)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Post Media
          if (post.postImageUrl.isNotEmpty)
            Image.network(
              post.postImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 250,
              errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey.shade900),
            ),
          // Caption
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              post.caption,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  color: isDark ? AppColors.goldLight : Colors.black87,
                  onPressed: () {
                    Share.share("${post.storeName}: ${post.caption}\n${post.postImageUrl}");
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.star_border, size: 22),
                  color: isDark ? AppColors.goldLight : Colors.black87,
                  onPressed: () async {
                    final record = SavedDealRecord(
                      key: 'post_${post.id}',
                      store: post.storeName,
                      location: post.address,
                      offer: post.caption,
                      mediaUrl: post.postImageUrl,
                      expires: 'आज रात 12:00 बजे',
                    );
                    _savedDeals.insert(0, record);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                        'starshops_saved_deals', jsonEncode(_savedDeals.map((e) => e.toJson()).toList()));
                    _showNoticeDialog("डील सेव हुई!", "${post.storeName} का ऑफर सफलतापूर्वक सेव हो गया!");
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: ALERTS TAB
  // ==========================================
  Widget _buildAlertsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "⚡ लाइव मर्चेंट अलर्ट्स & ऑफर्स",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightTextDark,
            ),
          ),
        ),
        if (_allMerchants.isEmpty)
          const Center(child: Text("कोई अलर्ट्स नहीं हैं", style: TextStyle(color: Colors.grey)))
        else
          ..._allMerchants.map(
            (store) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.goldBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightAmberBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("⚡", style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${store.shopName} लाइव हो चुकी है!",
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                        ),
                        Text("📍 ${store.address} • ऑफ़र: ${store.offerText}",
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Text("✨ काउंटर पर पिन दर्ज करें और क्लेम करें!",
                            style: TextStyle(fontSize: 10, color: AppColors.lightGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
      ],
    );
  }

  // ==========================================
  // TAB 5: PROFILE & CALCULATOR TAB
  // ==========================================
  Widget _buildProfileTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // Profile Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.goldBorder : AppColors.lightBorder),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: _showSavedDealsModal,
                ),
              ),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.goldMedium,
                child: const Text("👤", style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: AppColors.lightAmber),
                    onPressed: () {
                      final nameCtrl = TextEditingController(text: _userName);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("नाम बदलें"),
                          content: TextField(controller: nameCtrl),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                if (nameCtrl.text.trim().isNotEmpty) {
                                  setState(() {
                                    _userName = nameCtrl.text.trim();
                                  });
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString(
                                      'starshops_consumer_user',
                                      jsonEncode({
                                        'name': _userName,
                                        'phone': _userPhone,
                                      }));
                                  Navigator.pop(ctx);
                                }
                              },
                              child: const Text("सेव करें"),
                            )
                          ],
                        ),
                      );
                    },
                  )
                ],
              ),
              const SizedBox(height: 14),
              // Footprints & Claims Box
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151515) : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.goldBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "${_claimHistory.length} कार्ड्स",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.lightGreen),
                          ),
                          const Text("सफल क्लेम", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151515) : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.goldBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "$_userFootprints",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const Text("कुल कदम", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),

        // Smart Calculator Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.goldBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "स्मार्ट बचत कैलकुलेटर",
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 10),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _calcDisplay,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.goldLight : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Calculator Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _calcButton("C", color: Colors.red.shade100, textColor: Colors.red),
                  _calcButton("DEL", color: Colors.amber.shade100, textColor: Colors.amber.shade900),
                  _calcButton("%", color: Colors.amber.shade100, textColor: Colors.amber.shade900),
                  _calcButton("/", color: Colors.amber.shade100, textColor: Colors.amber.shade900),
                  _calcButton("7"),
                  _calcButton("8"),
                  _calcButton("9"),
                  _calcButton("*", color: Colors.amber.shade100, textColor: Colors.amber.shade900),
                  _calcButton("4"),
                  _calcButton("5"),
                  _calcButton("6"),
                  _calcButton("-", color: Colors.amber.shade100, textColor: Colors.amber.shade900),
                  _calcButton("1"),
                  _calcButton("2"),
                  _calcButton("3"),
                  _calcButton("+", color: Colors.amber.shade100, textColor: Colors.amber.shade900),
                  _calcButton("0"),
                  _calcButton("00"),
                  _calcButton("."),
                  _calcButton("=", color: Colors.black, textColor: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _calcButton(String val, {Color? color, Color? textColor}) {
    return InkWell(
      onTap: () => _onCalcPress(val),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? (_highDiscountUnlocked ? const Color(0xFF1F1F1F) : const Color(0xFFF8F9FA)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor ?? (_highDiscountUnlocked ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  void _showSavedDealsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _highDiscountUnlocked ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "⭐ सेव्ड डील्स & लोकेशन",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightAmberBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "⚠️ चेतावनी: यह सेव की गई रील और ऑफर रात 12:00 बजे हमेशा के लिए गायब हो जाएंगे!",
                style: TextStyle(fontSize: 10, color: AppColors.lightAmber, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _savedDeals.isEmpty
                  ? const Center(child: Text("कोई सेव्ड डील नहीं है", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _savedDeals.length,
                      itemBuilder: (_, i) {
                        final item = _savedDeals[i];
                        return ListTile(
                          title: Text(item.store, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("📍 ${item.location}\n${item.offer}", style: const TextStyle(fontSize: 11)),
                          trailing: const Text("रात 12:00", style: TextStyle(color: Colors.red, fontSize: 10)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FULL-SCREEN TIKTOK/REEL PLAYER COMPONENT
// ==========================================
class FullScreenReelItem extends StatefulWidget {
  final ReelModel reel;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const FullScreenReelItem({
    super.key,
    required this.reel,
    required this.onLike,
    required this.onSave,
    required this.onShare,
  });

  @override
  State<FullScreenReelItem> createState() => _FullScreenReelItemState();
}

class _FullScreenReelItemState extends State<FullScreenReelItem> {
  VideoPlayerController? _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    if (widget.reel.videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
        ..initialize().then((_) {
          setState(() {});
          _controller?.setLooping(true);
          _controller?.play();
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_controller != null && _controller!.value.isInitialized) {
          setState(() {
            if (_controller!.value.isPlaying) {
              _controller!.pause();
              _isPlaying = false;
            } else {
              _controller!.play();
              _isPlaying = true;
            }
          });
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Video or Image
          if (_controller != null && _controller!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.amber)),

          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                stops: [0.0, 0.25, 0.65, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Play/Pause Center Indicator
          if (!_isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, size: 60, color: Colors.white70),
            ),

          // Right Action Bar
          Positioned(
            right: 14,
            bottom: 90,
            child: Column(
              children: [
                _actionButton(Icons.star, "रेटिंग", widget.reel.likeCount.toString(), widget.onLike),
                const SizedBox(height: 16),
                _actionButton(Icons.share, "शेयर", "", widget.onShare),
                const SizedBox(height: 16),
                _actionButton(Icons.lock, "सुरक्षित", "", widget.onSave),
              ],
            ),
          ),

          // Bottom Store Profile and Details
          Positioned(
            left: 14,
            right: 70,
            bottom: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber,
                      backgroundImage:
                          widget.reel.avatarUrl.isNotEmpty ? NetworkImage(widget.reel.avatarUrl) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.reel.storeName,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            widget.reel.caption,
                            style: const TextStyle(
                                color: AppColors.goldLight, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    if (widget.reel.lat != null && widget.reel.lon != null) {
                      final url = Uri.parse(
                          "https://www.google.com/maps/dir/?api=1&destination=${widget.reel.lat},${widget.reel.lon}");
                      if (await canLaunchUrl(url)) launchUrl(url);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "${widget.reel.address} (मैप खोलें)",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, String count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
          if (count.isNotEmpty && count != "0")
            Text(count, style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Utility for Network Image with null safety
ImageProvider NetworkAppImage(String url) {
  return NetworkImage(url);
}

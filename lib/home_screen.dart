import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🔥 Copy to Clipboard ke liye
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔥 Call/Email ke liye
import 'package:share_plus/share_plus.dart'; // 🔥 NAYA: WhatsApp aur baaki jagah Share karne ke liye

import 'main.dart';
import 'add_money_screen.dart';
import 'mobile_recharge_screen.dart';
import 'dth_recharge_screen.dart';
import 'notification_service.dart';

const Color appMasterColor = Color(0xFF00BFFF);
const Color appBackground = Color(0xFFF7F9FB);
const Color appCardColor = Colors.white;
const Color appTextColor = Colors.black87;
const Color appSubTextColor = Colors.grey;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? appSettings;

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
    _fetchAdminSettings();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7122444140042109/8397767989',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, err) {
          debugPrint('AdFailedToLoad: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _fetchAdminSettings() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      if (doc.exists) setState(() => appSettings = doc.data());
    } catch (e) {
      debugPrint("Settings Fetch Error: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        title: const Text(
          'Easy Recharge',
          style: TextStyle(color: appTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: const [
          Icon(Icons.notifications_none_rounded, color: appMasterColor),
          SizedBox(width: 15),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text("Error: No User Logged In"))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: appMasterColor),
                  );
                }

                var userData =
                    snapshot.data!.data() as Map<String, dynamic>? ?? {};
                String userName = userData['name'] ?? 'Boss';
                String userMobile = userData['mobile'] ?? 'N/A';
                double walletBalance = (userData['walletBalance'] ?? 0.0)
                    .toDouble();

                if (_selectedIndex == 0) {
                  return _buildHomeView(userName, userMobile, walletBalance);
                }
                if (_selectedIndex == 1) return _buildHistoryView();
                return _buildProfileView(
                  userName,
                  userMobile,
                ); // 🔥 Premium Profile View
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: appMasterColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // --- 🏠 1. HOME VIEW ---
  Widget _buildHomeView(String name, String mobile, double balance) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, $name!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddMoneyScreen(
                    userId: currentUser!.uid,
                    userName: name,
                    userMobile: mobile,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [appMasterColor, Color(0xFF009ACD)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: appMasterColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '₹ ',
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                          Text(
                            balance.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Add",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Recharge Services',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildServiceCard(
                'Mobile',
                Icons.phone_android,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MobileRechargeScreen(currentBalance: balance),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              _buildServiceCard(
                'DTH',
                Icons.tv_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DthRechargeScreen(currentBalance: balance),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (_isAdLoaded && _bannerAd != null)
            Align(
              alignment: Alignment.center,
              child: Container(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: appMasterColor, size: 30),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- 📜 2. HISTORY VIEW ---
  Widget _buildHistoryView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: 15,
              left: 15,
              right: 15,
              bottom: 5,
            ),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              indicator: BoxDecoration(
                color: appMasterColor,
                borderRadius: BorderRadius.circular(25),
              ),
              tabs: const [
                Tab(text: "WALLET HISTORY"),
                Tab(text: "RECHARGES"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_buildWalletHistoryTab(), _buildRechargeHistoryTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('money_requests')
          .where('userId', isEqualTo: currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: appMasterColor),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyStateWidget(
            Icons.account_balance_wallet_rounded,
            "No Top-ups Yet!",
            "Aapne abhi tak wallet mein paise add nahi kiye hain.",
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var tx = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String timeString = _formatTime(tx['timestamp']);
            num amount = tx['amount'] ?? 0;
            String status = tx['status'] ?? 'Pending';
            String utr = tx['utr'] ?? 'Online';

            Color statusColor = Colors.orange.shade600;
            IconData statusIcon = Icons.access_time;
            if (status == 'Approved') {
              statusColor = Colors.green.shade600;
              statusIcon = Icons.account_balance_wallet_rounded;
            } else if (status == 'Rejected') {
              statusColor = Colors.red.shade600;
              statusIcon = Icons.close;
            }

            return _historyTile(
              title: "Added Money (Ref: $utr)",
              subtitle: timeString,
              amount: "+ ₹$amount",
              status: status,
              icon: statusIcon,
              color: statusColor,
            );
          },
        );
      },
    );
  }

  Widget _buildRechargeHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recharges')
          .where('userId', isEqualTo: currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: appMasterColor),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyStateWidget(
            Icons.phone_android_rounded,
            "No Recharges Yet!",
            "Aapne abhi tak koi mobile recharge nahi kiya hai.",
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var rx = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String timeString = _formatTime(rx['timestamp']);
            return _historyTile(
              title: "${rx['operator'] ?? 'Mobile'} Recharge",
              subtitle: "No: ${rx['number']}  •  $timeString",
              amount: "- ₹${rx['amount']}",
              status: rx['status'] ?? 'Success',
              icon: Icons.electrical_services_rounded,
              color: Colors.red.shade500,
            );
          },
        );
      },
    );
  }

  Widget _historyTile({
    required String title,
    required String subtitle,
    required String amount,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    Color statusColor;
    if (status.toLowerCase() == 'success' ||
        status.toLowerCase() == 'approved') {
      statusColor = Colors.green.shade700;
    } else if (status.toLowerCase() == 'failed' ||
        status.toLowerCase() == 'rejected')
      statusColor = Colors.red.shade700;
    else
      statusColor = Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyStateWidget(IconData icon, String title, String desc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime dt = (timestamp as Timestamp).toDate();
    return "${dt.day}/${dt.month}/${dt.year} • ${dt.hour > 12 ? dt.hour - 12 : dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
  }

  // --- 👤 3. PREMIUM PROFILE VIEW ---
  Widget _buildProfileView(String name, String mobile) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 🔥 1. VIP Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [appMasterColor, Color(0xFF007ACC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: appMasterColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundColor: appBackground,
                    child: Icon(Icons.person, size: 40, color: appMasterColor),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_android,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '+91 $mobile',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 🔥 2. Profile Options
          _profileTile(
            Icons.card_giftcard,
            "Refer & Earn",
            () => _showModernSheet(
              title: "Refer & Earn",
              child: _referUI(mobile),
            ),
          ),
          _profileTile(
            Icons.percent,
            "My Commission",
            () => _showModernSheet(
              title: "Commission Rates",
              child: _commissionUI(),
            ),
          ),
          _profileTile(
            Icons.support_agent,
            "Help & Support",
            () => _showModernSheet(title: "Contact Us", child: _supportUI()),
          ),
          _profileTile(
            Icons.privacy_tip_outlined,
            "Privacy Policy",
            () =>
                _showModernSheet(title: "Privacy Policy", child: _privacyUI()),
          ),

          const SizedBox(height: 30),

          // 🔥 3. Secure Logout Button
          ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              "Logout Securely",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // 🚨 Warning Dialog for Logout
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text("Logout?"),
          ],
        ),
        content: const Text(
          "Are you sure you want to logout from Easy Recharge?",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text(
              "LOGOUT",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🛠️ SMALL UI HELPERS & BOTTOM SHEETS
  void _showModernSheet({required String title, required Widget child}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(25, 12, 25, 25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: appMasterColor,
              ),
            ),
            const SizedBox(height: 25),
            child,
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: appMasterColor,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "CLOSE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 SUPERCHARGED REFER UI (With WhatsApp Share & Copy)
  Widget _referUI(String mobile) => Column(
    children: [
      const Icon(Icons.stars_rounded, size: 60, color: Colors.orange),
      const SizedBox(height: 15),
      const Text(
        "Share your number as referral code:",
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 15),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.shade200, width: 2),
        ),
        child: Text(
          mobile,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.orange,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        "Reward: ₹${appSettings?['refer_amount'] ?? '0'}",
        style: const TextStyle(
          color: Colors.green,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 25),

      Row(
        children: [
          // 📋 COPY BUTTON
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mobile));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Referral Code Copied! 📋"),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(
                Icons.copy_rounded,
                color: appMasterColor,
                size: 18,
              ),
              label: const Text(
                "COPY",
                style: TextStyle(
                  color: appMasterColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: appMasterColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 15),

          // 🟢 SHARE BUTTON
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                String appLink =
                    "https://play.google.com/store/apps/details?id=com.easy.recharge";
                String shareMessage =
                    "Hello! 👋\n\nDownload the Easy Recharge App and get amazing cashback on Mobile & DTH recharges! 🚀\n\nUse my Referral Code to get bonus: *$mobile*\n\nDownload Now: $appLink";

                Share.share(shareMessage);
              },
              icon: const Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                "SHARE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 5,
                shadowColor: Colors.green.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _commissionUI() => Column(
    children: [
      _sheetSection("MOBILE RECHARGE"),
      _commRow("Jio", appSettings?['jio_comm']),
      _commRow("Airtel", appSettings?['airtel_comm']),
      _commRow("Vi", appSettings?['vi_comm']),
      _commRow("BSNL", appSettings?['bsnl_comm']),
      const Divider(height: 25),
      _sheetSection("DTH RECHARGE"),
      _commRow("Tata Play", appSettings?['tata_play_comm']),
      _commRow("Dish TV", appSettings?['dish_tv_comm']),
      _commRow("Airtel DTH", appSettings?['airtel_dth_comm']),
      _commRow("Videocon", appSettings?['videocon_comm']),
      _commRow("Sun Direct", appSettings?['sun_direct_comm']),
    ],
  );

  // 🔥 CLICKABLE SUPPORT UI (Tap to Call/Email)
  Widget _supportUI() => Column(
    children: [
      _supportRow(
        Icons.email_rounded,
        "Email Us",
        appSettings?['support_email'] ?? "N/A",
        "mailto",
      ),
      _supportRow(
        Icons.phone_in_talk_rounded,
        "Call Us",
        appSettings?['support_phone'] ?? "N/A",
        "tel",
      ),
      _supportRow(
        Icons.location_on_rounded,
        "Office",
        appSettings?['support_address'] ?? "N/A",
        "none",
      ),
    ],
  );

  Widget _privacyUI() => Container(
    constraints: const BoxConstraints(maxHeight: 250),
    child: SingleChildScrollView(
      child: Text(
        appSettings?['privacy_policy'] ?? "Loading policy...",
        style: const TextStyle(height: 1.5),
      ),
    ),
  );

  Widget _profileTile(IconData icon, String title, VoidCallback onTap) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: appMasterColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: appMasterColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 18,
        color: Colors.grey,
      ),
      onTap: onTap,
    ),
  );

  Widget _commRow(String name, dynamic val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        Text(
          "${val ?? '0'}%",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Colors.green,
          ),
        ),
      ],
    ),
  );

  Widget _supportRow(IconData i, String t, String v, String scheme) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: appMasterColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(i, color: appMasterColor),
    ),
    title: Text(
      t,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
        fontWeight: FontWeight.bold,
      ),
    ),
    subtitle: Text(
      v,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        fontSize: 15,
      ),
    ),
    trailing: scheme != "none"
        ? const Icon(Icons.open_in_new_rounded, size: 18, color: appMasterColor)
        : null,
    onTap: () async {
      if (scheme == "none" || v == "N/A") return;
      final Uri url = Uri.parse('$scheme:$v');
      try {
        await launchUrl(url);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Action not supported on this device!")),
        );
      }
    },
  );

  Widget _sheetSection(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 5),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.5,
        ),
      ),
    ),
  );
}

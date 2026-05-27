import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color appMasterColor = Color(0xFF00BFFF);
const Color appBackground = Color(0xFFF4F7FC); // Premium background color

class AddMoneyScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userMobile;

  const AddMoneyScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userMobile,
  });

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  // Online Tab Controllers
  final TextEditingController _amountController = TextEditingController();
  bool _isOnlineLoading = false;
  final List<int> _quickAmounts = [100, 500, 1000, 2000];

  // Manual Tab Controllers
  final TextEditingController _manualAmountController = TextEditingController();
  final TextEditingController _utrController = TextEditingController();
  bool _isManualLoading = false;
  bool _isFetchingSettings = true;

  String? adminUpi;
  String? adminQr;

  @override
  void initState() {
    super.initState();
    _amountController.text = ""; // Initial blank
    _fetchAdminSettings();
  }

  Future<void> _fetchAdminSettings() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          adminUpi = doc.data()?['admin_upi'];
          adminQr = doc.data()?['admin_qr'];
          _isFetchingSettings = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingSettings = false);
    }
  }

  void _setQuickAmount(int amount) {
    HapticFeedback.lightImpact(); // Modern touch feedback
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  // ==========================================
  // 🟢 1. DIRECT ONLINE PAYMENT (With UPI Intents)
  // ==========================================
  Future<void> _processOnlinePay() async {
    String amountText = _amountController.text.trim();
    if (amountText.isEmpty || int.parse(amountText) < 1) {
      _showSnack("Please enter a valid amount!", Colors.redAccent);
      return;
    }

    setState(() => _isOnlineLoading = true);

    try {
      var settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      String? liveToken = settingsDoc.data()?['allapi_token'];

      if (liveToken == null || liveToken.isEmpty) {
        throw Exception("API Token not found in Settings!");
      }

      String orderId = "ORD${DateTime.now().millisecondsSinceEpoch}";
      String redirectUrl = "https://allapi.in/success";

      var response = await http.post(
        Uri.parse('https://allapi.in/order/create'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "token": liveToken,
          "order_id": orderId,
          "txn_amount": int.parse(amountText),
          "txn_note": "Wallet Topup",
          "product_name": "Easy Recharge Wallet",
          "customer_name": widget.userName,
          "customer_mobile": widget.userMobile,
          "customer_email": "${widget.userId}@app.com",
          "redirect_url": redirectUrl,
        }),
      );

      var data = jsonDecode(response.body);

      // 🔥 NAYA CODE (With 'results' and 'upi_intent' FIX) 🔥
      if (response.statusCode == 200 &&
          (data['status'] == true || data['status'] == 'success')) {
        String? paymentUrl;
        Map<String, dynamic>? upiIntents; // 🔥 Khazana (Direct Links)

        if (data['payment_url'] != null) {
          paymentUrl = data['payment_url'].toString();
        } else if (data['results'] != null) {
          paymentUrl = data['results']['payment_url']?.toString();
          // 🔥 Yahan humne UPI Apps ke Direct Links pakad liye!
          if (data['results']['upi_intent'] != null) {
            upiIntents = data['results']['upi_intent'];
          }
        } else if (data['data'] != null &&
            data['data']['payment_url'] != null) {
          paymentUrl = data['data']['payment_url'].toString();
        }

        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentWebView(
                  paymentUrl: paymentUrl!,
                  amount: int.parse(amountText),
                  userId: widget.userId,
                  redirectUrl: redirectUrl,
                  upiIntents:
                      upiIntents, // 🔥 Ye khazana hum WebView ko bhej rahe hain
                ),
              ),
            );
          }
        } else {
          throw Exception(
            "API ne Payment URL nahi bheja Boss! \nResponse: $data",
          );
        }
      } else {
        throw Exception(
          data['message']?.toString() ?? "API Error: Dekhiye kya gadbad hai",
        );
      }
    } catch (e) {
      if (mounted) _showSnack("Payment Error: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isOnlineLoading = false);
    }
  }

  // ==========================================
  // 🟡 2. MANUAL REQUEST LOGIC
  // ==========================================
  Future<void> _submitManualRequest() async {
    HapticFeedback.mediumImpact();
    String mAmount = _manualAmountController.text.trim();
    String mUtr = _utrController.text.trim();

    if (mAmount.isEmpty || mUtr.length < 10) {
      _showSnack("Sahi Amount aur UTR daalein!", Colors.orange);
      return;
    }

    setState(() => _isManualLoading = true);

    try {
      await FirebaseFirestore.instance.collection('money_requests').add({
        'userId': widget.userId,
        'userName': widget.userName,
        'userMobile': widget.userMobile,
        'amount': int.parse(mAmount),
        'utr': mUtr,
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _manualAmountController.clear();
        _utrController.clear();
        _showSnack("Request Submitted! Verification pending.", Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack("Error: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isManualLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==========================================
  // 🎨 UI HELPERS
  // ==========================================
  Widget _actionButton(String title, bool loading, VoidCallback tap) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [appMasterColor, Color(0xFF007ACC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: appMasterColor.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : tap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  // ==========================================
  // 🏗️ MAIN UI BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          title: const Text(
            "Top Up Wallet",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                indicator: BoxDecoration(
                  color: appMasterColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                tabs: const [
                  Tab(text: "ONLINE PAY"),
                  Tab(text: "MANUAL UTR"),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(children: [_buildOnlineUI(), _buildManualUI()]),
      ),
    );
  }

  // --- 🟢 MODERN ONLINE UI ---
  Widget _buildOnlineUI() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: appMasterColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              size: 50,
              color: appMasterColor,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "Instant Top-up",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 35),

          // 🔥 Massive Modern Amount Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "ENTER AMOUNT",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  cursorColor: appMasterColor,
                  cursorHeight: 50,
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    prefixText: "₹",
                    prefixStyle: TextStyle(
                      fontSize: 60,
                      color: Colors.grey.shade300,
                      fontWeight: FontWeight.w400,
                    ),
                    hintText: "0",
                    hintStyle: TextStyle(color: Colors.grey.shade300),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),

          // 🔥 Stylish Quick Amounts
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _quickAmounts.map((amt) {
              return InkWell(
                onTap: () => _setQuickAmount(amt),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Text(
                    "+ ₹$amt",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: appMasterColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 50),
          _actionButton("PROCEED TO PAY", _isOnlineLoading, _processOnlinePay),
        ],
      ),
    );
  }

  // --- 🟡 MODERN MANUAL UI ---
  Widget _buildManualUI() {
    if (_isFetchingSettings) {
      return const Center(
        child: CircularProgressIndicator(color: appMasterColor),
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
      child: Column(
        children: [
          // 🔥 Modern QR/UPI Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Scan QR to Pay",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                // Modern QR Container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade100, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: adminQr != null && adminQr!.isNotEmpty
                      ? Image.network(
                          adminQr!,
                          height: 180,
                          width: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.qr_code_2,
                            size: 100,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.qr_code_2,
                          size: 150,
                          color: Colors.grey,
                        ),
                ),
                const SizedBox(height: 20),
                // Modern UPI Tile
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: appBackground,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "ADMIN UPI ID",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              adminUpi ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: appMasterColor,
                          size: 20,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: adminUpi ?? ""),
                          );
                          _showSnack("UPI ID Copied!", Colors.green);
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),

          // 🔥 SLEEK FORM INPUTS
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "SUBMIT PAYMENT PROOF",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Column(
              children: [
                _sleekInput(
                  _manualAmountController,
                  Icons.currency_rupee_rounded,
                  "Amount Paid (₹)",
                  TextInputType.number,
                  true,
                ),
                const SizedBox(height: 20),
                _sleekInput(
                  _utrController,
                  Icons.tag_rounded,
                  "12-Digit UTR Number",
                  TextInputType.text,
                  false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _actionButton(
            "SUBMIT REQUEST",
            _isManualLoading,
            _submitManualRequest,
          ),
          const SizedBox(height: 15),
          const Text(
            "Admin verifies balance in 10-15 minutes.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Modern Input Builder
  Widget _sleekInput(
    TextEditingController ctrl,
    IconData icon,
    String label,
    TextInputType type,
    bool digitsOnly,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.black87,
      ),
      cursorColor: appMasterColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, color: appMasterColor, size: 20),
        filled: true,
        fillColor: appBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: appMasterColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }
}

// ==========================================
// 🌐 SUPERCHARGED WEBVIEW (Triple Guard Interceptor)
// ==========================================
class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final String redirectUrl;
  final int amount;
  final String userId;
  final Map<String, dynamic>? upiIntents;

  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.redirectUrl,
    required this.amount,
    required this.userId,
    this.upiIntents,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isSuccessHandled = false; // 🔥 DOUBLE BALANCE ROKNE KE LIYE

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          // 🔥 GUARD 1: Jab page load hona shuru ho
          onPageStarted: (String url) {
            if (url.toLowerCase().contains("success")) {
              _handleFinalStatus();
            }
          },

          // 🔥 GUARD 2: Jab URL background mein badle
          onUrlChange: (UrlChange change) {
            if (change.url != null &&
                change.url!.toLowerCase().contains("success")) {
              _handleFinalStatus();
            }
          },

          // 🔥 GUARD 3: Jab user click kare ya direct navigation ho
          onNavigationRequest: (request) async {
            String url = request.url.toLowerCase();

            // Direct App Launch
            if (url.startsWith('upi:') ||
                url.startsWith('paytmmp:') ||
                url.startsWith('tez:') ||
                url.startsWith('phonepe:') ||
                url.startsWith('bhim:') ||
                url.startsWith('gpay:')) {
              _launchDirectApp(request.url);
              return NavigationDecision.prevent;
            }

            // Success Redirect
            if (url.contains("success") ||
                url.contains(widget.redirectUrl.toLowerCase())) {
              _handleFinalStatus();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _launchDirectApp(String link) async {
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ye UPI App install nahi hai!"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // 🔥 BALANCE UPDATE FUNCTION (Sirf ek baar chalega)
  // 🔥 BALANCE UPDATE + HISTORY SAVE FUNCTION
  void _handleFinalStatus() async {
    if (_isSuccessHandled) return;
    _isSuccessHandled = true;

    try {
      // 1. Balance Badhao (Seedha Wallet mein)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'walletBalance': FieldValue.increment(widget.amount.toDouble()),
          });

      // 2. 🔥 THE FIX: Ise 'money_requests' mein direct 'Approved' karke daalo
      // Taaki ye User aur Admin dono ki passbook mein "Added Money" mein dikhe!
      await FirebaseFirestore.instance.collection('money_requests').add({
        'userId': widget.userId,
        'userName':
            'Online Gateway', // Pata chale ki UTR se nahi, online aaya hai
        'userMobile':
            widget.userId, // Agar actual mobile na mile, toh User ID rakh do
        'amount': widget.amount.toDouble(),
        'utr': 'AUTO-SUCCESS', // Online mein UTR manually nahi chahiye
        'status': 'Approved', // 🔥 Direct Approved!
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Money Added & History Updated! 🎉"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Balance Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text("Secure Payment"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // 🔥 PREMIUM ORIGINAL LOGO BAR
          if (widget.upiIntents != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "PAY DIRECTLY USING YOUR APP",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      if (widget.upiIntents!['paytm'] != null)
                        _buildUpiButton(
                          "Paytm",
                          widget.upiIntents!['paytm'],
                          "https://www.google.com/s2/favicons?sz=64&domain=paytm.com",
                        ),
                      if (widget.upiIntents!['gpay'] != null)
                        _buildUpiButton(
                          "GPay",
                          widget.upiIntents!['gpay'],
                          "https://www.google.com/s2/favicons?sz=64&domain=pay.google.com",
                        ),
                      if (widget.upiIntents!['phonepe'] != null)
                        _buildUpiButton(
                          "PhonePe",
                          widget.upiIntents!['phonepe'],
                          "https://www.google.com/s2/favicons?sz=64&domain=phonepe.com",
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.upiIntents!['bhim'] != null)
                    TextButton.icon(
                      onPressed: () =>
                          _launchDirectApp(widget.upiIntents!['bhim']),
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF00BFFF),
                        size: 18,
                      ),
                      label: const Text(
                        "Other UPI Apps",
                        style: TextStyle(
                          color: Color(0xFF00BFFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  Widget _buildUpiButton(String name, String link, String logoUrl) {
    return InkWell(
      onTap: () => _launchDirectApp(link),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(
                logoUrl,
                height: 24,
                width: 24,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.payment, size: 24, color: Colors.blue),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

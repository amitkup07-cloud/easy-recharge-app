import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color appMasterColor = Color(0xFF00BFFF);
const Color appBackground = Color(0xFFF4F7FC);

class MobileRechargeScreen extends StatefulWidget {
  final double currentBalance;
  const MobileRechargeScreen({super.key, required this.currentBalance});

  @override
  State<MobileRechargeScreen> createState() => _MobileRechargeScreenState();
}

class _MobileRechargeScreenState extends State<MobileRechargeScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedOperator = '';

  // Fetch API Variables (PlanAPI)
  bool _isFetchingDetails = false;
  String? _opCode;
  String? _circleCode;
  String _circleName = '';

  // Recharge API Variables (Robotic Exchange)
  bool _isRecharging = false;

  // 🔥 Aapka AWS Server Proxy IP
  final String myAwsProxyIp = "http://13.234.211.212/api.php?endpoint=";

  final List<Map<String, dynamic>> operators = [
    {'name': 'Jio', 'color': Colors.blue.shade700, 'roboticCode': 'JO'},
    {'name': 'Airtel', 'color': Colors.red.shade600, 'roboticCode': 'AT'},
    {'name': 'Vi', 'color': Colors.red.shade800, 'roboticCode': 'VI'},
    {'name': 'BSNL', 'color': Colors.blue.shade800, 'roboticCode': 'BS'},
  ];

  // 🛠️ Proxy Helper Function (URL ko hide aur safe encode karne ke liye)
  String _getProxyUrl(String targetUrl) {
    String encodedUrl = Uri.encodeComponent(
      base64Encode(utf8.encode(targetUrl)),
    );
    return "$myAwsProxyIp$encodedUrl";
  }

  // ==========================================
  // 🟢 1. FETCH OPERATOR & CIRCLE API (PlanAPI)
  // ==========================================
  Future<void> _fetchOperatorDetails(String mobile) async {
    setState(() => _isFetchingDetails = true);
    try {
      var settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      String planApiId =
          settingsDoc.data()?['plan_api_user_id']?.toString() ?? "";
      String rawPlanPass =
          settingsDoc.data()?['plan_api_password']?.toString() ?? "";

      if (planApiId.isEmpty || rawPlanPass.isEmpty) {
        _showSnack(
          "Admin Setup Incomplete: PlanAPI Credentials missing!",
          Colors.redAccent,
        );
        setState(() => _isFetchingDetails = false);
        return;
      }

      String planApiPass = Uri.encodeComponent(rawPlanPass);
      String originalUrl =
          "https://planapi.in/api/Mobile/OperatorFetchNew?ApiUserID=$planApiId&ApiPassword=$planApiPass&Mobileno=$mobile";

      var response = await http.get(Uri.parse(_getProxyUrl(originalUrl)));
      var data = jsonDecode(response.body);

      if (data['ERROR'] == "0" && data['STATUS'] == "1") {
        String apiOp = data['Operator'].toString().toUpperCase();

        if (apiOp.contains("AIRTEL")) {
          _selectedOperator = "Airtel";
        } else if (apiOp.contains("JIO"))
          _selectedOperator = "Jio";
        else if (apiOp.contains("VI") ||
            apiOp.contains("VODAFONE") ||
            apiOp.contains("IDEA"))
          _selectedOperator = "Vi";
        else if (apiOp.contains("BSNL"))
          _selectedOperator = "BSNL";

        _opCode = data['OpCode']?.toString();
        _circleCode = data['CircleCode']?.toString();
        _circleName = data['Circle']?.toString() ?? "";

        HapticFeedback.lightImpact();
      } else {
        _selectedOperator = '';
        _circleName = '';
        _showSnack(
          data['Message'] ?? "Network detail nahi mili",
          Colors.orange,
        );
      }
    } catch (e) {
      _showSnack("Operator fetch error via Proxy", Colors.redAccent);
    }
    setState(() => _isFetchingDetails = false);
  }

  // ==========================================
  // 🟡 2. SHOW PREMIUM PLANS BOTTOM SHEET
  // ==========================================
  Future<void> _openPlansSheet() async {
    if (_opCode == null || _circleCode == null) {
      _showSnack("Pehle 10-digit ka Mobile Number daalein!", Colors.orange);
      return;
    }

    _showSnack("Loading Plans...", appMasterColor);

    try {
      var settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      String planApiId =
          settingsDoc.data()?['plan_api_user_id']?.toString() ?? "";
      String rawPlanPass =
          settingsDoc.data()?['plan_api_password']?.toString() ?? "";

      if (planApiId.isEmpty || rawPlanPass.isEmpty) {
        _showSnack("PlanAPI Credentials missing in Admin!", Colors.redAccent);
        return;
      }

      String planApiPass = Uri.encodeComponent(rawPlanPass);
      String originalUrl =
          "https://planapi.in/api/Mobile/NewMobilePlans?apimember_id=$planApiId&api_password=$planApiPass&operatorcode=$_opCode&cricle=$_circleCode";

      String finalProxyUrl = _getProxyUrl(originalUrl);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 15, bottom: 10),
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Text(
                  "$_selectedOperator Plans ($_circleName)",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: appMasterColor,
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: FutureBuilder(
                    future: http.get(Uri.parse(finalProxyUrl)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: appMasterColor,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text("Plans lane mein error aayi!"),
                        );
                      }

                      var data = jsonDecode(snapshot.data!.body);
                      if (data['ERROR'] != "0" || data['RDATA'] == null) {
                        return Center(
                          child: Text(
                            data['MESSAGE'] ?? "Koi plans nahi mile!",
                          ),
                        );
                      }

                      Map<String, dynamic> rdata = data['RDATA'];
                      List<String> categories = rdata.keys.toList();

                      if (categories.isEmpty) {
                        return const Center(
                          child: Text("Koi plans nahi mile!"),
                        );
                      }

                      return DefaultTabController(
                        length: categories.length,
                        child: Column(
                          children: [
                            TabBar(
                              isScrollable: true,
                              labelColor: appMasterColor,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: appMasterColor,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              tabs: categories
                                  .map((cat) => Tab(text: cat))
                                  .toList(),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: categories.map((cat) {
                                  List plans = rdata[cat];
                                  return ListView.builder(
                                    padding: const EdgeInsets.all(15),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: plans.length,
                                    itemBuilder: (context, i) {
                                      var plan = plans[i];
                                      return Card(
                                        elevation: 0,
                                        margin: const EdgeInsets.only(
                                          bottom: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          side: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          onTap: () {
                                            setState(
                                              () => _amountController.text =
                                                  plan['rs'].toString(),
                                            );
                                            Navigator.pop(context);
                                            HapticFeedback.lightImpact();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(15),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: appMasterColor
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    "₹${plan['rs']}",
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: appMasterColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 15),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Validity: ${plan['validity']}",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        plan['desc'] ?? '',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showSnack("Config Error", Colors.red);
    }
  }

  // ==========================================
  // 🔴 3. MAIN RECHARGE API (Robotic Exchange via AWS)
  // ==========================================
  Future<void> _processRecharge() async {
    String mobile = _numberController.text.trim();
    String amountStr = _amountController.text.trim();

    if (mobile.length < 10) {
      _showSnack("Sahi Mobile Number daalein!", Colors.orange);
      return;
    }
    if (_selectedOperator.isEmpty) {
      _showSnack("Please select an Operator!", Colors.orange);
      return;
    }
    if (amountStr.isEmpty) {
      _showSnack("Please enter Recharge Amount!", Colors.orange);
      return;
    }
    if (_circleCode == null || _circleCode!.isEmpty) {
      _showSnack(
        "Circle code load nahi hua, dobara number daalein!",
        Colors.orange,
      );
      return;
    }

    setState(() => _isRecharging = true);

    try {
      // 🔥 1. Sabse Pehle Firebase Se Settings & Commission Fetch Karein
      var settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();

      if (!settingsDoc.exists) {
        _showSnack("Admin Setup Incomplete!", Colors.redAccent);
        setState(() => _isRecharging = false);
        return;
      }

      // 🔥 2. Operator Ke Hisaab Se Commission Field Ka Naam Nikalein
      String commField = "";
      if (_selectedOperator == "Jio")
        commField = "jio_comm";
      else if (_selectedOperator == "Airtel")
        commField = "airtel_comm";
      else if (_selectedOperator == "Vi")
        commField = "vi_comm";
      else if (_selectedOperator == "BSNL")
        commField = "bsnl_comm";

      // 🔥 3. Commission Percentage Extract Karein
      double commPercentage = 0.0;
      if (commField.isNotEmpty && settingsDoc.data()!.containsKey(commField)) {
        // (as num).toDouble() zaruri hai warna Firebase agar Integer bhejega toh error aayega
        commPercentage = (settingsDoc.data()![commField] as num).toDouble();
      }

      double rechargeAmount = double.parse(amountStr);

      // 🔥 4. Commission aur Wallet se katne wala asli paisa calculate karein
      double commissionEarned = (rechargeAmount * commPercentage) / 100.0;
      double finalDeductionAmount = rechargeAmount - commissionEarned;

      // 🔥 5. Ab Wallet Check finalDeductionAmount (katne wale paise) par hoga
      if (finalDeductionAmount > widget.currentBalance) {
        _showSnack(
          "Insufficient Wallet Balance! (Balance: ₹${widget.currentBalance})",
          Colors.red,
        );
        setState(() => _isRecharging = false);
        return;
      }

      String apiMemberId =
          settingsDoc.data()?['robotic_member_id']?.toString() ?? "";
      String apiPassword =
          settingsDoc.data()?['robotic_api_password']?.toString() ?? "";

      if (apiMemberId.isEmpty || apiPassword.isEmpty) {
        _showSnack(
          "Admin Setup Incomplete: Robotic Credentials missing!",
          Colors.redAccent,
        );
        setState(() => _isRecharging = false);
        return;
      }

      String safeApiPassword = Uri.encodeComponent(apiPassword);
      String roboticOpCode = operators.firstWhere(
        (op) => op['name'] == _selectedOperator,
      )['roboticCode'];
      String txnId = "TXN${DateTime.now().millisecondsSinceEpoch}";

      String originalUrl =
          "https://api.roboticexchange.in/Robotics/webservice/GetMobileRecharge?Apimember_id=$apiMemberId&Api_password=$safeApiPassword&Mobile_no=$mobile&Operator_code=$roboticOpCode&Amount=${int.parse(amountStr)}&Member_request_txnid=$txnId&Circle=$_circleCode";

      debugPrint("🔥 ORIGINAL API URL: $originalUrl");

      // Send via AWS Proxy
      var response = await http.get(Uri.parse(_getProxyUrl(originalUrl)));

      debugPrint("🔥 RAW API RESPONSE: ${response.body}");

      var data = jsonDecode(response.body);

      // STATUS 1 = Success, STATUS 2 = Processing
      if (data['STATUS'] == 1 || data['STATUS'] == 2) {
        String finalStatus = data['STATUS'] == 1 ? "Success" : "Processing";
        String uid = FirebaseAuth.instance.currentUser!.uid;

        // 🔥 6. Wallet Se Sirf Commission Kaat Kar Paisa Katega
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'walletBalance': FieldValue.increment(-finalDeductionAmount),
        });

        // 🔥 7. History (Recharges Table) Mein Pura Hisaab-Kitaab Save Karein
        await FirebaseFirestore.instance.collection('recharges').add({
          'userId': uid,
          'number': mobile,
          'operator': _selectedOperator,
          'amount': rechargeAmount, // User ko poora amount dikhega
          'commissionEarned': commissionEarned, // Kitna fayda hua
          'finalDeducted':
              finalDeductionAmount, // Wallet se asal mein kitna kata
          'status': finalStatus,
          'txnId': txnId,
          'apiOpTxnId': data['OPTRANSID'] ?? "",
          'type': 'Mobile',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          _showSnack(
            "Recharge $finalStatus! Commission Earned: ₹$commissionEarned 🎉",
            Colors.green,
          );
        }
      } else {
        String errorMsg = data['MESSAGE'] ?? "Unknown Error from API";
        _showSnack("Failed: $errorMsg", Colors.red);
        debugPrint("🔥 RECHARGE FAILED REASON: $errorMsg");
      }
    } catch (e) {
      debugPrint("🔥 CATCH ERROR: $e");
      _showSnack("Error: ${e.toString()}", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isRecharging = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: appMasterColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mobile Recharge",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _numberController,
                keyboardType: TextInputType.phone,
                onChanged: (value) {
                  if (value.length == 10) {
                    FocusScope.of(context).unfocus();
                    _fetchOperatorDetails(value);
                  } else {
                    if (_circleName.isNotEmpty) {
                      setState(() => _circleName = '');
                    }
                  }
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.phone_android_rounded,
                    color: appMasterColor,
                    size: 24,
                  ),
                  hintText: "Mobile Number",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                  border: InputBorder.none,
                  suffixIcon: _isFetchingDetails
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: appMasterColor,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            if (_circleName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 8),
                child: Text(
                  "Circle: $_circleName",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 30),

            Text(
              "Select Operator",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: operators.map((op) {
                bool isSelected = _selectedOperator == op['name'];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedOperator = op['name']);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: MediaQuery.of(context).size.width * 0.2 - 12,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? op['color'].withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected ? op['color'] : Colors.grey.shade200,
                        width: isSelected ? 2 : 1.5,
                      ),
                      boxShadow: [
                        if (!isSelected)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 5,
                          ),
                      ],
                    ),
                    child: Text(
                      op['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: op['color'],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 35),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recharge Amount",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                InkWell(
                  onTap: _openPlansSheet,
                  child: const Row(
                    children: [
                      Icon(Icons.local_offer, color: appMasterColor, size: 16),
                      SizedBox(width: 5),
                      Text(
                        "View Plans",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: appMasterColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: Text(
                      "₹",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        color: appMasterColor,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  hintText: "0",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isRecharging ? null : _processRecharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appMasterColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: appMasterColor.withValues(alpha: 0.5),
                ),
                child: _isRecharging
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Recharge Now",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

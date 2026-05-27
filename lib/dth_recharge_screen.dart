import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color appMasterColor = Color(0xFF00BFFF);
const Color appBackground = Color(0xFFF4F7FC);

class DthRechargeScreen extends StatefulWidget {
  final double currentBalance;
  const DthRechargeScreen({super.key, required this.currentBalance});

  @override
  State<DthRechargeScreen> createState() => _DthRechargeScreenState();
}

class _DthRechargeScreenState extends State<DthRechargeScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedOperator = '';

  // 🔥 Fetch API Variables (DTH PlanAPI)
  bool _isFetchingDetails = false;
  String? _opCode;

  // Recharge API Variables
  bool _isRecharging = false;

  final String myAwsProxyIp = "http://13.234.211.212/api.php?endpoint=";

  final List<Map<String, dynamic>> operators = [
    {
      'name': 'Airtel DTH',
      'color': Colors.red.shade600,
      'roboticCode': 'AD',
      'dbKey': 'airtel_dth_comm',
    },
    {
      'name': 'Dish TV',
      'color': Colors.orange.shade600,
      'roboticCode': 'DT',
      'dbKey': 'dish_tv_comm',
    },
    {
      'name': 'Sun Direct',
      'color': Colors.amber.shade600,
      'roboticCode': 'SD',
      'dbKey': 'sun_direct_comm',
    },
    {
      'name': 'Tata Play',
      'color': Colors.purple.shade600,
      'roboticCode': 'TS',
      'dbKey': 'tata_play_comm',
    },
    {
      'name': 'Videocon',
      'color': Colors.green.shade600,
      'roboticCode': 'VD',
      'dbKey': 'videocon_comm',
    },
  ];

  String _getProxyUrl(String targetUrl) {
    String encodedUrl = Uri.encodeComponent(
      base64Encode(utf8.encode(targetUrl)),
    );
    return "$myAwsProxyIp$encodedUrl";
  }

  // ==========================================
  // 🟢 1. VERIFY DTH OPERATOR (DTH PlanAPI) 📡
  // ==========================================
  Future<void> _fetchDthOperator() async {
    String dthNumber = _numberController.text.trim();
    if (dthNumber.length < 5) {
      _showSnack("Sahi DTH Number daalein!", Colors.orange);
      return;
    }

    FocusScope.of(context).unfocus(); // Keyboard chupane ke liye
    setState(() => _isFetchingDetails = true);

    try {
      var settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      // Admin panel me humne plan_api wali keys save ki hain
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
          "https://planapi.in/api/Mobile/DthOperatorFetch?apimember_id=$planApiId&api_password=$planApiPass&dth_number=$dthNumber";

      var response = await http.get(Uri.parse(_getProxyUrl(originalUrl)));
      var data = jsonDecode(response.body);

      if (data['ERROR'] == "0" && data['STATUS'] == "1") {
        String apiOp = (data['DthName'] ?? "").toString().toUpperCase();

        if (apiOp.contains("AIRTEL")) {
          _selectedOperator = "Airtel DTH";
        } else if (apiOp.contains("DISH")) {
          _selectedOperator = "Dish TV";
        } else if (apiOp.contains("SUN")) {
          _selectedOperator = "Sun Direct";
        } else if (apiOp.contains("TATA")) {
          _selectedOperator = "Tata Play";
        } else if (apiOp.contains("VIDEOCON") || apiOp.contains("D2H")) {
          _selectedOperator = "Videocon";
        }

        _opCode = data['DthOpCode']?.toString();
        HapticFeedback.lightImpact();
        _showSnack("Verified: $_selectedOperator ✅", Colors.green);
      } else {
        _selectedOperator = '';
        _opCode = null;
        _showSnack(
          data['Message'] ?? "Operator detail nahi mili",
          Colors.orange,
        );
      }
    } catch (e) {
      _showSnack("Operator fetch error via Proxy", Colors.redAccent);
    }
    setState(() => _isFetchingDetails = false);
  }

  // ==========================================
  // 🟡 2. SHOW DTH PLANS BOTTOM SHEET 📋
  // ==========================================
  Future<void> _openPlansSheet() async {
    if (_opCode == null) {
      _showSnack("Pehle Number daalkar 'VERIFY' dabayein!", Colors.orange);
      return;
    }

    _showSnack("Loading DTH Plans...", appMasterColor);

    try {
      var settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      String planApiId =
          settingsDoc.data()?['plan_api_user_id']?.toString() ?? "";
      String rawPlanPass =
          settingsDoc.data()?['plan_api_password']?.toString() ?? "";

      String planApiPass = Uri.encodeComponent(rawPlanPass);

      String originalUrl =
          "https://planapi.in/api/Mobile/DthPlans?apimember_id=$planApiId&api_password=$planApiPass&operatorcode=$_opCode";
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
                  "$_selectedOperator Plans",
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
                                  List categoryArray = rdata[cat];

                                  // Nested array flattening
                                  List allPlans = [];
                                  for (var item in categoryArray) {
                                    if (item['Details'] != null) {
                                      allPlans.addAll(item['Details']);
                                    }
                                  }

                                  return ListView.builder(
                                    padding: const EdgeInsets.all(15),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: allPlans.length,
                                    itemBuilder: (context, i) {
                                      var plan = allPlans[i];
                                      List pricingList =
                                          plan['PricingList'] ?? [];

                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.only(
                                          bottom: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                plan['PlanName'] ?? 'DTH Plan',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "${plan['Channels'] ?? ''} | ${plan['PaidChannels'] ?? ''}",
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: pricingList.map((
                                                  priceItem,
                                                ) {
                                                  String pureAmount =
                                                      priceItem['Amount']
                                                          .toString()
                                                          .replaceAll(
                                                            RegExp(r'[^0-9.]'),
                                                            '',
                                                          );
                                                  return InkWell(
                                                    onTap: () {
                                                      setState(
                                                        () =>
                                                            _amountController
                                                                    .text =
                                                                pureAmount,
                                                      );
                                                      Navigator.pop(context);
                                                      HapticFeedback.lightImpact();
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: appMasterColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        border: Border.all(
                                                          color: appMasterColor
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "₹$pureAmount (${priceItem['Month']})",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: appMasterColor,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
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
      _showSnack("Plans load karne mein error", Colors.red);
    }
  }

  // ==========================================
  // 🔴 3. MAIN RECHARGE API (WITH COMMISSION ENGINE)
  // ==========================================
  Future<void> _processRecharge() async {
    String dthNumber = _numberController.text.trim();
    String amountStr = _amountController.text.trim();

    if (dthNumber.isEmpty || dthNumber.length < 5) {
      _showSnack("Sahi DTH / VC Number daalein!", Colors.orange);
      return;
    }
    if (_selectedOperator.isEmpty) {
      _showSnack("Please select a DTH Operator!", Colors.orange);
      return;
    }
    if (amountStr.isEmpty) {
      _showSnack("Please enter Recharge Amount!", Colors.orange);
      return;
    }

    double rechargeAmount = double.parse(amountStr);

    setState(() => _isRecharging = true);

    try {
      var settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      var configData = settingsDoc.data();

      String apiMemberId = configData?['robotic_member_id']?.toString() ?? "";
      String apiPassword =
          configData?['robotic_api_password']?.toString() ?? "";

      if (apiMemberId.isEmpty || apiPassword.isEmpty) {
        _showSnack(
          "Admin Setup Incomplete: Robotic Credentials missing!",
          Colors.redAccent,
        );
        setState(() => _isRecharging = false);
        return;
      }

      double commissionPercentage = 0.0;
      var opData = operators.firstWhere(
        (op) => op['name'] == _selectedOperator,
      );
      String dbKey = opData['dbKey'];

      commissionPercentage =
          double.tryParse(configData?[dbKey]?.toString() ?? '0') ?? 0.0;

      double commissionEarned = (rechargeAmount * commissionPercentage) / 100;
      double finalAmountToDeduct = rechargeAmount - commissionEarned;

      if (finalAmountToDeduct > widget.currentBalance) {
        _showSnack(
          "Insufficient Balance! Aapko ₹$finalAmountToDeduct chahiye.",
          Colors.red,
        );
        setState(() => _isRecharging = false);
        return;
      }

      String safeApiPassword = Uri.encodeComponent(apiPassword);
      String roboticOpCode = opData['roboticCode'];
      String txnId = "TXN${DateTime.now().millisecondsSinceEpoch}";
      int apiAmount = rechargeAmount.toInt();

      String originalUrl =
          "https://api.roboticexchange.in/Robotics/webservice/GetMobileRecharge?Apimember_id=$apiMemberId&Api_password=$safeApiPassword&Mobile_no=$dthNumber&Operator_code=$roboticOpCode&Amount=$apiAmount&Member_request_txnid=$txnId";

      var response = await http.get(Uri.parse(_getProxyUrl(originalUrl)));
      var data = jsonDecode(response.body);

      if (data['STATUS'] == 1 || data['STATUS'] == 2) {
        String finalStatus = data['STATUS'] == 1 ? "Success" : "Processing";
        String uid = FirebaseAuth.instance.currentUser!.uid;

        // Wallet Se Deduction
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'walletBalance': FieldValue.increment(-finalAmountToDeduct),
        });

        // 🔥 History Entry (Mobile wale fields se 100% match)
        await FirebaseFirestore.instance.collection('recharges').add({
          'userId': uid,
          'number': dthNumber,
          'operator': _selectedOperator,
          'amount': rechargeAmount, // Poora Recharge Amount
          'commissionEarned': commissionEarned, // Pura Profit
          'finalDeducted': finalAmountToDeduct, // Wallet se jo kata
          'status': finalStatus,
          'txnId': txnId,
          'apiOpTxnId': data['OPTRANSID'] ?? "",
          'type': 'DTH',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          _showSnack(
            "DTH Recharge $finalStatus! 🎉 You saved ₹$commissionEarned",
            Colors.green,
          );
        }
      } else {
        String errorMsg = data['MESSAGE'] ?? "Unknown Error from API";
        _showSnack("Failed: $errorMsg", Colors.red);
      }
    } catch (e) {
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
          "DTH Recharge",
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
                keyboardType: TextInputType.text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.tv,
                    color: appMasterColor,
                    size: 24,
                  ),
                  hintText: "Subscriber ID / VC Number",
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
                      : TextButton(
                          onPressed: _fetchDthOperator,
                          child: const Text(
                            "VERIFY",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: appMasterColor,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            Text(
              "Select DTH Operator",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 15),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: operators.map((op) {
                  bool isSelected = _selectedOperator == op['name'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedOperator = op['name']);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 90,
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? op['color'].withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isSelected
                                ? op['color']
                                : Colors.grey.shade200,
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
                          op['name'].toString().replaceAll(" ", "\n"),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: op['color'],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
                        "Recharge DTH",
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

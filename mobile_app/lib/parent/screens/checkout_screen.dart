import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'wallet_page.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  late final List<Map<String, dynamic>> _cart;
  late final String _childId;
  late final String _childName;
  late final double _total;

  bool _initialized = false;
  bool _isProcessing = false;
  bool _dataLoaded = false;
  String? _error;

  double _walletBalance = 0;
  String _childMealConnectId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _cart = (args['cart'] as List).cast<Map<String, dynamic>>();
    _childId = args['childId'] as String;
    _childName = args['childName'] as String;
    _childMealConnectId = (args['childMealConnectId'] as String?) ?? '';
    _total = _cart.fold<double>(0, (acc, item) {
      final days = (item['days'] as List<dynamic>?) ?? [];
      return acc + days.fold<double>(0, (s, d) {
        final day = d as Map<String, dynamic>;
        return s + (item['price'] as double) * (day['qty'] as int);
      });
    });

    _loadParentData();
  }

  Future<void> _loadParentData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('parents')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() {
      _walletBalance =
          (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      _dataLoaded = true;
    });
  }

  bool get _hasSufficientBalance => _walletBalance >= _total;
  double get _deficit =>
      (_total - _walletBalance).clamp(0, double.infinity);

  Future<void> _onPay() async {
    if (!_hasSufficientBalance) {
      setState(() => _error =
          'Insufficient balance. Please top up your wallet first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // One orderId groups all items from this checkout into a single order
      final orderId = db.collection('mealSelections').doc().id;

      for (final item in _cart) {
        final days = (item['days'] as List<dynamic>?) ?? [];
        for (final dayEntry in days) {
          final day = dayEntry as Map<String, dynamic>;
          final ref = db.collection('mealSelections').doc();
          batch.set(ref, {
            'selectionId': ref.id,
            'orderId': orderId,
            'childId': _childId,
            'childName': _childName,
            'childMealConnectId': _childMealConnectId,
            'mealId': item['mealId'],
            'parentId': uid,
            'cafeteriaId': item['cafeteriaId'] ?? '',
            'mealName': item['mealName'],
            'price': item['price'],
            'quantity': day['qty'],
            'deliveryDate':
                Timestamp.fromDate(day['date'] as DateTime),
            'deliveryDay': day['dayName'],
            'selectionDate': FieldValue.serverTimestamp(),
            'status': 'pending',
            'isDelivered': false,
          });
        }
      }

      batch.update(db.collection('parents').doc(uid), {
        'walletBalance': FieldValue.increment(-_total),
      });

      await batch.commit();

      if (mounted) _showSuccess();
    } catch (_) {
      setState(() {
        _isProcessing = false;
        _error = 'Payment failed. Please try again.';
      });
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_pink, _orange]),
              ),
              child:
                  const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Placed!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Your order for $_childName has been placed successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9B9B9B)),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [_pink, _orange]),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context)
                      .popUntil(ModalRoute.withName('/parent-home'));
                },
                child: const Text(
                  'DONE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CHECKOUT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: !_dataLoaded
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_pink),
                ),
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummary(),
          const SizedBox(height: 16),
          _buildWalletCard(),
          if (!_hasSufficientBalance) ...[
            const SizedBox(height: 16),
            _buildInsufficientCard(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFE53935), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 24),
          _buildPayButton(),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return _section(
      title: 'Order Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._cart.map((item) {
            final days = (item['days'] as List<dynamic>?) ?? [];
            final mealTotal = days.fold<double>(0, (s, d) {
              final day = d as Map<String, dynamic>;
              return s +
                  (item['price'] as double) * (day['qty'] as int);
            });
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['mealName'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'Rs. ${mealTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  ...days.map((d) {
                    final day = d as Map<String, dynamic>;
                    final date = day['date'] as DateTime;
                    final dayName = day['dayName'] as String;
                    final qty = day['qty'] as int;
                    final price = item['price'] as double;
                    const mo = [
                      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May',
                      'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                    ];
                    return Padding(
                      padding:
                          const EdgeInsets.only(top: 4, left: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$dayName, ${mo[date.month]} ${date.day}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9B9B9B)),
                            ),
                          ),
                          Text(
                            '× $qty   Rs. ${(price * qty).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9B9B9B)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          const Divider(color: Color(0xFFEEEEEE)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A))),
              Text(
                'Rs. ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _pink),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_pink, _orange]),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet Balance',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF9B9B9B))),
                Text(
                  'Rs. ${_walletBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
          if (!_hasSufficientBalance)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Rs. ${_deficit.toStringAsFixed(2)} short',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE53935)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsufficientCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFF5A623).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Color(0xFFF5A623), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Insufficient Balance',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B6900))),
                const SizedBox(height: 2),
                Text(
                  'You need Rs. ${_deficit.toStringAsFixed(2)} more. Top up your wallet to continue.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8B6900)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    if (!_hasSufficientBalance) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFF5A623), Color(0xFFFF8C00)]),
            borderRadius: BorderRadius.circular(27),
          ),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WalletPage(popOnSuccess: true)),
            ).then((_) => _loadParentData()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27)),
            ),
            icon: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 18),
            label: const Text(
              'TOP UP WALLET',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isProcessing
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_pink),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_pink, _orange],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(27),
              ),
              child: ElevatedButton(
                onPressed: _onPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27)),
                ),
                child: Text(
                  'PAY  Rs. ${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

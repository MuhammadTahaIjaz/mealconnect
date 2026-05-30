import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class TopUpPaymentPage extends StatefulWidget {
  final double amount;
  const TopUpPaymentPage({super.key, required this.amount});

  @override
  State<TopUpPaymentPage> createState() => _TopUpPaymentPageState();
}

class _TopUpPaymentPageState extends State<TopUpPaymentPage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);
  static const _backendUrl = 'http://72.61.254.215:3000';

  // Customer / saved card state
  bool _loadingCustomer = true;
  String? _stripeCustomerId;
  Map<String, dynamic>? _savedCard; // {id, last4, brand}
  bool _useSavedCard = true;

  // Payment state
  bool _cardComplete = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      final parentDoc = await FirebaseFirestore.instance
          .collection('parents')
          .doc(uid)
          .get();

      String? customerId =
          parentDoc.data()?['stripeCustomerId'] as String?;

      // Create a Stripe customer if this is the first time
      if (customerId == null) {
        final response = await http.post(
          Uri.parse('$_backendUrl/create-customer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': user.email, 'uid': uid}),
        );
        if (response.statusCode == 200) {
          customerId =
              jsonDecode(response.body)['customerId'] as String;
          await FirebaseFirestore.instance
              .collection('parents')
              .doc(uid)
              .update({'stripeCustomerId': customerId});
        }
      }

      _stripeCustomerId = customerId;

      // Fetch saved payment methods
      if (customerId != null) {
        final pmResponse = await http.post(
          Uri.parse('$_backendUrl/list-payment-methods'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'customerId': customerId}),
        );
        if (pmResponse.statusCode == 200) {
          final methods =
              jsonDecode(pmResponse.body)['paymentMethods'] as List;
          if (methods.isNotEmpty) {
            final card = methods.first;
            _savedCard = {
              'id': card['id'] as String,
              'last4': card['card']['last4'] as String,
              'brand': card['card']['brand'] as String,
            };
          }
        }
      }
    } catch (_) {
      // Falls through — user will see CardFormField
    } finally {
      if (mounted) setState(() {
        _loadingCustomer = false;
        if (_savedCard == null) { _useSavedCard = false; }
      });
    }
  }

  bool get _canPay =>
      _useSavedCard ? _savedCard != null : _cardComplete;

  Future<void> _pay() async {
    if (!_canPay || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final amountCents = (widget.amount * 100).toInt();

      final body = <String, dynamic>{'amountCents': amountCents};
      if (_stripeCustomerId != null) {
        body['customerId'] = _stripeCustomerId;
      }
      if (_useSavedCard && _savedCard != null) {
        body['paymentMethodId'] = _savedCard!['id'];
      }

      final response = await http.post(
        Uri.parse('$_backendUrl/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw jsonDecode(response.body)['error'] as String? ??
            'Server error';
      }

      final clientSecret =
          jsonDecode(response.body)['clientSecret'] as String;

      if (_useSavedCard && _savedCard != null) {
        // PaymentIntent already has the payment_method set server-side
        await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: clientSecret,
        );
      } else {
        // New card entered via CardFormField
        await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: clientSecret,
          data: const PaymentMethodParams.card(
            paymentMethodData: PaymentMethodData(),
          ),
        );
      }

      await FirebaseFirestore.instance
          .collection('parents')
          .doc(uid)
          .update(
              {'walletBalance': FieldValue.increment(widget.amount)});

      if (mounted) Navigator.pop(context, true);
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled && mounted) {
        _showError(e.error.localizedMessage ?? 'Payment failed');
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          'TOP UP',
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
        child: _loadingCustomer
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_pink),
                ),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAmountCard(),
                    const SizedBox(height: 28),
                    _buildPaymentSection(),
                    const SizedBox(height: 28),
                    _buildPayButton(),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 13, color: Color(0xFF9B9B9B)),
                        SizedBox(width: 5),
                        Text(
                          'Payments secured by Stripe',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9B9B9B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_pink, _orange]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _pink.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white70, size: 32),
          const SizedBox(height: 8),
          const Text(
            'Adding to Wallet',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${widget.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    // Show saved card if available and user hasn't chosen to use a new one
    if (_savedCard != null && _useSavedCard) {
      return _buildSavedCardSection();
    }
    return _buildNewCardSection();
  }

  Widget _buildSavedCardSection() {
    final brand = (_savedCard!['brand'] as String).toUpperCase();
    final last4 = _savedCard!['last4'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.credit_card,
                    color: Color(0xFF1A1A1A), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$brand  ****  $last4',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Text(
                      'Saved card',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF9B9B9B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle,
                  color: Color(0xFF43A047), size: 22),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _useSavedCard = false),
          child: const Text(
            'Use a different card',
            style: TextStyle(
              fontSize: 13,
              color: _pink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Card Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (_savedCard != null)
              GestureDetector(
                onTap: () => setState(() => _useSavedCard = true),
                child: const Text(
                  'Use saved card',
                  style: TextStyle(
                    fontSize: 13,
                    color: _pink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CardFormField(
            style: CardFormStyle(
              backgroundColor: Colors.white,
              textColor: const Color(0xFF1A1A1A),
              placeholderColor: const Color(0xFF9B9B9B),
              fontSize: 15,
              cursorColor: _pink,
            ),
            onCardChanged: (details) {
              setState(
                  () => _cardComplete = details?.complete ?? false);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton() {
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
                gradient: LinearGradient(
                  colors: _canPay
                      ? const [_pink, _orange]
                      : const [Color(0xFFCCCCCC), Color(0xFFCCCCCC)],
                ),
                borderRadius: BorderRadius.circular(27),
              ),
              child: ElevatedButton(
                onPressed: _canPay ? _pay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27)),
                ),
                child: Text(
                  'PAY  \$${widget.amount.toStringAsFixed(0)}',
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
}

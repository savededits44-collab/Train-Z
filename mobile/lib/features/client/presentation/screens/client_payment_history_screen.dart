import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_payment_receipt_screen.dart';

/// Screen displaying the client's historical payment transactions fetched directly
/// from Firebase, with filter tabs, payment status badges, and receipt viewing.
class ClientPaymentHistoryScreen extends StatefulWidget {
  final String clientId;

  const ClientPaymentHistoryScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientPaymentHistoryScreen> createState() => _ClientPaymentHistoryScreenState();
}

class _ClientPaymentHistoryScreenState extends State<ClientPaymentHistoryScreen> {
  final _firestoreService = FirestoreService();
  int _selectedFilterIndex = 0; // 0: All, 1: Successful, 2: Failed

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment History',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 21.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip(0, 'All'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Successful'),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Failed / Incomplete'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // Streamed Payment List
          Expanded(
            child: StreamBuilder<List<PaymentModel>>(
              stream: _firestoreService.streamClientPayments(widget.clientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: kDark),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load payment history: ${snapshot.error}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFFDC2626)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final allPayments = snapshot.data ?? [];
                final filtered = allPayments.where((p) {
                  if (_selectedFilterIndex == 1) return p.isSuccess;
                  if (_selectedFilterIndex == 2) return p.isFailed || p.isInitiated;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(sf);
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildPaymentCard(context, item, sf);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kDark : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? kLime : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, PaymentModel item, double sf) {
    final isSuccess = item.isSuccess;
    final isFailed = item.isFailed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientPaymentReceiptScreen(payment: item),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.displayPackageName,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (15.0 * sf).clamp(13.5, 17.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${item.amount}',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (16.0 * sf).clamp(14.5, 18.5),
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${item.sessionsCount ?? 1} Sessions',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: kGrey)),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(item.createdAt),
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                    ),
                  ],
                ),
                if (item.trainerName != null && item.trainerName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Iconsax.user, size: 12, color: kGrey),
                      const SizedBox(width: 4),
                      Text(
                        'Coach: ${item.trainerName}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID: ${item.razorpayPaymentId ?? item.gatewayOrderId ?? item.id.substring(0, 8)}',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: kGrey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? const Color(0xFFDCFCE7)
                            : isFailed
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.status.toFirestore(),
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isSuccess
                              ? const Color(0xFF15803D)
                              : isFailed
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(double sf) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.receipt_2, size: 36, color: kDark),
            ),
            const SizedBox(height: 16),
            Text(
              'No Payment Records',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (17.0 * sf).clamp(15.0, 20.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'When you purchase training packages, receipts and payment records will appear here.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Recent';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[(dt.month - 1) % 12]} ${dt.year}';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../services/booking_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/support_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/support_ticket_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Form screen allowing verified Clients to raise a complaint or support request.
class ClientSubmitTicketScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String? clientEmail;
  final BookingModel? initialBooking;

  const ClientSubmitTicketScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientEmail,
    this.initialBooking,
  });

  @override
  State<ClientSubmitTicketScreen> createState() => _ClientSubmitTicketScreenState();
}

class _ClientSubmitTicketScreenState extends State<ClientSubmitTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  SupportTicketCategory _selectedCategory = SupportTicketCategory.bookingIssue;
  BookingModel? _selectedBooking;
  List<BookingModel> _clientBookings = [];
  bool _isLoadingBookings = true;

  String? _attachmentName;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedBooking = widget.initialBooking;
    _loadClientBookings();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadClientBookings() async {
    try {
      final bookings = await FirestoreService().streamClientBookings(widget.clientId).first;
      if (mounted) {
        setState(() {
          _clientBookings = bookings;
          _isLoadingBookings = false;
        });
      }
    } catch (_) {
      // Fallback to BookingService in-memory store
      if (mounted) {
        setState(() {
          _clientBookings = BookingService.instance.allBookings
              .where((b) => b.clientId == widget.clientId)
              .toList();
          _isLoadingBookings = false;
        });
      }
    }
  }

  Future<void> _handleAttachFile() async {
    // Show mock file selection dialog for testing & environments without image_picker
    final selectedOption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Screenshot or Document', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attach a relevant screenshot or document to help us resolve your issue faster (Max 5MB: JPG, PNG, PDF):',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Iconsax.image, color: kDark),
              title: const Text('Workout Screenshot', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('workout_error_proof.png (1.2 MB)', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => Navigator.pop(ctx, 'workout_error_proof.png'),
            ),
            ListTile(
              leading: const Icon(Iconsax.receipt, color: kDark),
              title: const Text('Payment Transaction Proof', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('razorpay_receipt_proof.jpg (850 KB)', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => Navigator.pop(ctx, 'razorpay_receipt_proof.jpg'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );

    if (selectedOption != null) {
      if (!mounted) return;
      setState(() {
        _attachmentName = selectedOption;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attached "$selectedOption"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog before submission
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Iconsax.message_question, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Submit Support Request?',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please confirm that the information provided is accurate. Our support specialists will review your ticket promptly.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category: ${_selectedCategory.label}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: kDark)),
                  const SizedBox(height: 4),
                  Text('Subject: ${_subjectController.text.trim()}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF4B5563))),
                  if (_selectedBooking != null) ...[
                    const SizedBox(height: 4),
                    Text('Booking: ${_selectedBooking!.bookingReference}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF4B5563))),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back to Edit', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              foregroundColor: kLime,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm & Submit', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (shouldSubmit != true) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final ticket = await SupportService.instance.createTicket(
        clientId: widget.clientId,
        clientName: widget.clientName,
        clientEmail: widget.clientEmail,
        category: _selectedCategory,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        bookingId: _selectedBooking?.id,
        bookingReference: _selectedBooking?.bookingReference,
        attachmentUrl: _attachmentName != null ? 'https://storage.trainz.app/support/$_attachmentName' : null,
        attachmentName: _attachmentName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Support request #${ticket.ticketNumber} submitted successfully!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e is TrainZException ? e.message : 'Failed to submit request: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Raise a Request',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Advisory Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Iconsax.info_circle, size: 18, color: kDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Submit your inquiry or report a problem. Our support team will review your case and reply in your ticket thread.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(10.0, 12.0),
                          color: const Color(0xFF4B5563),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Category Selector
              _buildFieldLabel('COMPLAINT CATEGORY', sf),
              const SizedBox(height: 8),
              DropdownButtonFormField<SupportTicketCategory>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDark, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: SupportTicketCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(
                      cat.label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (12.5 * sf).clamp(11.5, 13.5),
                        fontWeight: FontWeight.w600,
                        color: kDark,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (cat) {
                  if (cat != null) setState(() => _selectedCategory = cat);
                },
              ),

              const SizedBox(height: 18),

              // Related Booking (Optional)
              _buildFieldLabel('RELATED BOOKING (OPTIONAL)', sf),
              const SizedBox(height: 8),
              if (_isLoadingBookings)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: const Text('Loading your recent bookings...', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF9CA3AF))),
                )
              else
                DropdownButtonFormField<BookingModel?>(
                  initialValue: _selectedBooking,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDark, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<BookingModel?>(
                      value: null,
                      child: Text('None / General Inquiry', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF6B7280))),
                    ),
                    ..._clientBookings.map((b) {
                      return DropdownMenuItem<BookingModel?>(
                        value: b,
                        child: Text(
                          '${b.bookingReference} • ${b.displayTrainerName} (${b.displayStatus})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: kDark),
                        ),
                      );
                    }),
                  ],
                  onChanged: (b) => setState(() => _selectedBooking = b),
                ),

              const SizedBox(height: 18),

              // Subject
              _buildFieldLabel('SUBJECT', sf),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                maxLength: 100,
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Please enter a subject (minimum 3 characters).';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Brief summary of the problem or request...',
                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: (12.0 * sf).clamp(11.0, 13.0), color: const Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDark, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  counterText: '',
                ),
                style: TextStyle(fontFamily: 'Poppins', fontSize: (12.5 * sf).clamp(11.5, 13.5), color: kDark),
              ),

              const SizedBox(height: 18),

              // Detailed Description
              _buildFieldLabel('DETAILED DESCRIPTION', sf),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                minLines: 4,
                maxLength: 1000,
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Please provide more details (minimum 10 characters).';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Provide complete details regarding the situation, steps to reproduce, or workout context...',
                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: (12.0 * sf).clamp(11.0, 13.0), color: const Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDark, width: 1.5)),
                  contentPadding: const EdgeInsets.all(14),
                ),
                style: TextStyle(fontFamily: 'Poppins', fontSize: (12.5 * sf).clamp(11.5, 13.5), color: kDark),
              ),

              const SizedBox(height: 14),

              // Attachment Uploader
              _buildFieldLabel('OPTIONAL ATTACHMENT OR SCREENSHOT', sf),
              const SizedBox(height: 8),
              if (_attachmentName != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _attachmentName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFF166534)),
                        onPressed: () => setState(() {
                          _attachmentName = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: _handleAttachFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.document_upload, size: 18, color: kDark),
                        const SizedBox(width: 8),
                        Text(
                          'Upload Screenshot or Proof (Max 5MB)',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.5, 12.5),
                            fontWeight: FontWeight.w600,
                            color: kDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Error display
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDark,
                    foregroundColor: kLime,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                        )
                      : const Text(
                          'Submit Support Request',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kLime,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, double sf) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Syne',
        fontSize: (11.0 * sf).clamp(10.0, 12.0),
        fontWeight: FontWeight.w800,
        color: const Color(0xFF888888),
        letterSpacing: 0.8,
      ),
    );
  }
}

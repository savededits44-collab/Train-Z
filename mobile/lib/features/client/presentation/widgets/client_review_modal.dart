import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../services/review_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/review_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Modal bottom sheet allowing verified clients to rate and review
/// their personal trainer after completing a 60-minute training session.
class ClientReviewModal extends StatefulWidget {
  final BookingModel booking;
  final ReviewModel? existingReview;
  final VoidCallback? onReviewSubmitted;

  const ClientReviewModal({
    super.key,
    required this.booking,
    this.existingReview,
    this.onReviewSubmitted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required BookingModel booking,
    ReviewModel? existingReview,
    VoidCallback? onReviewSubmitted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientReviewModal(
        booking: booking,
        existingReview: existingReview,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  State<ClientReviewModal> createState() => _ClientReviewModalState();
}

class _ClientReviewModalState extends State<ClientReviewModal> {
  final _reviewService = ReviewService.instance;
  final _commentController = TextEditingController();

  double _rating = 5.0;
  final Set<String> _selectedCategories = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _availableCategories = [
    'Punctual & Prepared',
    'Technique & Form',
    'Challenging Workout',
    'Highly Motivating',
    'Clear Guidance',
    'Goal Oriented',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _commentController.text = widget.existingReview!.comment;
      _selectedCategories.addAll(widget.existingReview!.categories);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5.0) return '5.0 ★ Excellent Workout';
    if (rating >= 4.0) return '4.0 ★ Very Good Session';
    if (rating >= 3.0) return '3.0 ★ Good Workout';
    if (rating >= 2.0) return '2.0 ★ Fair Workout';
    return '1.0 ★ Needs Improvement';
  }

  Future<void> _handleSubmit() async {
    final comment = _commentController.text.trim();

    if (!widget.booking.isCompleted) {
      setState(() => _errorMessage = 'Reviews can only be submitted for completed sessions.');
      return;
    }

    if (comment.length < 5) {
      setState(() => _errorMessage = 'Please provide at least 5 characters of feedback.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      User? user;
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}
      final rawClientName = user?.displayName ?? widget.booking.clientName;

      await _reviewService.submitReview(
        bookingId: widget.booking.id,
        clientId: widget.booking.clientId,
        trainerId: widget.booking.trainerId,
        rating: _rating,
        comment: comment,
        categories: _selectedCategories.toList(),
        clientName: rawClientName,
        clientPhotoUrl: user?.photoURL ?? widget.booking.clientPhotoUrl,
        bookingContext: widget.booking,
      );

      if (!mounted) return;

      widget.onReviewSubmitted?.call();
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingReview != null
                ? 'Review updated successfully!'
                : 'Review submitted! Thank you for rating your trainer.',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e is TrainZException ? e.message : 'Failed to submit review: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final isEditing = widget.existingReview != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: kDark,
                    backgroundImage: widget.booking.trainerPhotoUrl != null &&
                            widget.booking.trainerPhotoUrl!.isNotEmpty
                        ? NetworkImage(widget.booking.trainerPhotoUrl!)
                        : null,
                    child: widget.booking.trainerPhotoUrl == null ||
                            widget.booking.trainerPhotoUrl!.isEmpty
                        ? Text(
                            widget.booking.displayTrainerName.isNotEmpty
                                ? widget.booking.displayTrainerName[0].toUpperCase()
                                : 'T',
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              color: kLime,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Session Review' : 'Rate Your Training Session',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (16.0 * sf).clamp(15.0, 18.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.booking.displayTrainerName} • 60-Min Training',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.5, 12.5),
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: kDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),

              // Star Rating Selector
              Center(
                child: Column(
                  children: [
                    Text(
                      'HOW WAS YOUR WORKOUT?',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (11.0 * sf).clamp(10.0, 12.0),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF888888),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        final isFilled = _rating >= starIndex;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _rating = starIndex.toDouble());
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.star_rounded,
                              size: 40,
                              color: isFilled
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        _getRatingLabel(_rating),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Categories / Tags
              Text(
                'WORKOUT HIGHLIGHTS (OPTIONAL)',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.0 * sf).clamp(10.0, 12.0),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableCategories.map((cat) {
                  final isSelected = _selectedCategories.contains(cat);
                  return FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: kDark,
                    backgroundColor: const Color(0xFFF9FAFB),
                    checkmarkColor: kLime,
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.0),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : kDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? kDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    onSelected: (selected) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (selected) {
                          if (_selectedCategories.length < 5) {
                            _selectedCategories.add(cat);
                          }
                        } else {
                          _selectedCategories.remove(cat);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Written Feedback
              Text(
                'WRITTEN FEEDBACK',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.0 * sf).clamp(10.0, 12.0),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                minLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Share your coaching experience, form tips received, or workout intensity...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (11.5 * sf).clamp(10.5, 12.5),
                    color: const Color(0xFF9CA3AF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kDark, width: 1.5),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.0 * sf).clamp(11.0, 13.0),
                  color: kDark,
                ),
              ),

              // Athlete Privacy Callout
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Athlete Privacy: Published as "Rahul S." (Verified Athlete). Your private home address and personal contact details are never shared.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (10.0 * sf).clamp(9.0, 11.0),
                          color: const Color(0xFF166534),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                      : Text(
                          isEditing ? 'Update Review' : 'Submit Review',
                          style: const TextStyle(
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
}

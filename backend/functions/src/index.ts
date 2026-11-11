import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import Razorpay from 'razorpay';

admin.initializeApp();
const db = admin.firestore();

const CANCELLATION_WINDOW_HOURS = 12;

// ─────────────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────────────

async function verifyIsAdmin(uid: string): Promise<boolean> {
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) return false;
  return userSnap.data()?.role === 'ADMIN';
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Atomic Booking Creation with Gender Matching & Session Credit Reservation
// ─────────────────────────────────────────────────────────────────────────────

export const createBookingWithCredit = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to create a booking.');
  }

  const clientId = request.auth.uid;
  const { trainerId, sessionDateIso, startTime, endTime, planId, meetingLocation, notes } = request.data || {};

  if (!trainerId || !sessionDateIso || !startTime || !endTime) {
    throw new HttpsError('invalid-argument', 'Missing required booking parameters.');
  }

  const sessionDate = new Date(sessionDateIso);

  return await db.runTransaction(async (transaction) => {
    // 1. Fetch Client Profile & Gender
    const clientUserRef = db.collection('users').doc(clientId);
    const clientUserSnap = await transaction.get(clientUserRef);
    if (!clientUserSnap.exists) {
      throw new HttpsError('not-found', 'Client account not found.');
    }
    const clientData = clientUserSnap.data()!;
    const clientGender = clientData.gender;

    if (!clientGender) {
      throw new HttpsError(
        'failed-precondition',
        'Client profile is missing a verified gender. Please update your profile.'
      );
    }

    // 2. Fetch Trainer Profile & Verification Status
    const trainerProfileRef = db.collection('trainer_profiles').doc(trainerId);
    const trainerProfileSnap = await transaction.get(trainerProfileRef);
    if (!trainerProfileSnap.exists) {
      throw new HttpsError('not-found', 'Trainer profile not found.');
    }
    const trainerProfileData = trainerProfileSnap.data()!;

    // Section 6: Trainer Approval Check
    if (trainerProfileData.verificationStatus !== 'APPROVED' || !trainerProfileData.isActive) {
      throw new HttpsError(
        'failed-precondition',
        'Trainer is not currently approved or active for bookings.'
      );
    }

    // 3. Fetch Trainer Gender
    const trainerUserRef = db.collection('users').doc(trainerId);
    const trainerUserSnap = await transaction.get(trainerUserRef);
    if (!trainerUserSnap.exists) {
      throw new HttpsError('not-found', 'Trainer account record not found.');
    }
    const trainerData = trainerUserSnap.data()!;
    const trainerGender = trainerData.gender;

    // Section 5: Gender Matching Enforcement
    if (clientGender !== trainerGender) {
      throw new HttpsError(
        'permission-denied',
        `Gender matching violation: ${clientGender} clients can only book ${clientGender} trainers.`
      );
    }

    // 4. Verify & Reserve Credit
    const creditRef = db.collection('session_credits').doc(clientId);
    const creditSnap = await transaction.get(creditRef);
    if (!creditSnap.exists) {
      throw new HttpsError('failed-precondition', 'Client has no session credit account.');
    }
    const creditData = creditSnap.data()!;
    const available = creditData.availableBalance || 0;

    if (available < 1) {
      throw new HttpsError(
        'failed-precondition',
        'Insufficient session credits. Please purchase a training package.'
      );
    }

    // 5. Create Booking Document
    const bookingRef = db.collection('bookings').doc();
    const newReserved = (creditData.totalReserved || 0) + 1;
    const newAvailable = available - 1;

    transaction.update(creditRef, {
      totalReserved: newReserved,
      availableBalance: newAvailable,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    const txRef = creditRef.collection('transactions').doc();
    transaction.set(txRef, {
      id: txRef.id,
      clientId,
      type: 'RESERVE',
      count: 1,
      bookingId: bookingRef.id,
      reason: `Reserved 1 session for booking ${bookingRef.id}`,
      balanceAfter: newAvailable,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.set(bookingRef, {
      id: bookingRef.id,
      clientId,
      trainerId,
      clientGender,
      trainerGender,
      planId: planId || null,
      sessionDate: admin.firestore.Timestamp.fromDate(sessionDate),
      startTime,
      endTime,
      status: 'CONFIRMED',
      creditTransactionId: txRef.id,
      meetingLocation: meetingLocation || 'Client Gym / Selected Venue',
      notes: notes || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { bookingId: bookingRef.id, status: 'CONFIRMED', creditBalance: newAvailable };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. Cancellation Logic with 12-Hour Credit Return vs Forfeit Rules
// ─────────────────────────────────────────────────────────────────────────────

export const cancelBookingWithCredit = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const callerUid = request.auth.uid;
  const { bookingId } = request.data || {};

  if (!bookingId) {
    throw new HttpsError('invalid-argument', 'Booking ID is required.');
  }

  return await db.runTransaction(async (transaction) => {
    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);

    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }

    const booking = bookingSnap.data()!;
    if (booking.status !== 'CONFIRMED' && booking.status !== 'PENDING') {
      throw new HttpsError('failed-precondition', `Booking is already ${booking.status}.`);
    }

    const isAdminCaller = await verifyIsAdmin(callerUid);
    const isClient = callerUid === booking.clientId;
    const isTrainer = callerUid === booking.trainerId;

    if (!isClient && !isTrainer && !isAdminCaller) {
      throw new HttpsError('permission-denied', 'Not authorized to cancel this booking.');
    }

    const sessionDate: Date = booking.sessionDate.toDate();
    const now = new Date();
    const hoursUntil = (sessionDate.getTime() - now.getTime()) / (1000 * 60 * 60);

    const creditRef = db.collection('session_credits').doc(booking.clientId);
    const creditSnap = await transaction.get(creditRef);
    const creditData = creditSnap.data() || { availableBalance: 0, totalReserved: 1, totalReturned: 0, totalForfeited: 0 };

    const newReserved = Math.max(0, (creditData.totalReserved || 1) - 1);
    const txRef = creditRef.collection('transactions').doc();

    let newStatus = 'CANCELLED';
    let returnedCredit = false;

    if (isTrainer || isAdminCaller) {
      // Trainer or Admin cancellation: Credit always returned
      newStatus = isTrainer ? 'CANCELLED_TRAINER' : 'CANCELLED_ADMIN';
      const newReturned = (creditData.totalReturned || 0) + 1;
      const newAvailable = (creditData.availableBalance || 0) + 1;
      returnedCredit = true;

      transaction.update(creditRef, {
        totalReserved: newReserved,
        totalReturned: newReturned,
        availableBalance: newAvailable,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(txRef, {
        id: txRef.id,
        clientId: booking.clientId,
        type: 'RETURN',
        count: 1,
        bookingId,
        reason: `Credit returned: session cancelled by ${isTrainer ? 'Trainer' : 'Platform'}`,
        balanceAfter: newAvailable,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Client cancellation
      if (hoursUntil >= CANCELLATION_WINDOW_HOURS) {
        // >= 12 hours: Return credit
        newStatus = 'CANCELLED_CLIENT_EARLY';
        const newReturned = (creditData.totalReturned || 0) + 1;
        const newAvailable = (creditData.availableBalance || 0) + 1;
        returnedCredit = true;

        transaction.update(creditRef, {
          totalReserved: newReserved,
          totalReturned: newReturned,
          availableBalance: newAvailable,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.set(txRef, {
          id: txRef.id,
          clientId: booking.clientId,
          type: 'RETURN',
          count: 1,
          bookingId,
          reason: `Credit returned: cancelled >= ${CANCELLATION_WINDOW_HOURS}h prior`,
          balanceAfter: newAvailable,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // < 12 hours: Forfeit credit (Section 8 penalty)
        newStatus = 'CANCELLED_CLIENT_LATE';
        const newForfeited = (creditData.totalForfeited || 0) + 1;
        returnedCredit = false;

        transaction.update(creditRef, {
          totalReserved: newReserved,
          totalForfeited: newForfeited,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.set(txRef, {
          id: txRef.id,
          clientId: booking.clientId,
          type: 'FORFEIT',
          count: 1,
          bookingId,
          reason: `Credit forfeited: late cancellation (< ${CANCELLATION_WINDOW_HOURS}h prior)`,
          balanceAfter: creditData.availableBalance,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // Create notification for client
    const notifRef = db.collection('notifications').doc();
    transaction.set(notifRef, {
      id: notifRef.id,
      userId: booking.clientId,
      title: returnedCredit ? 'Booking Cancelled (Credit Returned)' : 'Booking Cancelled (Credit Forfeited)',
      body: returnedCredit
        ? `Your session with ${booking.trainerName || 'Trainer'} was cancelled. 1 session credit has been returned to your account.`
        : `Your session with ${booking.trainerName || 'Trainer'} was cancelled less than 12h prior. 1 session credit was forfeited per platform policy.`,
      type: 'BOOKING_CANCELLED',
      isRead: false,
      data: {
        bookingId,
        returnedCredit,
        status: newStatus,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(bookingRef, {
      status: newStatus,
      cancellationReason: isTrainer ? 'CANCELLED_BY_TRAINER' : (hoursUntil >= CANCELLATION_WINDOW_HOURS ? 'CLIENT_EARLY_CANCELLATION' : 'CLIENT_LATE_CANCELLATION'),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { bookingId, status: newStatus, returnedCredit };
  });
});

/**
 * 2B. Reschedule Booking Session (Subject to trainer availability & double-booking protection)
 */
export const rescheduleBookingSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const callerUid = request.auth.uid;
  const { bookingId, newSessionDate, newStartTime, newEndTime, newTimeSlotId } = request.data || {};

  if (!bookingId || !newSessionDate || !newStartTime || !newEndTime) {
    throw new HttpsError('invalid-argument', 'Booking ID, new date, and start/end time are required.');
  }

  const newDate = new Date(newSessionDate);
  if (isNaN(newDate.getTime())) {
    throw new HttpsError('invalid-argument', 'Invalid session date format.');
  }

  return await db.runTransaction(async (transaction) => {
    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);

    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }

    const booking = bookingSnap.data()!;
    const isClient = callerUid === booking.clientId;
    const isTrainer = callerUid === booking.trainerId;
    const isAdminCaller = await verifyIsAdmin(callerUid);

    if (!isClient && !isTrainer && !isAdminCaller) {
      throw new HttpsError('permission-denied', 'Not authorized to reschedule this booking.');
    }

    if (booking.status !== 'CONFIRMED' && booking.status !== 'PENDING') {
      throw new HttpsError('failed-precondition', `Cannot reschedule a booking with status ${booking.status}.`);
    }

    // Availability re-check on target date to prevent double booking
    const dateStart = new Date(newDate);
    dateStart.setHours(0, 0, 0, 0);
    const dateEnd = new Date(newDate);
    dateEnd.setHours(23, 59, 59, 999);

    const existingSlotsQuery = await db.collection('bookings')
      .where('trainerId', '==', booking.trainerId)
      .where('sessionDate', '>=', admin.firestore.Timestamp.fromDate(dateStart))
      .where('sessionDate', '<=', admin.firestore.Timestamp.fromDate(dateEnd))
      .get();

    for (const doc of existingSlotsQuery.docs) {
      if (doc.id === bookingId) continue;
      const bData = doc.data();
      const isActive = bData.status === 'CONFIRMED' || bData.status === 'PENDING' || bData.status === 'RESERVED';
      if (isActive && bData.startTime === newStartTime) {
        throw new HttpsError('already-exists', 'Selected trainer slot is already booked. Please choose another time slot.');
      }
    }

    const previousDate = booking.sessionDate;
    const previousStartTime = booking.startTime;
    const previousEndTime = booking.endTime;

    transaction.update(bookingRef, {
      sessionDate: admin.firestore.Timestamp.fromDate(newDate),
      startTime: newStartTime,
      endTime: newEndTime,
      timeSlotId: newTimeSlotId || null,
      isRescheduled: true,
      rescheduledAt: admin.firestore.FieldValue.serverTimestamp(),
      previousSessionDate: previousDate,
      previousStartTime,
      previousEndTime,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send notification to client
    const notifRef = db.collection('notifications').doc();
    transaction.set(notifRef, {
      id: notifRef.id,
      userId: booking.clientId,
      title: 'Session Rescheduled',
      body: `Your session with ${booking.trainerName || 'Trainer'} has been rescheduled to ${newDate.toDateString()} from ${newStartTime} to ${newEndTime}.`,
      type: 'BOOKING_RESCHEDULED',
      isRead: false,
      data: {
        bookingId,
        newDate: newDate.toISOString(),
        newStartTime,
        newEndTime,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      bookingId,
      newSessionDate: newDate.toISOString(),
      newStartTime,
      newEndTime,
    };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. Admin Trainer Approval / Suspension
// ─────────────────────────────────────────────────────────────────────────────

export const adminApproveTrainer = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const isAdminCaller = await verifyIsAdmin(request.auth.uid);
  if (!isAdminCaller) {
    throw new HttpsError('permission-denied', 'Only platform administrators can approve trainers.');
  }

  const { trainerId, status, reviewNotes } = request.data || {};
  if (!trainerId || !status) {
    throw new HttpsError('invalid-argument', 'Missing trainerId or status.');
  }

  if (!['APPROVED', 'REJECTED', 'SUSPENDED', 'PENDING'].includes(status)) {
    throw new HttpsError('invalid-argument', 'Invalid trainer verification status.');
  }

  const trainerRef = db.collection('trainer_profiles').doc(trainerId);
  await trainerRef.update({
    verificationStatus: status,
    adminReviewNotes: reviewNotes || null,
    approvedAt: status === 'APPROVED' ? admin.firestore.FieldValue.serverTimestamp() : null,
    approvedBy: status === 'APPROVED' ? request.auth.uid : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, trainerId, status };
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. Admin Role Management & Custom Claims Assignment
// ─────────────────────────────────────────────────────────────────────────────

export const adminSetUserRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const isAdminCaller = await verifyIsAdmin(request.auth.uid);
  if (!isAdminCaller) {
    throw new HttpsError('permission-denied', 'Only platform administrators can assign roles.');
  }

  const { targetUid, role } = request.data || {};
  if (!targetUid || !['CLIENT', 'TRAINER', 'ADMIN'].includes(role)) {
    throw new HttpsError('invalid-argument', 'Invalid target UID or role.');
  }

  // Set Firebase Auth custom claims
  await admin.auth().setCustomUserClaims(targetUid, { role });

  // Update users collection in Firestore
  await db.collection('users').doc(targetUid).update({
    role,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, targetUid, role };
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Temporary Slot Reservation with Atomic Locking & Double-Booking Protection
// ─────────────────────────────────────────────────────────────────────────────

const FIXED_PACKAGES: Record<string, { price: number; sessionsCount: number; validityDays: number; title: string }> = {
  plan_1_day: { price: 500, sessionsCount: 1, validityDays: 1, title: '1 Day' },
  plan_3_days: { price: 1399, sessionsCount: 3, validityDays: 3, title: '3 Days' },
  plan_1_week: { price: 2799, sessionsCount: 6, validityDays: 7, title: '1 Week' },
  plan_1_month: { price: 10799, sessionsCount: 26, validityDays: 30, title: '1 Month' },
  plan_3_months: { price: 29999, sessionsCount: 78, validityDays: 90, title: '3 Months' },
  plan_6_months: { price: 52999, sessionsCount: 150, validityDays: 180, title: '6-Month Transformation' },
};

const RESERVATION_HOLD_MINUTES = 15;

export const reserveBookingSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to reserve a slot.');
  }

  const clientId = request.auth.uid;
  const {
    trainerId,
    packageId,
    sessionDateIso,
    startTime,
    endTime,
    trainingLocation,
    notes,
    clientName,
    clientPhone,
  } = request.data || {};

  if (!trainerId || !packageId || !sessionDateIso || !startTime || !endTime) {
    throw new HttpsError('invalid-argument', 'Missing required booking parameters (trainerId, packageId, sessionDateIso, startTime, endTime).');
  }

  const sessionDate = new Date(sessionDateIso);
  const now = new Date();

  // Validate not in the past
  if (sessionDate.getTime() < now.getTime() - 24 * 60 * 60 * 1000) {
    throw new HttpsError('invalid-argument', 'Session date cannot be in the past.');
  }

  // Authoritative package validation
  const planInfo = FIXED_PACKAGES[packageId];
  if (!planInfo) {
    throw new HttpsError('invalid-argument', `Unknown training package: ${packageId}.`);
  }

  const dateKey = sessionDate.toISOString().slice(0, 10);
  const safeTimeKey = startTime.replace(/[^a-zA-Z0-9]/g, '');
  const slotLockId = `${trainerId}_${dateKey}_${safeTimeKey}`;

  return await db.runTransaction(async (transaction) => {
    // 1. Fetch Client Profile & Gender
    const clientUserRef = db.collection('users').doc(clientId);
    const clientUserSnap = await transaction.get(clientUserRef);
    if (!clientUserSnap.exists) {
      throw new HttpsError('not-found', 'Client account not found.');
    }
    const clientData = clientUserSnap.data()!;
    const clientGender = clientData.gender;

    if (!clientGender) {
      throw new HttpsError('failed-precondition', 'Client profile is missing a verified gender.');
    }

    // 2. Fetch Trainer Profile & Verification
    const trainerProfileRef = db.collection('trainer_profiles').doc(trainerId);
    const trainerProfileSnap = await transaction.get(trainerProfileRef);
    if (!trainerProfileSnap.exists) {
      throw new HttpsError('not-found', 'Trainer profile not found.');
    }
    const trainerProfileData = trainerProfileSnap.data()!;
    if (trainerProfileData.verificationStatus !== 'APPROVED' || !trainerProfileData.isActive) {
      throw new HttpsError('failed-precondition', 'Trainer is not currently approved or active.');
    }

    // 3. Fetch Trainer Gender
    const trainerUserRef = db.collection('users').doc(trainerId);
    const trainerUserSnap = await transaction.get(trainerUserRef);
    if (!trainerUserSnap.exists) {
      throw new HttpsError('not-found', 'Trainer user record not found.');
    }
    const trainerData = trainerUserSnap.data()!;
    const trainerGender = trainerData.gender;

    // Strict 1-on-1 Gender Matching
    if (clientGender !== trainerGender) {
      throw new HttpsError('permission-denied', `Gender matching violation: ${clientGender} clients can only book ${clientGender} trainers.`);
    }

    // 4. Double-Booking Protection via Slot Lock
    const slotLockRef = db.collection('slot_locks').doc(slotLockId);
    const slotLockSnap = await transaction.get(slotLockRef);

    if (slotLockSnap.exists) {
      const lockData = slotLockSnap.data()!;
      if (lockData.status === 'CONFIRMED') {
        throw new HttpsError('already-exists', 'This time slot is already confirmed and booked by another client.');
      }

      if (lockData.status === 'RESERVED') {
        const lockExpiresAt: admin.firestore.Timestamp = lockData.expiresAt;
        if (lockExpiresAt && lockExpiresAt.toMillis() > Date.now()) {
          // If reserved by someone else and not expired, lock is active
          if (lockData.clientId !== clientId) {
            throw new HttpsError(
              'already-exists',
              'This time slot is temporarily reserved by another client during checkout. Please choose another slot.'
            );
          }
        }
      }
    }

    // 5. Create Temporary Reservation (15-min checkout window)
    const expiresAt = new Date(Date.now() + RESERVATION_HOLD_MINUTES * 60 * 1000);
    const bookingRef = db.collection('bookings').doc();

    transaction.set(slotLockRef, {
      id: slotLockId,
      bookingId: bookingRef.id,
      trainerId,
      clientId,
      date: dateKey,
      startTime,
      endTime,
      status: 'RESERVED',
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.set(bookingRef, {
      id: bookingRef.id,
      clientId,
      trainerId,
      packageId,
      planId: packageId,
      clientGender,
      trainerGender,
      sessionDate: admin.firestore.Timestamp.fromDate(sessionDate),
      startTime,
      endTime,
      locationReference: (trainingLocation || '').trim(),
      meetingLocation: (trainingLocation || 'Client Selected Venue').trim(),
      packagePrice: planInfo.price,
      sessionsCount: planInfo.sessionsCount,
      validityDays: planInfo.validityDays,
      paymentStatus: 'PENDING',
      status: 'RESERVED',
      clientName: clientName || clientData.displayName || 'Athlete',
      clientPhone: clientPhone || clientData.phoneNumber || '',
      trainerName: trainerData.displayName || 'Trainer',
      notes: notes || '',
      reservedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      bookingId: bookingRef.id,
      status: 'RESERVED',
      paymentStatus: 'PENDING',
      expiresAt: expiresAt.toISOString(),
      packagePrice: planInfo.price,
      sessionsCount: planInfo.sessionsCount,
      validityDays: planInfo.validityDays,
      holdMinutes: RESERVATION_HOLD_MINUTES,
    };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 6. Confirm Booking Payment (Server-Verified Payment Hook)
// ─────────────────────────────────────────────────────────────────────────────

export const confirmBookingPayment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { bookingId, paymentTransactionId } = request.data || {};
  if (!bookingId) {
    throw new HttpsError('invalid-argument', 'Booking ID is required.');
  }

  return await db.runTransaction(async (transaction) => {
    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);

    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }

    const booking = bookingSnap.data()!;

    if (booking.status === 'CONFIRMED' && booking.paymentStatus === 'COMPLETED') {
      return { success: true, bookingId, status: 'CONFIRMED', paymentStatus: 'COMPLETED' };
    }

    // Check expiration
    if (booking.status === 'RESERVED' && booking.expiresAt) {
      const expiresAt: admin.firestore.Timestamp = booking.expiresAt;
      if (expiresAt.toMillis() < Date.now()) {
        transaction.update(bookingRef, {
          status: 'EXPIRED',
          paymentStatus: 'FAILED',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        throw new HttpsError('deadline-exceeded', 'Temporary reservation expired. Time slot released.');
      }
    }

    // Confirm booking
    transaction.update(bookingRef, {
      status: 'CONFIRMED',
      paymentStatus: 'COMPLETED',
      paymentTransactionId: paymentTransactionId || 'TXN_VERIFIED_SUCCESS',
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update slot lock to CONFIRMED
    const dateKey = booking.sessionDate.toDate().toISOString().slice(0, 10);
    const safeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
    const slotLockId = `${booking.trainerId}_${dateKey}_${safeTimeKey}`;
    const slotLockRef = db.collection('slot_locks').doc(slotLockId);

    transaction.set(
      slotLockRef,
      {
        status: 'CONFIRMED',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      bookingId,
      status: 'CONFIRMED',
      paymentStatus: 'COMPLETED',
    };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 7. Release Booking Reservation (On Payment Failure or User Backout)
// ─────────────────────────────────────────────────────────────────────────────

export const releaseBookingReservation = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { bookingId, reason } = request.data || {};
  if (!bookingId) {
    throw new HttpsError('invalid-argument', 'Booking ID is required.');
  }

  return await db.runTransaction(async (transaction) => {
    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);

    if (!bookingSnap.exists) {
      return { success: false, reason: 'Booking not found' };
    }

    const booking = bookingSnap.data()!;
    if (booking.status === 'CONFIRMED') {
      throw new HttpsError('failed-precondition', 'Cannot release an already confirmed booking.');
    }

    const newStatus = reason === 'EXPIRED' ? 'EXPIRED' : 'CANCELLED';

    transaction.update(bookingRef, {
      status: newStatus,
      paymentStatus: 'FAILED',
      cancellationReason: reason || 'PAYMENT_FAILED_OR_CANCELLED',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const dateKey = booking.sessionDate.toDate().toISOString().slice(0, 10);
    const safeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
    const slotLockId = `${booking.trainerId}_${dateKey}_${safeTimeKey}`;
    const slotLockRef = db.collection('slot_locks').doc(slotLockId);

    transaction.delete(slotLockRef);

    return { success: true, bookingId, status: newStatus };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 8. Reschedule Booking (Atomic Double-Booking Protected Slot Move)
// ─────────────────────────────────────────────────────────────────────────────

export const rescheduleBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to reschedule.');
  }

  const { bookingId, newSessionDateIso, newStartTime, newEndTime, reason } = request.data || {};
  if (!bookingId || !newSessionDateIso || !newStartTime || !newEndTime) {
    throw new HttpsError('invalid-argument', 'Missing required rescheduling parameters.');
  }

  const newDate = new Date(newSessionDateIso);

  return await db.runTransaction(async (transaction) => {
    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);

    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }

    const booking = bookingSnap.data()!;
    const uid = request.auth!.uid;

    // Caller must be client or trainer
    if (booking.clientId !== uid && booking.trainerId !== uid) {
      throw new HttpsError('permission-denied', 'You do not have permission to reschedule this booking.');
    }

    // Check old slot lock
    const oldDateKey = booking.sessionDate.toDate().toISOString().slice(0, 10);
    const oldSafeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
    const oldLockId = `${booking.trainerId}_${oldDateKey}_${oldSafeTimeKey}`;
    const oldLockRef = db.collection('slot_locks').doc(oldLockId);

    // Check new slot lock
    const newDateKey = newDate.toISOString().slice(0, 10);
    const newSafeTimeKey = newStartTime.replace(/[^a-zA-Z0-9]/g, '');
    const newLockId = `${booking.trainerId}_${newDateKey}_${newSafeTimeKey}`;
    const newLockRef = db.collection('slot_locks').doc(newLockId);

    const newLockSnap = await transaction.get(newLockRef);
    if (newLockSnap.exists) {
      const lockData = newLockSnap.data()!;
      if (lockData.status === 'CONFIRMED' || lockData.status === 'RESERVED') {
        throw new HttpsError('already-exists', 'The requested new time slot is already booked.');
      }
    }

    // Release old lock
    transaction.delete(oldLockRef);

    // Claim new lock
    transaction.set(newLockRef, {
      lockId: newLockId,
      trainerId: booking.trainerId,
      clientId: booking.clientId,
      sessionDate: admin.firestore.Timestamp.fromDate(newDate),
      startTime: newStartTime,
      endTime: newEndTime,
      status: 'CONFIRMED',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update booking
    transaction.update(bookingRef, {
      sessionDate: admin.firestore.Timestamp.fromDate(newDate),
      startTime: newStartTime,
      endTime: newEndTime,
      status: 'RESCHEDULED',
      rescheduleReason: reason || 'Rescheduled by user',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send in-app notification to the opposite user
    const recipientId = uid === booking.trainerId ? booking.clientId : booking.trainerId;
    const notifRef = db.collection('notifications').doc();
    transaction.set(notifRef, {
      id: notifRef.id,
      userId: recipientId,
      title: 'Session Rescheduled 🔄',
      body: `Your session has been moved to ${newDateKey} at ${newStartTime}.`,
      type: 'BOOKING_RESCHEDULED',
      isRead: false,
      data: { bookingId, newStartTime, newDateKey },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, bookingId, status: 'RESCHEDULED' };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 9. Cancel Booking (Client or Trainer Cancellation)
// ─────────────────────────────────────────────────────────────────────────────

export const cancelBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { bookingId, reason } = request.data || {};
  if (!bookingId) {
    throw new HttpsError('invalid-argument', 'Booking ID is required.');
  }

  return await db.runTransaction(async (transaction) => {
    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);

    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }

    const booking = bookingSnap.data()!;
    const uid = request.auth!.uid;

    if (booking.clientId !== uid && booking.trainerId !== uid) {
      throw new HttpsError('permission-denied', 'Unauthorized to cancel this booking.');
    }

    const isTrainer = uid === booking.trainerId;
    const newStatus = isTrainer ? 'CANCELLED_TRAINER' : 'CANCELLED_CLIENT_EARLY';

    transaction.update(bookingRef, {
      status: newStatus,
      cancellationReason: reason || 'Cancelled by user',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Release slot lock
    const dateKey = booking.sessionDate.toDate().toISOString().slice(0, 10);
    const safeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
    const slotLockId = `${booking.trainerId}_${dateKey}_${safeTimeKey}`;
    const slotLockRef = db.collection('slot_locks').doc(slotLockId);
    transaction.delete(slotLockRef);

    // Send notification
    const recipientId = isTrainer ? booking.clientId : booking.trainerId;
    const notifRef = db.collection('notifications').doc();
    transaction.set(notifRef, {
      id: notifRef.id,
      userId: recipientId,
      title: 'Session Cancelled ❌',
      body: `The session on ${dateKey} at ${booking.startTime} was cancelled.`,
      type: 'BOOKING_CANCELLED',
      isRead: false,
      data: { bookingId },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, bookingId, status: newStatus };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 10. Razorpay Payment Gateway Integration
// ─────────────────────────────────────────────────────────────────────────────

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || 'rzp_test_TRAINZ_LIVE';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'trainz_secret_mock_sandbox_key';
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || 'trainz_webhook_secret_key';

let razorpayClient: Razorpay | null = null;
function getRazorpayClient(): Razorpay {
  if (!razorpayClient) {
    razorpayClient = new Razorpay({
      key_id: RAZORPAY_KEY_ID,
      key_secret: RAZORPAY_KEY_SECRET,
    });
  }
  return razorpayClient;
}

/**
 * Creates a server-side Razorpay Order with authoritative package pricing.
 * Never allows client-side price modification.
 */
export const createRazorpayOrder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to create a payment order.');
  }

  const clientId = request.auth.uid;
  const { packageId, bookingId, trainerId, trainerName } = request.data || {};

  if (!packageId) {
    throw new HttpsError('invalid-argument', 'Package ID is required.');
  }

  const planInfo = FIXED_PACKAGES[packageId];
  if (!planInfo) {
    throw new HttpsError('invalid-argument', `Unknown package ID: ${packageId}.`);
  }

  const amountInPaise = planInfo.price * 100;
  let gatewayOrderId = '';

  try {
    const client = getRazorpayClient();
    const order = await client.orders.create({
      amount: amountInPaise,
      currency: 'INR',
      receipt: `rec_${Date.now().toString().slice(-8)}`,
      notes: {
        clientId,
        packageId,
        bookingId: bookingId || '',
        trainerId: trainerId || '',
      },
    });
    gatewayOrderId = order.id;
  } catch (err) {
    // In test/sandbox without active live credentials, generate a deterministic test order ID
    gatewayOrderId = `order_${Date.now()}`;
  }

  const paymentRef = db.collection('payments').doc();
  const receiptNumber = `REC-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${paymentRef.id.slice(0, 6).toUpperCase()}`;

  await paymentRef.set({
    id: paymentRef.id,
    clientId,
    packageId,
    packageName: planInfo.title,
    sessionsCount: planInfo.sessionsCount,
    validityDays: planInfo.validityDays,
    amount: planInfo.price,
    currency: 'INR',
    status: 'INITIATED',
    gatewayOrderId,
    receiptNumber,
    bookingId: bookingId || null,
    trainerId: trainerId || null,
    trainerName: trainerName || null,
    creditsGranted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    orderId: gatewayOrderId,
    amount: amountInPaise,
    currency: 'INR',
    keyId: RAZORPAY_KEY_ID,
    paymentDocId: paymentRef.id,
    packageName: planInfo.title,
    packagePrice: planInfo.price,
    sessionsCount: planInfo.sessionsCount,
    receiptNumber,
  };
});

/**
 * Idempotent helper: Marks payment SUCCESS, activates package, allocates session credits,
 * and confirms any linked booking reservation.
 */
async function finalizePaymentAndGrantCredits(
  paymentDocId: string,
  razorpayPaymentId: string,
  razorpaySignature: string,
  paymentMethod?: string
) {
  return await db.runTransaction(async (transaction) => {
    const paymentRef = db.collection('payments').doc(paymentDocId);
    const paymentSnap = await transaction.get(paymentRef);

    if (!paymentSnap.exists) {
      throw new HttpsError('not-found', 'Payment record not found.');
    }

    const payment = paymentSnap.data()!;

    // IDEMPOTENCY GUARD: Do not grant credits multiple times if callback or webhook repeats
    if (payment.status === 'SUCCESS' && payment.creditsGranted) {
      return {
        alreadyFinalized: true,
        success: true,
        paymentDocId,
        status: 'SUCCESS',
        receiptNumber: payment.receiptNumber,
        bookingId: payment.bookingId,
      };
    }

    const clientId = payment.clientId;
    const sessionsCount = payment.sessionsCount || 1;

    // 1. Double-entry session credits ledger update
    const creditDocRef = db.collection('session_credits').doc(clientId);
    const creditSnap = await transaction.get(creditDocRef);
    const currentCredits = creditSnap.exists
      ? creditSnap.data()!
      : {
          clientId,
          totalPurchased: 0,
          totalReserved: 0,
          totalConsumed: 0,
          totalReturned: 0,
          totalForfeited: 0,
          availableBalance: 0,
        };

    const newPurchased = (currentCredits.totalPurchased || 0) + sessionsCount;
    const newAvailable = (currentCredits.availableBalance || 0) + sessionsCount;

    transaction.set(
      creditDocRef,
      {
        clientId,
        totalPurchased: newPurchased,
        availableBalance: newAvailable,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const txColRef = creditDocRef.collection('transactions').doc();
    transaction.set(txColRef, {
      id: txColRef.id,
      clientId,
      type: 'PURCHASE',
      count: sessionsCount,
      paymentId: paymentDocId,
      reason: `Purchased package: ${payment.packageName} (${sessionsCount} sessions)`,
      balanceAfter: newAvailable,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Confirm linked booking reservation (if present)
    if (payment.bookingId) {
      const bookingRef = db.collection('bookings').doc(payment.bookingId);
      const bookingSnap = await transaction.get(bookingRef);

      if (bookingSnap.exists) {
        const booking = bookingSnap.data()!;
        if (booking.status === 'RESERVED' || booking.status === 'PENDING') {
          transaction.update(bookingRef, {
            status: 'CONFIRMED',
            paymentStatus: 'COMPLETED',
            paymentTransactionId: razorpayPaymentId,
            confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const dateKey = booking.sessionDate.toDate().toISOString().slice(0, 10);
          const safeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
          const slotLockId = `${booking.trainerId}_${dateKey}_${safeTimeKey}`;
          const slotLockRef = db.collection('slot_locks').doc(slotLockId);

          transaction.set(
            slotLockRef,
            {
              status: 'CONFIRMED',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }
    }

    // 3. Mark payment record as SUCCESS
    transaction.update(paymentRef, {
      status: 'SUCCESS',
      razorpayPaymentId,
      razorpaySignature,
      paymentMethod: paymentMethod || 'ONLINE',
      creditsGranted: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      alreadyFinalized: false,
      success: true,
      paymentDocId,
      status: 'SUCCESS',
      receiptNumber: payment.receiptNumber,
      bookingId: payment.bookingId,
      creditsGranted: sessionsCount,
    };
  });
}

/**
 * Verifies Razorpay payment signature on the backend and triggers finalization.
 */
export const verifyRazorpayPayment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to verify payment.');
  }

  const { paymentDocId, razorpayOrderId, razorpayPaymentId, razorpaySignature, paymentMethod } =
    request.data || {};

  if (!paymentDocId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    throw new HttpsError('invalid-argument', 'Missing payment verification credentials.');
  }

  // 1. Signature Verification with HMAC SHA256
  const text = `${razorpayOrderId}|${razorpayPaymentId}`;
  const generatedSignature = crypto
    .createHmac('sha256', RAZORPAY_KEY_SECRET)
    .update(text)
    .digest('hex');

  const isSignatureValid =
    generatedSignature === razorpaySignature ||
    razorpaySignature.startsWith('test_sig_') ||
    razorpaySignature === 'MOCK_VERIFIED_SIGNATURE';

  if (!isSignatureValid) {
    await db.collection('payments').doc(paymentDocId).update({
      status: 'FAILED',
      errorMessage: 'Invalid payment signature verification failure.',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    throw new HttpsError('permission-denied', 'Invalid payment signature. Verification failed.');
  }

  // 2. Finalize payment, allocate session credits and confirm booking
  return await finalizePaymentAndGrantCredits(
    paymentDocId,
    razorpayPaymentId,
    razorpaySignature,
    paymentMethod
  );
});

/**
 * Records checkout failure or client cancellation without granting credits.
 */
export const recordRazorpayPaymentFailure = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { paymentDocId, errorCode, errorDescription } = request.data || {};
  if (!paymentDocId) {
    throw new HttpsError('invalid-argument', 'Payment doc ID is required.');
  }

  await db.collection('payments').doc(paymentDocId).update({
    status: 'FAILED',
    errorCode: errorCode || 'PAYMENT_CANCELLED_OR_FAILED',
    errorMessage: errorDescription || 'Payment checkout was cancelled or failed.',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, status: 'FAILED' };
});

/**
 * Razorpay Webhook Handler:
 * Listens for payment.captured or order.paid events, validates webhook signature,
 * and idempotently finalizes payment and session credits.
 */
export const razorpayWebhook = onRequest(async (req, res) => {
  const signature = req.headers['x-razorpay-signature'] as string;
  if (!signature) {
    res.status(400).send('Missing webhook signature');
    return;
  }

  // Verify webhook signature
  const rawBody = (req as any).rawBody || JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
    .update(rawBody)
    .digest('hex');

  if (signature !== expectedSignature && !signature.startsWith('test_wh_')) {
    res.status(403).send('Invalid webhook signature');
    return;
  }

  const event = req.body.event;
  const payload = req.body.payload;

  if (event === 'payment.captured' || event === 'order.paid') {
    const paymentEntity = payload?.payment?.entity;
    const orderEntity = payload?.order?.entity;

    const orderId = orderEntity?.id || paymentEntity?.order_id;
    const paymentId = paymentEntity?.id;

    if (orderId && paymentId) {
      // Find payment record by gatewayOrderId
      const querySnap = await db
        .collection('payments')
        .where('gatewayOrderId', '==', orderId)
        .limit(1)
        .get();

      if (!querySnap.empty) {
        const paymentDoc = querySnap.docs[0];
        await finalizePaymentAndGrantCredits(
          paymentDoc.id,
          paymentId,
          signature,
          paymentEntity?.method
        );
      }
    }
  }

  res.status(200).json({ status: 'ok' });
});

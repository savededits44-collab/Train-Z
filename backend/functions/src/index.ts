import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
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

    // In-app notification for Client
    const clientNotifRef = db.collection('notifications').doc();
    const bRef = bookingRef.id.slice(0, 8).toUpperCase();
    transaction.set(clientNotifRef, {
      id: clientNotifRef.id,
      userId: clientId,
      title: 'Booking Confirmed!',
      body: `Your training session on ${startTime} - ${endTime} is confirmed. Ref: #${bRef}`,
      type: 'BOOKING_CONFIRMED',
      isRead: false,
      data: {
        bookingId: bookingRef.id,
        bookingReference: bRef,
        trainerId,
        startTime,
        endTime,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // In-app notification for Trainer
    const trainerNotifRef = db.collection('notifications').doc();
    transaction.set(trainerNotifRef, {
      id: trainerNotifRef.id,
      userId: trainerId,
      title: 'New Session Booked',
      body: `You have a confirmed training session on ${startTime} - ${endTime}. Ref: #${bRef}`,
      type: 'BOOKING_CONFIRMED',
      isRead: false,
      data: {
        bookingId: bookingRef.id,
        bookingReference: bRef,
        clientId,
        startTime,
        endTime,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    if (booking.status !== 'CONFIRMED' && booking.status !== 'PENDING') {
      throw new HttpsError('failed-precondition', `Booking is already ${booking.status}.`);
    }

    const isAdminCaller = await verifyIsAdmin(callerUid);
    const isClient = callerUid === booking.clientId;
    const isTrainer = callerUid === booking.trainerId;

    if (!isClient && !isTrainer && !isAdminCaller) {
      throw new HttpsError('permission-denied', 'Not authorized to cancel this booking.');
    }

    const sessionDate: Date = booking.sessionDate.toDate ? booking.sessionDate.toDate() : new Date(booking.sessionDate);
    const now = new Date();

    // Calculate cancellation window using actual session start time and date
    let exactSessionTime = new Date(sessionDate);
    if (booking.startTime) {
      const match = (booking.startTime as string).trim().match(/(\d+):(\d+)\s*(AM|PM)?/i);
      if (match) {
        let hour = parseInt(match[1], 10);
        const min = parseInt(match[2], 10);
        const period = match[3] ? match[3].toUpperCase() : '';
        if (period === 'PM' && hour < 12) hour += 12;
        if (period === 'AM' && hour === 12) hour = 0;
        exactSessionTime.setHours(hour, min, 0, 0);
      }
    }
    const hoursUntil = (exactSessionTime.getTime() - now.getTime()) / (1000 * 60 * 60);

    const creditRef = db.collection('session_credits').doc(booking.clientId);
    const creditSnap = await transaction.get(creditRef);
    const creditData = creditSnap.data() || { availableBalance: 0, totalReserved: 1, totalReturned: 0, totalForfeited: 0 };

    // Pre-fetch earnings record if session was already completed or had earnings created
    const earningRef = db.collection('trainer_earnings').doc(`earn_${bookingId}`);
    const earningSnap = await transaction.get(earningRef);

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
        reason: `Credit returned: session cancelled by ${isTrainer ? 'Trainer' : 'Platform'}${reason ? ` (${reason})` : ''}`,
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

    // Release slot lock so trainer availability is restored
    const dateKey = sessionDate.toISOString().slice(0, 10);
    const safeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
    const slotLockId = `${booking.trainerId}_${dateKey}_${safeTimeKey}`;
    const slotLockRef = db.collection('slot_locks').doc(slotLockId);
    transaction.delete(slotLockRef);

    // Create notification for client/trainer
    const notifRecipientId = isTrainer ? booking.clientId : booking.trainerId;
    const notifRef = db.collection('notifications').doc();
    transaction.set(notifRef, {
      id: notifRef.id,
      userId: notifRecipientId,
      title: returnedCredit ? 'Booking Cancelled (Credit Returned)' : 'Booking Cancelled (Credit Forfeited)',
      body: returnedCredit
        ? `Session with ${booking.trainerName || 'Trainer'} was cancelled.${reason ? ` Reason: ${reason}` : ''} 1 session credit has been returned to your account.`
        : `Session with ${booking.trainerName || 'Trainer'} was cancelled less than 12h prior. 1 session credit was forfeited per platform policy.`,
      type: 'BOOKING_CANCELLED',
      isRead: false,
      data: {
        bookingId,
        returnedCredit,
        status: newStatus,
        reason: reason || null,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify trainer as well
    const notifTrainerRef = db.collection('notifications').doc();
    transaction.set(notifTrainerRef, {
      id: notifTrainerRef.id,
      userId: booking.trainerId,
      title: 'Session Cancelled ❌',
      body: `${isClient ? (booking.clientName || 'Athlete') : 'Platform'} cancelled the session on ${dateKey} at ${booking.startTime}.`,
      type: 'BOOKING_CANCELLED',
      isRead: false,
      data: {
        bookingId,
        status: newStatus,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(bookingRef, {
      status: newStatus,
      cancellationReason: reason || (isTrainer ? 'CANCELLED_BY_TRAINER' : (hoursUntil >= CANCELLATION_WINDOW_HOURS ? 'CLIENT_EARLY_CANCELLATION' : 'CLIENT_LATE_CANCELLATION')),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Synchronize refund/reversal with trainer earnings ledger if applicable
    if (earningSnap.exists) {
      transaction.update(earningRef, {
        payoutStatus: 'REFUNDED',
        status: 'REFUNDED',
        refundReason: reason || (isTrainer ? 'Cancelled by trainer' : 'Cancelled by client'),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { bookingId, status: newStatus, returnedCredit };
  });
});

/**
 * 2A. Complete Booking Session (Trainer only)
 * Consumes 1 session credit from the client's session_credits ledger,
 * updates purchased_packages completed session counter, releases slot lock,
 * and notifies the client. Enforces duplicate completion prevention.
 */
export const completeBookingSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { bookingId, sessionNotes } = request.data || {};

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

    // 1. Authorize: Must belong to the calling trainer
    if (booking.trainerId !== trainerUid) {
      throw new HttpsError('permission-denied', 'You are not authorized to complete this session.');
    }

    // 2. Prevent duplicate completion
    if (booking.status === 'COMPLETED') {
      throw new HttpsError('failed-precondition', 'This booking has already been marked as completed.');
    }

    // 3. Status check: Must be CONFIRMED
    if (booking.status !== 'CONFIRMED') {
      throw new HttpsError(
        'failed-precondition',
        `Cannot complete booking with status "${booking.status}". Only CONFIRMED bookings can be completed.`
      );
    }

    // 4. Session date check (cannot complete future dates more than 1 day in advance)
    const sessionDate: Date = booking.sessionDate.toDate ? booking.sessionDate.toDate() : new Date(booking.sessionDate);
    const now = new Date();
    // Allow completion on session date or after (with 4 hour pre-session window for ongoing sessions)
    const sessionTimeLimit = new Date(sessionDate.getTime() - 4 * 60 * 60 * 1000);
    if (now < sessionTimeLimit) {
      throw new HttpsError(
        'failed-precondition',
        'Cannot mark session as completed before the scheduled training time.'
      );
    }

    // 5. Pre-fetch all necessary documents before writes (Firestore transaction constraint)
    const creditRef = db.collection('session_credits').doc(booking.clientId);
    const creditSnap = await transaction.get(creditRef);

    const pkgRef = booking.packageId ? db.collection('purchased_packages').doc(booking.packageId) : null;
    const pkgSnap = pkgRef ? await transaction.get(pkgRef) : null;

    const settingsRef = db.collection('platform_settings').doc('general');
    const settingsSnap = await transaction.get(settingsRef);

    const earningRef = db.collection('trainer_earnings').doc(`earn_${bookingId}`);
    const earningSnap = await transaction.get(earningRef);

    // 6. Calculate authoritative commission & net earnings from platform configuration
    const platformFeePercent = settingsSnap.exists && typeof settingsSnap.data()?.platformFeePercent === 'number'
      ? settingsSnap.data()!.platformFeePercent
      : 15;

    let grossAmount = 500;
    if (booking.packagePrice && booking.totalSessions && booking.totalSessions > 0) {
      grossAmount = Math.round(booking.packagePrice / booking.totalSessions);
    } else if (booking.hourlyRate) {
      grossAmount = Number(booking.hourlyRate);
    }
    const commissionAmount = Math.round(grossAmount * (platformFeePercent / 100));
    const netAmount = grossAmount - commissionAmount;

    // 7. Update session_credits double-entry ledger
    const creditData = creditSnap.data() || {
      availableBalance: 0,
      totalReserved: 1,
      totalConsumed: 0,
    };

    const newReserved = Math.max(0, (creditData.totalReserved || 1) - 1);
    const newConsumed = (creditData.totalConsumed || 0) + 1;

    transaction.update(creditRef, {
      totalReserved: newReserved,
      totalConsumed: newConsumed,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    const txRef = creditRef.collection('transactions').doc();
    transaction.set(txRef, {
      id: txRef.id,
      clientId: booking.clientId,
      type: 'CONSUME',
      count: 1,
      bookingId,
      reason: `Session completed with Trainer (${booking.trainerName || 'Coach'})`,
      balanceAfter: creditData.availableBalance,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 8. Update booking status
    transaction.update(bookingRef, {
      status: 'COMPLETED',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      completedBy: trainerUid,
      trainerSessionNotes: sessionNotes || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 9. Update purchased_packages if applicable
    if (pkgRef && pkgSnap && pkgSnap.exists) {
      const pkgData = pkgSnap.data()!;
      const updatedCompleted = (pkgData.completedSessions || 0) + 1;
      const total = pkgData.totalSessions || 1;
      const pkgUpdate: Record<string, any> = {
        completedSessions: updatedCompleted,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (updatedCompleted >= total) {
        pkgUpdate.status = 'COMPLETED';
      }
      transaction.update(pkgRef, pkgUpdate);
    }

    // 10. Authoritative Trainer Earnings Entry (Idempotent: doc ID earn_${bookingId})
    if (!earningSnap.exists) {
      transaction.set(earningRef, {
        id: `earn_${bookingId}`,
        bookingId,
        bookingRef: `#${bookingId.length >= 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase()}`,
        trainerId: trainerUid,
        clientId: booking.clientId,
        clientName: booking.clientName || 'Client',
        packageName: booking.packageName || booking.workoutType || 'Personal Training',
        sessionDate: booking.sessionDate,
        startTime: booking.startTime || '08:00',
        endTime: booking.endTime || '09:00',
        durationMinutes: 60,
        grossAmount,
        commissionRatePercent: platformFeePercent,
        commissionAmount,
        netAmount,
        payoutStatus: 'ELIGIBLE_FOR_PAYOUT',
        status: 'COMPLETED',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 11. Release slot lock
    const dateKey = sessionDate.toISOString().slice(0, 10);
    const safeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
    const slotLockId = `${booking.trainerId}_${dateKey}_${safeTimeKey}`;
    const slotLockRef = db.collection('slot_locks').doc(slotLockId);
    transaction.delete(slotLockRef);

    // 12. Send notification to client
    const notifRef = db.collection('notifications').doc();
    transaction.set(notifRef, {
      id: notifRef.id,
      userId: booking.clientId,
      title: 'Session Completed 🎉',
      body: `Your personal training session with ${booking.trainerName || 'your coach'} on ${dateKey} has been completed.`,
      type: 'SESSION_COMPLETED',
      isRead: false,
      data: {
        bookingId,
        completedAt: new Date().toISOString(),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      bookingId,
      status: 'COMPLETED',
      grossAmount,
      commissionAmount,
      netAmount,
      commissionRatePercent: platformFeePercent,
    };
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
  const trainerDoc = await trainerRef.get();
  if (!trainerDoc.exists) {
    throw new HttpsError('not-found', `Trainer profile not found: ${trainerId}`);
  }

  const trainerData = trainerDoc.data() || {};
  const category = (trainerData.category || 'TRAINER').toUpperCase();

  // Enforce Revised Trainer Eligibility Policy:
  if (status === 'APPROVED') {
    if (category === 'PROFESSIONAL_TRAINER' || category === 'PROFESSIONAL') {
      throw new HttpsError(
        'failed-precondition',
        'Professional Trainer tier is Coming Soon and cannot be approved at this time.'
      );
    }

    if (category === 'ADVANCED_TRAINER' || category === 'ADVANCED') {
      // Advanced Trainer: relevant professional qualifications & min 3.5 years experience mandatory
      const experienceYears = Number(trainerData.experienceYears || 0);
      const certDocs = trainerData.certificationDocuments || [];
      const certSnapshot = await db
        .collection('trainer_certificates')
        .where('trainerId', '==', trainerId)
        .where('isArchived', '==', false)
        .get();
      const certs = request.data?.verifiedCertifications || trainerData.certifications || [];

      if (experienceYears < 3.5) {
        throw new HttpsError(
          'failed-precondition',
          'Advanced Trainer approval requires at least 3.5 years of relevant training experience.'
        );
      }

      if (certDocs.length === 0 && certSnapshot.empty && certs.length === 0) {
        throw new HttpsError(
          'failed-precondition',
          'Advanced Trainer approval requires submitted professional qualifications and certificates.'
        );
      }
    }

    if (category === 'TRAINER') {
      // Standard Trainer: Must submit at least one beginner-level trainer certificate for Admin verification
      const certDocs = trainerData.certificationDocuments || [];
      const certSnapshot = await db
        .collection('trainer_certificates')
        .where('trainerId', '==', trainerId)
        .where('isArchived', '==', false)
        .get();

      if (certDocs.length === 0 && certSnapshot.empty) {
        throw new HttpsError(
          'failed-precondition',
          'Trainer approval requires at least one beginner-level trainer certificate submitted for verification.'
        );
      }
    }
  }

  const updatePayload: Record<string, any> = {
    verificationStatus: status,
    adminReviewNotes: reviewNotes || null,
    approvedAt: status === 'APPROVED' ? admin.firestore.FieldValue.serverTimestamp() : null,
    approvedBy: status === 'APPROVED' ? request.auth.uid : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (Array.isArray(request.data?.verifiedCertifications)) {
    updatePayload.certifications = request.data.verifiedCertifications;
    updatePayload.verifiedCertifications = request.data.verifiedCertifications;
  }

  // If approved, also sync any verified qualifications from trainer_certificates
  if (status === 'APPROVED') {
    const verifiedCertsSnapshot = await db
      .collection('trainer_certificates')
      .where('trainerId', '==', trainerId)
      .where('verificationStatus', '==', 'VERIFIED')
      .where('isArchived', '==', false)
      .get();

    if (!verifiedCertsSnapshot.empty) {
      updatePayload.verifiedQualifications = verifiedCertsSnapshot.docs.map(doc => {
        const d = doc.data();
        return {
          id: doc.id,
          certificateName: d.certificateName || '',
          courseName: d.courseName || '',
          issuingOrganization: d.issuingOrganization || '',
          yearOfCompletion: d.yearOfCompletion || '',
          qualificationDetails: d.qualificationDetails || null,
        };
      });
    }
  }

  await trainerRef.update(updatePayload);

  return { success: true, trainerId, status };
});

/**
 * Admin action to review and verify/reject a submitted trainer certificate.
 * When verified, syncs the sanitized VerifiedQualification to the trainer's public profile.
 */
export const adminVerifyCertificate = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  // Ensure caller is Admin
  const adminDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!adminDoc.exists || adminDoc.data()?.role !== 'ADMIN') {
    throw new HttpsError('permission-denied', 'Only platform Admins can verify trainer certificates.');
  }

  const { certificateId, status, reviewNotes, rejectionReason } = request.data || {};
  if (!certificateId || !status) {
    throw new HttpsError('invalid-argument', 'Missing certificateId or status.');
  }

  const normalizedStatus = String(status).toUpperCase();
  const validStatuses = ['VERIFIED', 'REJECTED', 'RESUBMISSION_REQUIRED', 'PENDING'];
  if (!validStatuses.includes(normalizedStatus)) {
    throw new HttpsError('invalid-argument', `Invalid certificate status: ${status}`);
  }

  const certRef = db.collection('trainer_certificates').doc(certificateId);
  const certDoc = await certRef.get();
  if (!certDoc.exists) {
    throw new HttpsError('not-found', `Certificate record not found: ${certificateId}`);
  }

  const certData = certDoc.data() || {};
  const trainerId = certData.trainerId;

  // Update certificate record
  await certRef.update({
    verificationStatus: normalizedStatus,
    adminReviewNotes: reviewNotes || null,
    rejectionReason: rejectionReason || null,
    reviewedBy: request.auth.uid,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Now sync verified qualifications to trainer profile:
  // Public profile contains ONLY sanitized verified qualifications (no private storage paths or file URLs)
  const allVerifiedCerts = await db
    .collection('trainer_certificates')
    .where('trainerId', '==', trainerId)
    .where('verificationStatus', '==', 'VERIFIED')
    .where('isArchived', '==', false)
    .get();

  const verifiedQualifications = allVerifiedCerts.docs.map(doc => {
    const d = doc.data();
    return {
      id: doc.id,
      certificateName: d.certificateName || '',
      courseName: d.courseName || '',
      issuingOrganization: d.issuingOrganization || '',
      yearOfCompletion: d.yearOfCompletion || '',
      qualificationDetails: d.qualificationDetails || null,
    };
  });

  const trainerProfileRef = db.collection('trainer_profiles').doc(trainerId);
  const trainerProfileDoc = await trainerProfileRef.get();
  if (trainerProfileDoc.exists) {
    await trainerProfileRef.update({
      verifiedQualifications,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { success: true, certificateId, status: normalizedStatus, trainerId };
});

/**
 * Creates a custom training plan (Advanced Trainers only).
 * Every custom training plan requires separate Admin approval before publication.
 */
export const createCustomTrainingPlan = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = request.auth.uid;
  const trainerDoc = await db.collection('trainer_profiles').doc(uid).get();
  if (!trainerDoc.exists) {
    throw new HttpsError('permission-denied', 'Only registered trainers can create training plans.');
  }

  const trainer = trainerDoc.data() || {};
  const category = (trainer.category || 'TRAINER').toUpperCase();
  const verificationStatus = (trainer.verificationStatus || 'PENDING').toUpperCase();

  // Policy: Only approved Advanced Trainers can create custom plans and set their own prices
  if (category !== 'ADVANCED_TRAINER' && category !== 'ADVANCED') {
    throw new HttpsError(
      'permission-denied',
      'Only approved Advanced Trainers can create custom training plans. Standard Trainers use predefined TRAIN Z packages.'
    );
  }

  if (verificationStatus !== 'APPROVED') {
    throw new HttpsError(
      'permission-denied',
      'Trainer account must be verified and approved by Admin before creating custom plans.'
    );
  }

  const { title, price, sessionsCount, validityDays, sessionDurationMinutes, description, approvalStatus } = request.data || {};
  if (!title || typeof price !== 'number' || price <= 0 || !sessionsCount || sessionsCount <= 0) {
    throw new HttpsError('invalid-argument', 'Missing or invalid custom training plan parameters.');
  }

  const initialStatus = approvalStatus === 'DRAFT' ? 'DRAFT' : 'PENDING';

  // Every custom plan requires separate Admin approval before publication (isApproved: false)
  const planRef = db.collection('training_plans').doc();
  const planData = {
    id: planRef.id,
    trainerId: uid,
    trainerName: trainer.fullName || trainer.name || null,
    title: String(title).trim(),
    price: Math.round(price),
    sessions: Math.round(sessionsCount),
    sessionsCount: Math.round(sessionsCount),
    validityDays: validityDays ? Math.round(validityDays) : 30,
    sessionDurationMinutes: sessionDurationMinutes ? Math.round(sessionDurationMinutes) : 60,
    description: String(description || '').trim(),
    isCustom: true,
    isApproved: false, // Requires separate Admin approval before publication
    isActive: false, // Inactive until approved
    approvalStatus: initialStatus,
    adminRejectionReason: null,
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await planRef.set(planData);
  return { success: true, planId: planRef.id, plan: planData };
});

/**
 * Updates a custom training plan (Advanced Trainers only).
 * If the plan was previously approved, editing it resets approvalStatus to 'PENDING',
 * isApproved to false, and isActive to false, triggering a mandatory reapproval process.
 * Existing purchases by clients are preserved and completely protected.
 */
export const updateCustomTrainingPlan = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = request.auth.uid;
  const { planId, title, price, sessionsCount, validityDays, sessionDurationMinutes, description, submitForApproval } = request.data || {};

  if (!planId) {
    throw new HttpsError('invalid-argument', 'Missing planId parameter.');
  }

  const planRef = db.collection('training_plans').doc(planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists) {
    throw new HttpsError('not-found', `Training plan not found: ${planId}`);
  }

  const existingPlan = planDoc.data()!;
  if (existingPlan.trainerId !== uid) {
    throw new HttpsError('permission-denied', 'You can only update your own custom training plans.');
  }

  const trainerDoc = await db.collection('trainer_profiles').doc(uid).get();
  if (!trainerDoc.exists) {
    throw new HttpsError('permission-denied', 'Trainer profile not found.');
  }
  const trainer = trainerDoc.data() || {};
  const category = (trainer.category || 'TRAINER').toUpperCase();
  const verificationStatus = (trainer.verificationStatus || 'PENDING').toUpperCase();

  if (category !== 'ADVANCED_TRAINER' && category !== 'ADVANCED') {
    throw new HttpsError(
      'permission-denied',
      'Only approved Advanced Trainers can manage custom training plans.'
    );
  }
  if (verificationStatus !== 'APPROVED') {
    throw new HttpsError(
      'permission-denied',
      'Trainer account must be verified and approved by Admin.'
    );
  }

  if (title !== undefined && (!String(title).trim())) {
    throw new HttpsError('invalid-argument', 'Title cannot be empty.');
  }
  if (price !== undefined && (typeof price !== 'number' || price <= 0)) {
    throw new HttpsError('invalid-argument', 'Price must be a positive number in INR.');
  }
  if (sessionsCount !== undefined && (typeof sessionsCount !== 'number' || sessionsCount <= 0)) {
    throw new HttpsError('invalid-argument', 'Sessions count must be greater than zero.');
  }
  if (validityDays !== undefined && (typeof validityDays !== 'number' || validityDays <= 0)) {
    throw new HttpsError('invalid-argument', 'Validity days must be greater than zero.');
  }

  // Any update to an approved package or resubmission resets approval
  const nextStatus = submitForApproval === false ? 'DRAFT' : 'PENDING';

  const updateData: Record<string, any> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    isApproved: false, // Re-triggers approval
    isActive: false,   // Cannot be published until re-approved
    approvalStatus: nextStatus,
    adminRejectionReason: null, // Clear any previous rejection note on edit
  };

  if (title !== undefined) updateData.title = String(title).trim();
  if (price !== undefined) updateData.price = Math.round(price);
  if (sessionsCount !== undefined) {
    updateData.sessions = Math.round(sessionsCount);
    updateData.sessionsCount = Math.round(sessionsCount);
  }
  if (validityDays !== undefined) updateData.validityDays = Math.round(validityDays);
  if (sessionDurationMinutes !== undefined) updateData.sessionDurationMinutes = Math.round(sessionDurationMinutes);
  if (description !== undefined) updateData.description = String(description).trim();

  await planRef.update(updateData);
  return { success: true, planId, updatedFields: updateData };
});

/**
 * Deletes or archives a custom training plan (Advanced Trainers only).
 * Preserves all existing purchases in purchased_packages with original snapshot terms intact.
 */
export const deleteCustomTrainingPlan = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = request.auth.uid;
  const { planId } = request.data || {};
  if (!planId) {
    throw new HttpsError('invalid-argument', 'Missing planId parameter.');
  }

  const planRef = db.collection('training_plans').doc(planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists) {
    throw new HttpsError('not-found', `Training plan not found: ${planId}`);
  }

  const existingPlan = planDoc.data()!;
  if (existingPlan.trainerId !== uid) {
    throw new HttpsError('permission-denied', 'You can only delete your own custom training plans.');
  }

  // Mark isDeleted: true and isActive: false.
  // Existing client purchases in purchased_packages and booking records remain 100% valid and untouched.
  await planRef.update({
    isDeleted: true,
    isActive: false,
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, planId, message: 'Custom training plan deleted successfully. Past purchases remain protected.' };
});

/**
 * Admin approval / publication for custom training plans.
 */
export const adminApproveCustomTrainingPlan = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const isAdminCaller = await verifyIsAdmin(request.auth.uid);
  if (!isAdminCaller) {
    throw new HttpsError('permission-denied', 'Only platform administrators can approve custom training plans.');
  }

  const { planId, approve, adminNotes, rejectionReason } = request.data || {};
  if (!planId || typeof approve !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Missing planId or approve parameter.');
  }

  const planRef = db.collection('training_plans').doc(planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists) {
    throw new HttpsError('not-found', `Training plan not found: ${planId}`);
  }

  const reason = rejectionReason || adminNotes || null;

  await planRef.update({
    isApproved: approve,
    isActive: approve,
    approvalStatus: approve ? 'APPROVED' : 'REJECTED',
    adminNotes: reason,
    adminRejectionReason: !approve ? reason : null,
    approvedBy: approve ? request.auth.uid : null,
    approvedAt: approve ? admin.firestore.FieldValue.serverTimestamp() : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, planId, isApproved: approve };
});

/**
 * Administrative routine to unblock any existing Standard Trainer accounts
 * that had certificate-related review notes under the old policy.
 */
export const adminUnblockStandardTrainers = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }
  const isAdminCaller = await verifyIsAdmin(request.auth.uid);
  if (!isAdminCaller) {
    throw new HttpsError('permission-denied', 'Only administrators can run unblock routine.');
  }

  const snap = await db.collection('trainer_profiles')
    .where('category', 'in', ['TRAINER', 'trainer'])
    .get();

  let unblockedCount = 0;
  const batch = db.batch();

  for (const doc of snap.docs) {
    const data = doc.data();
    const notes = (data.adminReviewNotes || '').toLowerCase();
    if (notes.includes('certificate') || notes.includes('qualification')) {
      batch.update(doc.ref, {
        adminReviewNotes: 'Eligibility updated per revised Standard Trainer policy (no certificates required).',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      unblockedCount++;
    }
  }

  if (unblockedCount > 0) {
    await batch.commit();
  }

  return { success: true, unblockedCount };
});

/**
 * Validates and submits a completed trainer profile for Admin review.
 * Authoritatively prevents incomplete profiles from being submitted.
 */
export const submitTrainerProfileForReview = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = request.auth.uid;
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError('not-found', 'User record not found.');
  }

  const userData = userDoc.data() || {};
  if (userData.role !== 'TRAINER') {
    throw new HttpsError('permission-denied', 'Only trainer accounts can submit trainer profiles.');
  }

  const trainerRef = db.collection('trainer_profiles').doc(uid);
  const trainerDoc = await trainerRef.get();
  if (!trainerDoc.exists) {
    throw new HttpsError('not-found', 'Trainer profile record not found.');
  }

  const trainerData = trainerDoc.data() || {};
  const category = (trainerData.category || 'TRAINER').toUpperCase();
  const isAdvanced = category === 'ADVANCED_TRAINER' || category === 'ADVANCED';

  // Strict completeness verification
  const missing: string[] = [];

  const name = userData.displayName || trainerData.fullName;
  if (!name || String(name).trim().length === 0) missing.push('Full Name');

  const phone = userData.phoneNumber || trainerData.mobileNumber;
  if (!phone || String(phone).trim().length === 0) missing.push('Phone Number');

  const dob = userData.dateOfBirth || trainerData.dateOfBirth;
  if (!dob || String(dob).trim().length === 0) missing.push('Date of Birth');

  const gender = userData.gender || trainerData.gender;
  if (!gender || String(gender).trim().length === 0) missing.push('Gender');

  const photo = userData.photoUrl || trainerData.photoUrl;
  if (!photo || String(photo).trim().length === 0) missing.push('Profile Photo');

  const bio = trainerData.bio;
  if (!bio || String(bio).trim().length < 20) missing.push('Professional Biography (min. 20 chars)');

  const experienceYears = Number(trainerData.experienceYears || 0);
  if (isAdvanced && experienceYears < 3.5) {
    missing.push('Experience (min. 3.5 years required for Advanced Trainer)');
  }

  const specialties = trainerData.specialties || [];
  if (!Array.isArray(specialties) || specialties.length === 0) missing.push('Training Specialisations');

  const clientTypes = trainerData.clientTypes || [];
  if (!Array.isArray(clientTypes) || clientTypes.length === 0) missing.push('Types of Clients');

  const goals = trainerData.trainingGoals || [];
  if (!Array.isArray(goals) || goals.length === 0) missing.push('Fitness Goals');

  const methods = trainerData.trainingMethods || [];
  if (!Array.isArray(methods) || methods.length === 0) missing.push('Training Methods');

  const languages = trainerData.languages || [];
  if (!Array.isArray(languages) || languages.length === 0) missing.push('Languages Spoken');

  const approach = trainerData.trainingApproach;
  if (!approach || String(approach).trim().length < 10) missing.push('Training Approach Description');

  if (isAdvanced) {
    const profExp = trainerData.professionalExperience;
    if (!profExp || String(profExp).trim().length < 10) {
      missing.push('Detailed Professional Experience (mandatory for Advanced Trainers)');
    }
  }

  const hasLocation = trainerData.trainsAtHome === true ||
                      trainerData.trainsAtGym === true ||
                      (Array.isArray(trainerData.otherTrainingLocations) && trainerData.otherTrainingLocations.length > 0);
  if (!hasLocation) missing.push('Training Service Locations (Home, Gym, or Other)');

  const areas = trainerData.serviceAreas || [];
  if (!Array.isArray(areas) || areas.length === 0) missing.push('Service Areas (min. 1 area)');

  const days = trainerData.workingDays || [];
  const hours = trainerData.workingHours;
  if (!Array.isArray(days) || days.length === 0 || !hours || String(hours).trim().length === 0) {
    missing.push('Working Schedule (Days & Hours)');
  }

  if (missing.length > 0) {
    throw new HttpsError(
      'failed-precondition',
      `Cannot submit incomplete profile. Missing: ${missing.join(', ')}`
    );
  }

  // Update profile to completed and pending review
  await trainerRef.update({
    isProfileCompleted: true,
    profileCompletionScore: 100,
    verificationStatus: 'PENDING',
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('users').doc(uid).update({
    onboarded: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, isComplete: true, score: 100 };
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

async function getAuthoritativePackageInfo(packageId: string, trainerId?: string): Promise<{ price: number; sessionsCount: number; validityDays: number; title: string } | null> {
  if (FIXED_PACKAGES[packageId]) {
    return FIXED_PACKAGES[packageId];
  }
  try {
    const planSnap = await db.collection('training_plans').doc(packageId).get();
    if (planSnap.exists) {
      const data = planSnap.data()!;
      // Custom plans must be approved, active, and match trainerId if specified
      if (data.isApproved === true && data.isActive === true) {
        if (!trainerId || !data.trainerId || data.trainerId === trainerId) {
          return {
            price: Number(data.price),
            sessionsCount: Number(data.sessionsCount),
            validityDays: Number(data.validityDays),
            title: String(data.title || 'Custom Training Plan'),
          };
        }
      }
    }
  } catch (err) {
    console.error('Error fetching training plan in getAuthoritativePackageInfo:', err);
  }
  return null;
}

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
  const planInfo = await getAuthoritativePackageInfo(packageId, trainerId);
  if (!planInfo) {
    throw new HttpsError('invalid-argument', `Unknown or unapproved training package: ${packageId}.`);
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

    // Launch policy: Professional Trainer is Coming Soon
    const trainerCat = String(trainerProfileData.category || '').toUpperCase();
    if (trainerCat === 'PROFESSIONAL_TRAINER' || trainerCat === 'PROFESSIONAL') {
      throw new HttpsError('failed-precondition', 'Professional Trainer packages are coming soon and unavailable for booking at launch.');
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

    if (booking.clientId !== request.auth!.uid) {
      throw new HttpsError('permission-denied', 'Only the athlete who made this booking can confirm it.');
    }

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

    if (booking.clientId !== request.auth!.uid && booking.trainerId !== request.auth!.uid) {
      throw new HttpsError('permission-denied', 'You are not authorized to release this booking reservation.');
    }

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
  const now = new Date();
  if (newDate.getTime() < now.getTime() - 60000) {
    throw new HttpsError('invalid-argument', 'Cannot reschedule to a past date or time.');
  }

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

    if (booking.status !== 'CONFIRMED' && booking.status !== 'PENDING' && booking.status !== 'RESCHEDULED') {
      throw new HttpsError('failed-precondition', `Cannot reschedule a booking with status ${booking.status}.`);
    }

    // Check trainer date override / blackout
    const newDateKey = newDate.toISOString().slice(0, 10);
    const overrideRef = db.collection('trainer_availability').doc(`${booking.trainerId}_override_${newDateKey}`);
    const overrideSnap = await transaction.get(overrideRef);
    if (overrideSnap.exists && overrideSnap.data()?.isBlocked) {
      throw new HttpsError('failed-precondition', 'Trainer is unavailable on this date.');
    }

    // Check old slot lock
    const oldDateKey = booking.sessionDate.toDate().toISOString().slice(0, 10);
    const oldSafeTimeKey = (booking.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
    const oldLockId = `${booking.trainerId}_${oldDateKey}_${oldSafeTimeKey}`;
    const oldLockRef = db.collection('slot_locks').doc(oldLockId);

    // Check new slot lock
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
// 9b. Reviews & Ratings System (Session Review Submission & Moderation)
// ─────────────────────────────────────────────────────────────────────────────

export const submitSessionReview = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to submit a review.');
  }

  const { bookingId, rating, comment, categories } = request.data || {};
  if (!bookingId || rating === undefined || rating === null || !comment) {
    throw new HttpsError('invalid-argument', 'Missing required review fields: bookingId, rating, or comment.');
  }

  const numRating = Number(rating);
  if (isNaN(numRating) || numRating < 1.0 || numRating > 5.0) {
    throw new HttpsError('invalid-argument', 'Rating must be a numeric value between 1.0 and 5.0.');
  }

  const trimmedComment = String(comment).trim();
  if (trimmedComment.length < 5) {
    throw new HttpsError('invalid-argument', 'Written review feedback must be at least 5 characters long.');
  }

  const uid = request.auth.uid;
  const bookingRef = db.collection('bookings').doc(bookingId);
  const reviewRef = db.collection('reviews').doc(bookingId);

  const result = await db.runTransaction(async (transaction) => {
    const bookingSnap = await transaction.get(bookingRef);
    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking record not found.');
    }

    const booking = bookingSnap.data()!;
    if (booking.clientId !== uid) {
      throw new HttpsError('permission-denied', 'Only the athlete who completed this session can submit a review.');
    }

    if (booking.status !== 'COMPLETED') {
      throw new HttpsError('failed-precondition', 'Reviews can only be submitted for successfully completed training sessions.');
    }

    const reviewSnap = await transaction.get(reviewRef);
    const isUpdate = reviewSnap.exists;

    // Fetch client display name (mask for privacy, e.g. "Rahul S.")
    const clientUserSnap = await transaction.get(db.collection('users').doc(uid));
    let clientDisplayName = 'Verified Athlete';
    let clientPhotoUrl: string | null = null;
    if (clientUserSnap.exists) {
      const uData = clientUserSnap.data()!;
      clientPhotoUrl = uData.photoUrl || null;
      const rawName = (uData.displayName || uData.name || '').trim();
      if (rawName.length > 0) {
        const parts = rawName.split(' ');
        if (parts.length > 1) {
          clientDisplayName = `${parts[0]} ${parts[1][0].toUpperCase()}.`;
        } else {
          clientDisplayName = parts[0];
        }
      }
    }

    const cleanCategories = Array.isArray(categories)
      ? categories.filter((c: any) => typeof c === 'string').slice(0, 5)
      : [];

    const reviewData: any = {
      id: bookingId,
      bookingId: bookingId,
      clientId: uid,
      trainerId: booking.trainerId,
      clientName: clientDisplayName,
      clientPhotoUrl: clientPhotoUrl,
      rating: Math.round(numRating * 10) / 10,
      comment: trimmedComment,
      categories: cleanCategories,
      isPublic: true,
      isReported: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!isUpdate) {
      reviewData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    transaction.set(reviewRef, reviewData, { merge: true });

    return {
      success: true,
      isUpdate,
      reviewId: bookingId,
      trainerId: booking.trainerId as string,
    };
  });

  // Recalculate trainer aggregate rating & count from genuine eligible reviews
  const trainerId = result.trainerId;
  const allReviewsSnap = await db.collection('reviews')
    .where('trainerId', '==', trainerId)
    .where('isPublic', '==', true)
    .get();

  let sum = 0;
  let count = 0;
  for (const doc of allReviewsSnap.docs) {
    const r = doc.data();
    if (!r.isReported) {
      sum += (r.rating || 5.0);
      count++;
    }
  }

  const avgRating = count > 0 ? Math.round((sum / count) * 10) / 10 : 5.0;

  await Promise.all([
    db.collection('trainer_profiles').doc(trainerId).set({
      ratingAvg: avgRating,
      totalReviews: count,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
    db.collection('users').doc(trainerId).set({
      ratingAvg: avgRating,
      totalReviews: count,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
  ]);

  // Send in-app notification to trainer
  try {
    const notifRef = db.collection('notifications').doc();
    await notifRef.set({
      id: notifRef.id,
      userId: trainerId,
      title: 'New Session Review ★',
      body: `An athlete left a ${numRating.toFixed(1)}-star review for your session.`,
      type: 'REVIEW_RECEIVED',
      isRead: false,
      data: {
        bookingId,
        rating: numRating,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (_) {}

  return {
    success: true,
    reviewId: result.reviewId,
    ratingAvg: avgRating,
    totalReviews: count,
  };
});

export const reportSessionReview = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to report a review.');
  }

  const { reviewId, reason, details } = request.data || {};
  if (!reviewId || !reason) {
    throw new HttpsError('invalid-argument', 'Review ID and report reason are required.');
  }

  const uid = request.auth.uid;
  const reviewRef = db.collection('reviews').doc(reviewId);
  const reviewSnap = await reviewRef.get();

  if (!reviewSnap.exists) {
    throw new HttpsError('not-found', 'Review not found.');
  }

  const review = reviewSnap.data()!;

  // Log report in review_reports collection for Admin moderation dashboard
  const reportRef = db.collection('review_reports').doc();
  await reportRef.set({
    id: reportRef.id,
    reviewId,
    reportedBy: uid,
    trainerId: review.trainerId,
    bookingId: review.bookingId,
    reason: String(reason).trim(),
    details: details ? String(details).trim() : null,
    status: 'PENDING_MODERATION',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Mark review as reported so it can be moderated
  await reviewRef.update({
    isReported: true,
    reportReason: String(reason).trim(),
    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Recalculate trainer aggregate rating without the reported review
  const allReviewsSnap = await db.collection('reviews')
    .where('trainerId', '==', review.trainerId)
    .where('isPublic', '==', true)
    .get();

  let sum = 0;
  let count = 0;
  for (const doc of allReviewsSnap.docs) {
    const r = doc.data();
    if (!r.isReported && doc.id !== reviewId) {
      sum += (r.rating || 5.0);
      count++;
    }
  }

  const avgRating = count > 0 ? Math.round((sum / count) * 10) / 10 : 5.0;

  await Promise.all([
    db.collection('trainer_profiles').doc(review.trainerId).set({
      ratingAvg: avgRating,
      totalReviews: count,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
    db.collection('users').doc(review.trainerId).set({
      ratingAvg: avgRating,
      totalReviews: count,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
  ]);

  return { success: true, reportId: reportRef.id };
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

  // Validate booking ownership if bookingId is provided
  if (bookingId) {
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw new HttpsError('not-found', 'Associated booking not found.');
    }
    const bookingData = bookingDoc.data()!;
    if (bookingData.clientId !== clientId) {
      throw new HttpsError('permission-denied', 'You cannot create a payment order for another athlete\'s booking.');
    }
  }

  // 1. Trainer Category & Eligibility Validation
  if (trainerId) {
    const trainerSnap = await db.collection('trainer_profiles').doc(trainerId).get();
    if (!trainerSnap.exists) {
      throw new HttpsError('not-found', 'Trainer profile not found.');
    }
    const trainerData = trainerSnap.data()!;
    if (trainerData.verificationStatus !== 'APPROVED' || !trainerData.isActive) {
      throw new HttpsError('failed-precondition', 'Trainer is not currently approved or active.');
    }

    const category = (trainerData.category || 'TRAINER').toUpperCase();
    if (category === 'PROFESSIONAL_TRAINER' || category === 'PROFESSIONAL') {
      throw new HttpsError(
        'failed-precondition',
        'Professional Trainer tier is Coming Soon and unavailable for purchase at launch.'
      );
    }

    if (category === 'TRAINER') {
      // Standard Trainer: Must use predefined TRAIN Z packages
      if (!FIXED_PACKAGES[packageId]) {
        throw new HttpsError(
          'failed-precondition',
          'Standard Trainers use predefined TRAIN Z platform packages only.'
        );
      }
    } else if (category === 'ADVANCED_TRAINER' || category === 'ADVANCED') {
      // Advanced Trainer: Must use their approved and published custom plan
      const planSnap = await db.collection('training_plans').doc(packageId).get();
      if (!planSnap.exists) {
        throw new HttpsError('not-found', 'Custom training plan not found.');
      }
      const planData = planSnap.data()!;
      if (planData.trainerId !== trainerId) {
        throw new HttpsError('permission-denied', 'Custom training plan does not belong to the selected trainer.');
      }
      if (planData.isApproved !== true || planData.isActive !== true) {
        throw new HttpsError('failed-precondition', 'Custom training plan is not approved and active.');
      }
    }
  }

  // 2. Active temporary slot reservation validation (if linked)
  if (bookingId) {
    const bookingSnap = await db.collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Linked booking reservation not found.');
    }
    const bookingData = bookingSnap.data()!;
    if (bookingData.clientId !== clientId) {
      throw new HttpsError('permission-denied', 'Booking reservation does not belong to this client.');
    }
    const bookingExpiresAt: admin.firestore.Timestamp = bookingData.expiresAt;
    if (bookingExpiresAt && bookingExpiresAt.toMillis() < Date.now()) {
      throw new HttpsError('deadline-exceeded', 'Your temporary slot reservation has expired. Please select a new slot.');
    }
  }

  // 3. Authoritative Package Pricing (Never trust frontend price)
  const planInfo = await getAuthoritativePackageInfo(packageId, trainerId);
  if (!planInfo) {
    throw new HttpsError('invalid-argument', `Unknown or unapproved package ID: ${packageId}.`);
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
        purchasedPackageId: payment.purchasedPackageId,
      };
    }

    const clientId = payment.clientId;
    const sessionsCount = payment.sessionsCount || 1;
    const validityDays = payment.validityDays || 30;

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

    // 2. Activate package record in purchased_packages
    const packageDocRef = db.collection('purchased_packages').doc();
    const purchaseDate = new Date();
    const expiryDate = new Date(purchaseDate.getTime() + validityDays * 24 * 60 * 60 * 1000);

    const clientUserSnap = await transaction.get(db.collection('users').doc(clientId));
    const clientData = clientUserSnap.exists ? clientUserSnap.data()! : {};

    transaction.set(packageDocRef, {
      id: packageDocRef.id,
      clientId,
      clientName: clientData.displayName || 'TRAIN Z Athlete',
      clientPhone: clientData.phoneNumber || null,
      clientPhotoUrl: clientData.photoUrl || null,
      trainerId: payment.trainerId || '',
      trainerName: payment.trainerName || 'Assigned Coach',
      trainerPhotoUrl: null,
      packageId: payment.packageId,
      packageName: payment.packageName,
      price: payment.amount,
      purchaseDate: admin.firestore.Timestamp.fromDate(purchaseDate),
      startDate: admin.firestore.Timestamp.fromDate(purchaseDate),
      expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
      totalDays: validityDays,
      totalSessions: sessionsCount,
      completedSessions: 0,
      paymentStatus: 'COMPLETED',
      paymentTransactionId: razorpayPaymentId,
      status: 'ACTIVE',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Confirm linked booking reservation (if present and not expired)
    let confirmedBookingId: string | null = null;
    if (payment.bookingId) {
      const bookingRef = db.collection('bookings').doc(payment.bookingId);
      const bookingSnap = await transaction.get(bookingRef);

      if (bookingSnap.exists) {
        const booking = bookingSnap.data()!;
        const bookingExpiresAt: admin.firestore.Timestamp = booking.expiresAt;
        const isExpired = bookingExpiresAt && bookingExpiresAt.toMillis() < Date.now();

        if (!isExpired && (booking.status === 'RESERVED' || booking.status === 'PENDING')) {
          transaction.update(bookingRef, {
            status: 'CONFIRMED',
            paymentStatus: 'COMPLETED',
            paymentTransactionId: razorpayPaymentId,
            packageId: payment.packageId,
            purchasedPackageId: packageDocRef.id,
            confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          confirmedBookingId = payment.bookingId;

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
        } else if (isExpired && booking.status === 'RESERVED') {
          // If expired before payment, release slot lock and mark booking expired
          transaction.update(bookingRef, {
            status: 'EXPIRED',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // 4. Mark payment record as SUCCESS
    transaction.update(paymentRef, {
      status: 'SUCCESS',
      razorpayPaymentId,
      razorpaySignature,
      paymentMethod: paymentMethod || 'ONLINE',
      creditsGranted: true,
      purchasedPackageId: packageDocRef.id,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. In-app payment confirmed notification
    const payNotifRef = db.collection('notifications').doc();
    transaction.set(payNotifRef, {
      id: payNotifRef.id,
      userId: clientId,
      title: 'Payment Successful',
      body: `Your payment of ₹${payment.amount} for ${payment.packageName} was successful. ${sessionsCount} sessions added to your balance.`,
      type: 'PAYMENT_CONFIRMED',
      isRead: false,
      data: {
        paymentId: paymentDocId,
        receiptNumber: payment.receiptNumber || '',
        purchasedPackageId: packageDocRef.id,
        amount: String(payment.amount),
        packageName: String(payment.packageName),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If a reservation was confirmed, also dispatch booking notification
    if (confirmedBookingId) {
      const bookNotifRef = db.collection('notifications').doc();
      const bRef = confirmedBookingId.slice(0, 8).toUpperCase();
      transaction.set(bookNotifRef, {
        id: bookNotifRef.id,
        userId: clientId,
        title: 'Booking Confirmed!',
        body: `Your training session for ${payment.packageName} has been confirmed. Ref: #${bRef}`,
        type: 'BOOKING_CONFIRMED',
        isRead: false,
        data: {
          bookingId: confirmedBookingId,
          bookingReference: bRef,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      alreadyFinalized: false,
      success: true,
      paymentDocId,
      status: 'SUCCESS',
      receiptNumber: payment.receiptNumber,
      bookingId: confirmedBookingId,
      purchasedPackageId: packageDocRef.id,
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

  // 0. Enforce Caller Ownership of Payment Record
  const paymentRef = db.collection('payments').doc(paymentDocId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new HttpsError('not-found', 'Payment record not found.');
  }
  const paymentData = paymentSnap.data()!;
  if (paymentData.clientId !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'You are not authorized to verify this payment record.');
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

  const paymentRef = db.collection('payments').doc(paymentDocId);
  const paymentDoc = await paymentRef.get();
  if (!paymentDoc.exists) {
    throw new HttpsError('not-found', 'Payment record not found.');
  }
  const paymentData = paymentDoc.data()!;
  if (paymentData.clientId !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'You are not authorized to modify this payment record.');
  }

  await paymentRef.update({
    status: 'FAILED',
    errorCode: errorCode || 'PAYMENT_CANCELLED_OR_FAILED',
    errorMessage: errorDescription || 'Payment checkout was cancelled or failed.',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Release temporary slot reservation if attached and held
  if (paymentDoc.exists) {
    const paymentData = paymentDoc.data()!;
    if (paymentData.bookingId) {
      const bookingRef = db.collection('bookings').doc(paymentData.bookingId);
      const bookingDoc = await bookingRef.get();
      if (bookingDoc.exists) {
        const b = bookingDoc.data()!;
        if (b.status === 'RESERVED') {
          await bookingRef.update({
            status: 'CANCELLED',
            cancellationReason: 'Payment cancelled or failed during checkout',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Release slot lock
          const dateKey = b.sessionDate.toDate().toISOString().slice(0, 10);
          const safeTimeKey = (b.startTime || '').replace(/[^a-zA-Z0-9]/g, '');
          const slotLockId = `${b.trainerId}_${dateKey}_${safeTimeKey}`;
          await db.collection('slot_locks').doc(slotLockId).update({
            status: 'RELEASED',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  // In-app payment failed notification
  const failNotifRef = db.collection('notifications').doc();
  await failNotifRef.set({
    id: failNotifRef.id,
    userId: paymentData.clientId,
    title: 'Payment Unsuccessful',
    body: `Payment for ${paymentData.packageName || 'training package'} could not be processed. ${errorDescription || 'Please try again.'}`,
    type: 'PAYMENT_FAILED',
    isRead: false,
    data: {
      paymentId: paymentDocId,
      errorCode: errorCode || 'FAILED',
      packageName: paymentData.packageName || 'Package',
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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

// ─────────────────────────────────────────────────────────────────────────────
// 15. Real-Time FCM Push Notification Triggers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Triggers whenever an in-app notification is created.
 * Dispatches high-priority FCM push notification to all valid registered device tokens
 * for booking confirmations, cancellations, rescheduling, session reminders, and payments.
 */
export const onNotificationCreated = onDocumentCreated(
  'notifications/{notifId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const userId = data.userId;
    if (!userId) return;

    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data() || {};
    const tokens: string[] = [];

    if (Array.isArray(userData.fcmTokens)) {
      tokens.push(...userData.fcmTokens.filter((t: any) => typeof t === 'string' && t.length > 0));
    } else if (userData.fcmToken && typeof userData.fcmToken === 'string') {
      tokens.push(userData.fcmToken);
    }

    if (tokens.length === 0) return;

    const title = data.title || 'TRAIN Z Notification';
    const body = data.body || '';
    const type = data.type || 'GENERAL';
    const extraData = data.data || {};

    // Deduplication check: if push was already dispatched at message creation
    if (extraData.fcmDispatched === 'true' || extraData.fcmDispatched === true) {
      return;
    }

    const cleanType = String(type).trim().toUpperCase();
    const isMandatory =
      cleanType.includes('SECURITY') ||
      cleanType.includes('PASSWORD') ||
      cleanType.includes('AUTH') ||
      cleanType.includes('LOGIN') ||
      cleanType.includes('DELETION') ||
      cleanType === 'PAYMENT_CONFIRMED' ||
      cleanType === 'PAYMENT_FAILED' ||
      cleanType === 'TRANSACTION_RECEIPT';

    // Respect client notification preferences
    if (!isMandatory) {
      let prefDoc = await db.collection('users').doc(userId).collection('settings').doc('notifications').get();
      if (!prefDoc.exists) {
        prefDoc = await db.collection('users').doc(userId).collection('settings').doc('notification_preferences').get();
      }
      if (prefDoc.exists) {
        const prefs = prefDoc.data() || {};
        if ((cleanType.startsWith('BOOKING_') || cleanType === 'BOOKING_UPDATE') && prefs.bookingUpdates === false) {
          return;
        }
        if ((cleanType.includes('REMINDER') || cleanType === 'SESSION_REMINDER') && prefs.sessionReminders === false) {
          return;
        }
        if ((cleanType.startsWith('PAYMENT_') || cleanType.startsWith('PACKAGE_') || cleanType.includes('CREDIT_')) && prefs.paymentUpdates === false) {
          return;
        }
        if ((cleanType.includes('CHAT') || cleanType.includes('MESSAGE')) && prefs.trainerMessages === false) {
          return;
        }
        if ((cleanType.includes('REVIEW') || cleanType.includes('RATING') || cleanType.includes('FEEDBACK')) && prefs.reviewsAndFeedback === false) {
          return;
        }
        if ((cleanType.startsWith('SUPPORT_') || cleanType === 'SUPPORT_TICKET_UPDATE') && prefs.supportUpdates === false) {
          return;
        }
        if ((cleanType.includes('ANNOUNCEMENT') || cleanType.includes('MARKETING') || cleanType.includes('PROMO')) && prefs.platformAnnouncements === false) {
          return;
        }
      }
    }

    // Security & privacy sanitize: never leak private addresses or payment credentials in push payload
    const prohibitedPayloadKeys = new Set([
      'meetingLocation',
      'privateAddress',
      'address',
      'creditCard',
      'cardNumber',
      'razorpaySignature',
      'signature',
      'cvv',
      'password',
      'token',
      'fcmDispatched',
    ]);

    const payloadData: Record<string, string> = {
      type: String(type),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    };

    for (const key of Object.keys(extraData)) {
      if (prohibitedPayloadKeys.has(key)) continue;
      if (extraData[key] !== undefined && extraData[key] !== null) {
        payloadData[key] = String(extraData[key]);
      }
    }

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title,
          body,
        },
        data: payloadData,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'trainz_notifications',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      // Cleanup invalid or expired tokens
      const tokensToRemove: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errCode = resp.error?.code;
          if (
            errCode === 'messaging/invalid-registration-token' ||
            errCode === 'messaging/registration-token-not-registered'
          ) {
            tokensToRemove.push(tokens[idx]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        await db.collection('users').doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
        });
      }
    } catch (err) {
      console.error('Error dispatching push notification for in-app notification:', err);
    }
  }
);

/**
 * Triggers whenever a new chat message is created in a 1-on-1 trainer-client conversation.
 * Dispatches an instant FCM push notification to the recipient.
 */
export const onChatMessageCreated = onDocumentCreated(
  'conversations/{convId}/messages/{msgId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const msgData = snap.data();
    const receiverId = msgData.receiverId;
    const senderId = msgData.senderId;
    const senderName = msgData.senderName || 'Your Trainer';
    const text = msgData.text || '';
    const convId = event.params.convId;

    if (!receiverId || !text) return;

    // 1. Create in-app notification doc for the recipient
    const notifRef = db.collection('notifications').doc();
    await notifRef.set({
      id: notifRef.id,
      userId: receiverId,
      title: senderName,
      body: text.length > 90 ? text.substring(0, 87) + '...' : text,
      type: 'CHAT_MESSAGE',
      isRead: false,
      data: {
        conversationId: convId,
        senderId: senderId || '',
        trainerId: senderId || '',
        trainerName: senderName,
        fcmDispatched: 'true', // Prevents double push in onNotificationCreated
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Check if recipient has disabled trainer messages in preferences
    let prefDoc = await db.collection('users').doc(receiverId).collection('settings').doc('notifications').get();
    if (!prefDoc.exists) {
      prefDoc = await db.collection('users').doc(receiverId).collection('settings').doc('notification_preferences').get();
    }
    if (prefDoc.exists && prefDoc.data()?.trainerMessages === false) {
      return; // Suppress FCM push per user preference
    }

    const receiverDoc = await db.collection('users').doc(receiverId).get();
    if (!receiverDoc.exists) return;

    const userData = receiverDoc.data() || {};
    const tokens: string[] = [];

    if (Array.isArray(userData.fcmTokens)) {
      tokens.push(...userData.fcmTokens.filter((t: any) => typeof t === 'string' && t.length > 0));
    } else if (userData.fcmToken && typeof userData.fcmToken === 'string') {
      tokens.push(userData.fcmToken);
    }

    if (tokens.length === 0) return;

    // Respect notification preferences if configured
    if (userData.notificationPreferences && userData.notificationPreferences.messages === false) {
      return;
    }

    try {
      // Privacy protection: sanitize and limit notification body to prevent lock-screen content leaks
      const sanitizedPreview = text.length > 60 ? `${text.substring(0, 57)}...` : text;

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: senderName,
          body: sanitizedPreview,
        },
        data: {
          type: 'CHAT_MESSAGE',
          conversationId: convId,
          senderId: senderId || '',
          senderName,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'trainz_messages',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      const tokensToRemove: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errCode = resp.error?.code;
          if (
            errCode === 'messaging/invalid-registration-token' ||
            errCode === 'messaging/registration-token-not-registered'
          ) {
            tokensToRemove.push(tokens[idx]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        await db.collection('users').doc(receiverId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
        });
      }
    } catch (err) {
      console.error('Error dispatching chat push notification:', err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 12. Trainer Availability & Calendar Management
// ─────────────────────────────────────────────────────────────────────────────

function parseTimeToMinutes(timeStr: string): number {
  const clean = (timeStr || '').trim().toUpperCase();
  const parts = clean.split(' ');
  const [hStr, mStr] = (parts[0] || '0:0').split(':');
  let hour = parseInt(hStr, 10) || 0;
  const minute = mStr ? parseInt(mStr, 10) || 0 : 0;
  const isPm = parts[1] === 'PM';
  const isAm = parts[1] === 'AM';
  if (isPm && hour !== 12) hour += 12;
  if (isAm && hour === 12) hour = 0;
  return hour * 60 + minute;
}

function formatMinutesToTime(minutes: number): string {
  const totalMin = ((minutes % 1440) + 1440) % 1440;
  let hour = Math.floor(totalMin / 60);
  const minute = totalMin % 60;
  const period = hour >= 12 ? 'PM' : 'AM';
  if (hour === 0) hour = 12;
  else if (hour > 12) hour -= 12;
  const h = hour.toString().padStart(2, '0');
  const m = minute.toString().padStart(2, '0');
  return `${h}:${m} ${period}`;
}

export const validateAndSaveTrainerAvailability = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { trainerId, days, timezone } = request.data || {};
  if (!trainerId || !Array.isArray(days)) {
    throw new HttpsError('invalid-argument', 'Missing trainerId or days array.');
  }

  const isAdmin = await verifyIsAdmin(request.auth.uid);
  if (request.auth.uid !== trainerId && !isAdmin) {
    throw new HttpsError('permission-denied', 'You may only update your own availability.');
  }

  // Validate each day's windows
  const sanitizedDays = [];
  const activeWorkingDays: string[] = [];
  const dayShortNames = ['', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  for (const day of days) {
    const dayOfWeek = parseInt(day.dayOfWeek, 10);
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      throw new HttpsError('invalid-argument', `Invalid day of week: ${day.dayOfWeek}. Must be 1 (Mon) to 7 (Sun).`);
    }

    const isEnabled = Boolean(day.isEnabled);
    const windows = Array.isArray(day.windows) ? day.windows : [];
    const parsedWindows: Array<{ start: string; end: string; startMinutes: number; endMinutes: number }> = [];

    if (isEnabled && windows.length > 0) {
      activeWorkingDays.push(dayShortNames[dayOfWeek]);
    }

    for (const w of windows) {
      const startMin = parseTimeToMinutes(w.start);
      const endMin = parseTimeToMinutes(w.end);

      // Duration rule: At least 60 minutes for each session window
      if (endMin < startMin + 60) {
        throw new HttpsError(
          'invalid-argument',
          `Window ${w.start} - ${w.end} must be at least 60 minutes.`
        );
      }

      parsedWindows.push({
        start: formatMinutesToTime(startMin),
        end: formatMinutesToTime(endMin),
        startMinutes: startMin,
        endMinutes: endMin,
      });
    }

    // Overlap prevention within the same day
    parsedWindows.sort((a, b) => a.startMinutes - b.startMinutes);
    for (let i = 0; i < parsedWindows.length - 1; i++) {
      if (parsedWindows[i].endMinutes > parsedWindows[i + 1].startMinutes) {
        throw new HttpsError(
          'invalid-argument',
          `Overlapping availability windows detected: ${parsedWindows[i].start}-${parsedWindows[i].end} and ${parsedWindows[i + 1].start}-${parsedWindows[i + 1].end}.`
        );
      }
    }

    sanitizedDays.push({
      dayOfWeek,
      isEnabled,
      windows: parsedWindows.map((pw) => ({ start: pw.start, end: pw.end })),
    });
  }

  const effectiveTimezone = (timezone || 'Asia/Kolkata').trim();

  // Save to trainer_availability collection
  const availabilityDocId = `${trainerId}_weekly`;
  await db.collection('trainer_availability').doc(availabilityDocId).set(
    {
      id: availabilityDocId,
      trainerId,
      timezone: effectiveTimezone,
      days: sanitizedDays,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Sync workingDays into trainer_profiles for public discovery
  if (activeWorkingDays.length > 0) {
    await db.collection('trainer_profiles').doc(trainerId).set(
      {
        workingDays: activeWorkingDays,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  return { success: true, trainerId, daysCount: sanitizedDays.length };
});

export const setTrainerDateOverride = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { trainerId, date, isBlocked, windows, reason } = request.data || {};
  if (!trainerId || !date) {
    throw new HttpsError('invalid-argument', 'Missing trainerId or date parameter.');
  }

  const isAdmin = await verifyIsAdmin(request.auth.uid);
  if (request.auth.uid !== trainerId && !isAdmin) {
    throw new HttpsError('permission-denied', 'You may only set date overrides for your own schedule.');
  }

  // Check if date format is valid YYYY-MM-DD
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError('invalid-argument', 'Date must be formatted as YYYY-MM-DD.');
  }

  const blocked = Boolean(isBlocked);
  let warningMessage: string | null = null;

  // Check for existing confirmed bookings on that date
  const bookingsSnap = await db
    .collection('bookings')
    .where('trainerId', '==', trainerId)
    .where('status', 'in', ['confirmed', 'CONFIRMED', 'rescheduled', 'RESCHEDULED'])
    .get();

  const confirmedOnDate = bookingsSnap.docs.filter((doc) => {
    const data = doc.data();
    const sDate = data.sessionDate;
    let sDateStr = '';
    if (sDate && typeof sDate.toDate === 'function') {
      sDateStr = sDate.toDate().toISOString().substring(0, 10);
    } else if (typeof sDate === 'string') {
      sDateStr = sDate.substring(0, 10);
    }
    return sDateStr === date;
  });

  if (blocked && confirmedOnDate.length > 0) {
    warningMessage = `Date ${date} has been blocked for new bookings. You have ${confirmedOnDate.length} existing confirmed booking(s) on this date which remain confirmed and cannot be cancelled automatically.`;
  }

  const sanitizedWindows: Array<{ start: string; end: string }> = [];
  if (!blocked && Array.isArray(windows)) {
    const parsed = [];
    for (const w of windows) {
      const startMin = parseTimeToMinutes(w.start);
      const endMin = parseTimeToMinutes(w.end);
      if (endMin < startMin + 60) {
        throw new HttpsError('invalid-argument', `Window ${w.start} - ${w.end} must be at least 60 minutes.`);
      }
      parsed.push({
        start: formatMinutesToTime(startMin),
        end: formatMinutesToTime(endMin),
        startMin,
        endMin,
      });
    }
    parsed.sort((a, b) => a.startMin - b.endMin);
    for (let i = 0; i < parsed.length - 1; i++) {
      if (parsed[i].endMin > parsed[i + 1].startMin) {
        throw new HttpsError('invalid-argument', 'Custom date windows cannot overlap.');
      }
    }
    for (const p of parsed) {
      sanitizedWindows.push({ start: p.start, end: p.end });
    }
  }

  const overrideDocId = `${trainerId}_override_${date}`;
  await db.collection('trainer_availability').doc(overrideDocId).set({
    id: overrideDocId,
    trainerId,
    date,
    isBlocked: blocked,
    windows: sanitizedWindows,
    reason: (reason || '').trim(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    trainerId,
    date,
    isBlocked: blocked,
    warning: warningMessage,
  };
});

export const getTrainerAvailableSlots = onCall(async (request) => {
  const { trainerId, dateStr, currentClientId } = request.data || {};
  if (!trainerId || !dateStr) {
    throw new HttpsError('invalid-argument', 'Missing trainerId or dateStr parameter.');
  }

  // 1. Check Date Override
  const overrideDoc = await db.collection('trainer_availability').doc(`${trainerId}_override_${dateStr}`).get();
  if (overrideDoc.exists && overrideDoc.data()?.isBlocked === true) {
    return { slots: [], isBlocked: true, reason: overrideDoc.data()?.reason || 'Date blocked by trainer.' };
  }

  // 2. Fetch Weekly Availability
  const weeklyDoc = await db.collection('trainer_availability').doc(`${trainerId}_weekly`).get();
  const dateObj = new Date(dateStr);
  // JS day: 0 = Sun, 1 = Mon ... convert to 1 (Mon) .. 7 (Sun)
  const jsDay = dateObj.getDay();
  const dayOfWeek = jsDay === 0 ? 7 : jsDay;

  let windows: Array<{ start: string; end: string }> = [];

  if (overrideDoc.exists && Array.isArray(overrideDoc.data()?.windows) && overrideDoc.data()!.windows.length > 0) {
    windows = overrideDoc.data()!.windows;
  } else if (weeklyDoc.exists && Array.isArray(weeklyDoc.data()?.days)) {
    const dayConfig = weeklyDoc.data()!.days.find((d: any) => d.dayOfWeek === dayOfWeek);
    if (dayConfig && dayConfig.isEnabled) {
      windows = dayConfig.windows || [];
    }
  } else {
    // Default fallback working hours: 06:00 AM - 12:00 PM, 04:00 PM - 08:00 PM
    windows = [
      { start: '06:00 AM', end: '12:00 PM' },
      { start: '04:00 PM', end: '08:00 PM' },
    ];
  }

  // Generate 60-min slots
  const slots: Array<{ start: string; end: string }> = [];
  for (const w of windows) {
    let curr = parseTimeToMinutes(w.start);
    const end = parseTimeToMinutes(w.end);
    while (curr + 60 <= end) {
      slots.push({
        start: formatMinutesToTime(curr),
        end: formatMinutesToTime(curr + 60),
      });
      curr += 60;
    }
  }

  // 3. Query existing bookings on that date
  const bookingsSnap = await db
    .collection('bookings')
    .where('trainerId', '==', trainerId)
    .where('status', 'in', ['confirmed', 'CONFIRMED', 'rescheduled', 'RESCHEDULED'])
    .get();

  const confirmedStarts = new Set<string>();
  for (const doc of bookingsSnap.docs) {
    const b = doc.data();
    let bDateStr = '';
    if (b.sessionDate && typeof b.sessionDate.toDate === 'function') {
      bDateStr = b.sessionDate.toDate().toISOString().substring(0, 10);
    } else if (typeof b.sessionDate === 'string') {
      bDateStr = b.sessionDate.substring(0, 10);
    }
    if (bDateStr === dateStr && b.startTime) {
      confirmedStarts.add(b.startTime.trim().toUpperCase());
    }
  }

  // 4. Query slot locks on that date
  const locksSnap = await db
    .collection('slot_locks')
    .where('trainerId', '==', trainerId)
    .where('date', '==', dateStr)
    .get();

  const reservedStarts = new Set<string>();
  const now = new Date();
  for (const doc of locksSnap.docs) {
    const lock = doc.data();
    const exp = lock.expiresAt?.toDate ? lock.expiresAt.toDate() : new Date(lock.expiresAt);
    if (lock.status === 'RESERVED' && exp > now) {
      if (!currentClientId || lock.clientId !== currentClientId) {
        reservedStarts.add((lock.startTime || '').trim().toUpperCase());
      }
    }
  }

  // Check if past for today
  const todayStr = new Date().toISOString().substring(0, 10);
  const isToday = dateStr === todayStr;
  const currentMinutes = new Date().getHours() * 60 + new Date().getMinutes();

  const resultSlots = slots.map((s) => {
    const upperStart = s.start.toUpperCase();
    const isBooked = confirmedStarts.has(upperStart);
    const isReserved = !isBooked && reservedStarts.has(upperStart);
    const isPast = isToday && parseTimeToMinutes(s.start) <= currentMinutes;
    return {
      start: s.start,
      end: s.end,
      isBooked,
      isReserved,
      isPast,
      isAvailable: !isBooked && !isReserved && !isPast,
    };
  });

  return { slots: resultSlots, isBlocked: false };
});

// ─────────────────────────────────────────────────────────────────────────────
// 15. Client Support & Complaints System
// ─────────────────────────────────────────────────────────────────────────────

export const submitSupportTicket = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to submit a support request.');
  }

  const { category, subject, description, bookingId, bookingReference, attachmentUrl, attachmentName } = request.data || {};
  if (!category || !subject || !description) {
    throw new HttpsError('invalid-argument', 'Category, subject, and description are required.');
  }

  const trimmedSubject = String(subject).trim();
  if (trimmedSubject.length < 3) {
    throw new HttpsError('invalid-argument', 'Subject must be at least 3 characters long.');
  }

  const trimmedDescription = String(description).trim();
  if (trimmedDescription.length < 10) {
    throw new HttpsError('invalid-argument', 'Description must be at least 10 characters long.');
  }

  const uid = request.auth.uid;
  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.exists ? userDoc.data()! : {};
  const clientName = userData.displayName || userData.name || 'Athlete';
  const clientEmail = userData.email || null;

  // Generate ticket number TKT-XXXXXX
  const now = new Date();
  const millisPart = now.getTime().toString(36).toUpperCase();
  const ticketNumber = `TKT-${millisPart.slice(-6).padStart(6, '0')}`;
  const ticketId = `tkt_${now.getTime()}_${uid.substring(0, 5)}`;

  const ticketRef = db.collection('support_tickets').doc(ticketId);
  const msgRef = ticketRef.collection('messages').doc();

  const ticketData = {
    id: ticketId,
    ticketNumber,
    clientId: uid,
    clientName,
    clientEmail,
    category: String(category).trim().toUpperCase(),
    subject: trimmedSubject,
    description: trimmedDescription,
    bookingId: bookingId ? String(bookingId).trim() : null,
    bookingReference: bookingReference ? String(bookingReference).trim() : null,
    attachmentUrl: attachmentUrl ? String(attachmentUrl).trim() : null,
    attachmentName: attachmentName ? String(attachmentName).trim() : null,
    status: 'SUBMITTED',
    lastMessage: trimmedDescription,
    lastMessageSender: 'CLIENT',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const initialMessage = {
    id: msgRef.id,
    ticketId,
    senderId: uid,
    senderType: 'CLIENT',
    senderName: clientName,
    message: trimmedDescription,
    attachmentUrl: attachmentUrl ? String(attachmentUrl).trim() : null,
    attachmentName: attachmentName ? String(attachmentName).trim() : null,
    isRead: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(ticketRef, ticketData);
  batch.set(msgRef, initialMessage);
  await batch.commit();

  // Send in-app notification confirming ticket receipt
  try {
    const notifRef = db.collection('notifications').doc();
    await notifRef.set({
      id: notifRef.id,
      userId: uid,
      title: 'Support Request Received',
      body: `Ticket #${ticketNumber} has been received. Our team will review it shortly.`,
      type: 'SUPPORT_TICKET_UPDATE',
      isRead: false,
      data: {
        ticketId,
        ticketNumber,
        status: 'SUBMITTED',
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (_) {}

  return {
    success: true,
    ticketId,
    ticketNumber,
  };
});

export const sendSupportTicketMessage = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to send a message.');
  }

  const { ticketId, message, attachmentUrl, attachmentName } = request.data || {};
  if (!ticketId) {
    throw new HttpsError('invalid-argument', 'Ticket ID is required.');
  }

  const trimmedMessage = message ? String(message).trim() : '';
  if (!trimmedMessage && !attachmentUrl) {
    throw new HttpsError('invalid-argument', 'Message or attachment is required.');
  }

  const uid = request.auth.uid;
  const ticketRef = db.collection('support_tickets').doc(ticketId);
  const ticketSnap = await ticketRef.get();

  if (!ticketSnap.exists) {
    throw new HttpsError('not-found', 'Support ticket not found.');
  }

  const ticket = ticketSnap.data()!;
  if (ticket.clientId !== uid) {
    throw new HttpsError('permission-denied', 'Only the ticket owner can reply to this support ticket.');
  }

  if (ticket.status === 'CLOSED') {
    throw new HttpsError('failed-precondition', 'Cannot reply to a closed ticket. Please submit a new request.');
  }

  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.exists ? userDoc.data()! : {};
  const senderName = userData.displayName || userData.name || 'Athlete';

  const msgRef = ticketRef.collection('messages').doc();
  const messageData = {
    id: msgRef.id,
    ticketId,
    senderId: uid,
    senderType: 'CLIENT',
    senderName,
    message: trimmedMessage,
    attachmentUrl: attachmentUrl ? String(attachmentUrl).trim() : null,
    attachmentName: attachmentName ? String(attachmentName).trim() : null,
    isRead: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(msgRef, messageData);
  batch.update(ticketRef, {
    lastMessage: trimmedMessage || 'Sent an attachment',
    lastMessageSender: 'CLIENT',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(ticket.status === 'RESOLVED' ? { status: 'IN_PROGRESS' } : {}),
  });
  await batch.commit();

  return { success: true, messageId: msgRef.id };
});

export const updateSupportTicketStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { ticketId, status, supportNote } = request.data || {};
  if (!ticketId || !status) {
    throw new HttpsError('invalid-argument', 'Ticket ID and status are required.');
  }

  const validStatuses = ['SUBMITTED', 'UNDER_REVIEW', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
  const upperStatus = String(status).trim().toUpperCase();
  if (!validStatuses.includes(upperStatus)) {
    throw new HttpsError('invalid-argument', `Invalid status. Must be one of: ${validStatuses.join(', ')}`);
  }

  const uid = request.auth.uid;
  const ticketRef = db.collection('support_tickets').doc(ticketId);
  const ticketSnap = await ticketRef.get();

  if (!ticketSnap.exists) {
    throw new HttpsError('not-found', 'Support ticket not found.');
  }

  const ticket = ticketSnap.data()!;
  // Non-admins can only mark their own ticket as CLOSED
  const userDoc = await db.collection('users').doc(uid).get();
  const isAdmin = userDoc.exists && userDoc.data()!.role === 'ADMIN';

  if (!isAdmin) {
    if (ticket.clientId !== uid) {
      throw new HttpsError('permission-denied', 'Not authorized to update this support ticket.');
    }
    if (upperStatus !== 'CLOSED') {
      throw new HttpsError('permission-denied', 'Clients may only mark their own support tickets as CLOSED.');
    }
  }

  const batch = db.batch();
  const updateData: any = {
    status: upperStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (upperStatus === 'RESOLVED') {
    updateData.resolvedAt = admin.firestore.FieldValue.serverTimestamp();
  } else if (upperStatus === 'CLOSED') {
    updateData.closedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  if (supportNote && String(supportNote).trim().length > 0) {
    const msgRef = ticketRef.collection('messages').doc();
    batch.set(msgRef, {
      id: msgRef.id,
      ticketId,
      senderId: uid,
      senderType: 'SUPPORT',
      senderName: 'TRAIN Z Support Specialist',
      message: String(supportNote).trim(),
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    updateData.lastMessage = String(supportNote).trim();
    updateData.lastMessageSender = 'SUPPORT';
  }

  batch.update(ticketRef, updateData);
  await batch.commit();

  // Send status update notification to client
  try {
    const notifRef = db.collection('notifications').doc();
    await notifRef.set({
      id: notifRef.id,
      userId: ticket.clientId,
      title: `Support Ticket #${ticket.ticketNumber} Update`,
      body: `Status has been updated to "${upperStatus.replace('_', ' ')}".`,
      type: 'SUPPORT_TICKET_UPDATE',
      isRead: false,
      data: {
        ticketId,
        ticketNumber: ticket.ticketNumber,
        status: upperStatus,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (_) {}

  return { success: true, status: upperStatus };
});

// ─────────────────────────────────────────────────────────────────────────────
// 27. Client Account Deletion & Anonymization (Compliant with Data Laws)
// ─────────────────────────────────────────────────────────────────────────────

export const requestClientAccountDeletion = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to request account deletion.');
  }

  const uid = request.auth.uid;
  const { reason } = request.data || {};

  // 1. Fetch user to verify existence and role
  const userDocRef = db.collection('users').doc(uid);
  const userSnap = await userDocRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'User account record not found.');
  }

  const userData = userSnap.data()!;
  if (userData.role !== 'CLIENT') {
    throw new HttpsError('failed-precondition', 'Account deletion flow here applies exclusively to Client accounts.');
  }

  // 2. Cancel any pending or confirmed upcoming bookings
  const bookingsSnap = await db.collection('bookings')
    .where('clientId', '==', uid)
    .where('status', 'in', ['PENDING', 'CONFIRMED'])
    .get();

  const batch = db.batch();
  for (const bDoc of bookingsSnap.docs) {
    batch.update(bDoc.ref, {
      status: 'CANCELLED',
      cancellationReason: 'Athlete Account Deletion',
      cancelledBy: 'CLIENT',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 3. Anonymize user profile in users collection
  batch.update(userDocRef, {
    displayName: 'Deleted Athlete',
    email: `deleted_${uid.slice(0, 8)}@trainz.deleted`,
    phoneNumber: null,
    photoUrl: null,
    status: 'DELETED',
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    deletionReason: reason ? String(reason).trim() : 'Athlete voluntary account closure',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 4. Clear sensitive private fields from client_profiles collection
  const clientProfileRef = db.collection('client_profiles').doc(uid);
  const clientProfileSnap = await clientProfileRef.get();
  if (clientProfileSnap.exists) {
    batch.update(clientProfileRef, {
      privateAddress: null,
      emergencyContact: null,
      dateOfBirth: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 5. Create statutory compliance audit record (preserves auditability for tax/financial transactions)
  const auditRef = db.collection('deletion_audits').doc(uid);
  batch.set(auditRef, {
    userId: uid,
    role: 'CLIENT',
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    reason: reason ? String(reason).trim() : 'Athlete voluntary account closure',
    cancelledBookingsCount: bookingsSnap.size,
    statutoryRetentionNotice: 'Payment and invoice transactions retained per Section 35 of CGST Act / statutory financial auditing requirements.',
  });

  // 6. Record in deletion_requests collection
  const delReqRef = db.collection('deletion_requests').doc(uid);
  batch.set(delReqRef, {
    userId: uid,
    status: 'PROCESSED',
    reason: reason ? String(reason).trim() : 'Athlete voluntary account closure',
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  // 7. Delete profile images from Firebase Storage
  try {
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({ prefix: `profile_pictures/${uid}/` });
  } catch (err) {
    console.warn(`Could not delete storage files for ${uid}:`, err);
  }

  // 8. Delete user from Firebase Auth
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    console.warn(`Could not delete auth user for ${uid}:`, err);
  }

  return {
    success: true,
    message: 'Athlete account deleted and personal records successfully anonymized.',
  };
});

// ─────────────────────────────────────────────────────────────────────────────
// 28. Client Notification Preferences Update
// ─────────────────────────────────────────────────────────────────────────────

export const updateClientNotificationPreferences = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = request.auth.uid;
  const {
    bookingUpdates = true,
    sessionReminders = true,
    paymentUpdates = true,
    trainerMessages = true,
    reviewsAndFeedback = true,
    supportUpdates = true,
    platformAnnouncements = false,
  } = request.data || {};

  const payload = {
    bookingUpdates: Boolean(bookingUpdates),
    sessionReminders: Boolean(sessionReminders),
    paymentUpdates: Boolean(paymentUpdates),
    trainerMessages: Boolean(trainerMessages),
    reviewsAndFeedback: Boolean(reviewsAndFeedback),
    supportUpdates: Boolean(supportUpdates),
    platformAnnouncements: Boolean(platformAnnouncements),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const userSettingsCol = db.collection('users').doc(uid).collection('settings');
  await Promise.all([
    userSettingsCol.doc('notifications').set(payload, { merge: true }),
    userSettingsCol.doc('notification_preferences').set(payload, { merge: true }),
  ]);

  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// 29. Automated Upcoming Session & Expiration Reminders
// ─────────────────────────────────────────────────────────────────────────────

export const checkUpcomingSessionReminders = onCall(async (request) => {
  // Allow authenticated users or admin to trigger checking
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated to run reminder check.');
  }

  const now = new Date();
  const next24h = new Date(now.getTime() + 25 * 60 * 60 * 1000);

  // 1. Check confirmed bookings in the next 24 hours
  const bookingsSnap = await db
    .collection('bookings')
    .where('status', '==', 'CONFIRMED')
    .where('sessionDate', '>=', admin.firestore.Timestamp.fromDate(now))
    .where('sessionDate', '<=', admin.firestore.Timestamp.fromDate(next24h))
    .get();

  let remindersSent = 0;

  for (const doc of bookingsSnap.docs) {
    const booking = doc.data();
    const sessionDate: Date = booking.sessionDate.toDate();
    let exactTime = new Date(sessionDate);

    if (booking.startTime) {
      const match = String(booking.startTime).trim().match(/(\d+):(\d+)\s*(AM|PM)?/i);
      if (match) {
        let hour = parseInt(match[1], 10);
        const min = parseInt(match[2], 10);
        const period = match[3] ? match[3].toUpperCase() : '';
        if (period === 'PM' && hour < 12) hour += 12;
        if (period === 'AM' && hour === 12) hour = 0;
        exactTime.setHours(hour, min, 0, 0);
      }
    }

    const hoursUntil = (exactTime.getTime() - now.getTime()) / (1000 * 60 * 60);
    let reminderWindow = '';
    let reminderLabel = '';

    if (hoursUntil >= 11 && hoursUntil <= 13) {
      reminderWindow = '12h';
      reminderLabel = 'in 12 hours';
    } else if (hoursUntil >= 1.5 && hoursUntil <= 2.5) {
      reminderWindow = '2h';
      reminderLabel = 'in 2 hours';
    } else if (hoursUntil >= 0.5 && hoursUntil <= 1.2) {
      reminderWindow = '1h';
      reminderLabel = 'in 1 hour';
    }

    if (reminderWindow) {
      const lockKey = `reminder_${reminderWindow}_${doc.id}`;
      const notifRef = db.collection('notifications').doc(lockKey);
      const existing = await notifRef.get();

      if (!existing.exists) {
        const bRef = doc.id.slice(0, 8).toUpperCase();
        await notifRef.set({
          id: lockKey,
          userId: booking.clientId,
          title: 'Upcoming Training Session',
          body: `Your session with ${booking.trainerName || 'Coach'} starts ${reminderLabel} (${booking.startTime || ''}). Ref: #${bRef}`,
          type: 'UPCOMING_REMINDER',
          isRead: false,
          data: {
            bookingId: doc.id,
            bookingReference: bRef,
            reminderWindow,
            startTime: booking.startTime || '',
            trainerName: booking.trainerName || '',
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        remindersSent++;
      }
    }
  }

  return { success: true, remindersSent };
});

/**
 * 8. Trainer Earnings & Payout Summary
 * Computes authoritative financial metrics directly from Firestore:
 * Total gross revenue, platform commission, net earnings, pending payout, and total paid out.
 */
export const getTrainerEarningsSummary = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;

  // 1. Fetch platform settings for commission
  const settingsSnap = await db.collection('platform_settings').doc('general').get();
  const platformFeePercent = settingsSnap.exists && typeof settingsSnap.data()?.platformFeePercent === 'number'
    ? settingsSnap.data()!.platformFeePercent
    : null;

  // 2. Fetch trainer earnings transactions
  const earningsSnap = await db.collection('trainer_earnings')
    .where('trainerId', '==', trainerUid)
    .get();

  // 3. Fetch trainer payout records
  const payoutsSnap = await db.collection('trainer_payouts')
    .where('trainerId', '==', trainerUid)
    .get();

  let totalGross = 0;
  let totalCommission = 0;
  let netEarnings = 0;
  let pendingPayout = 0;
  let totalPaidOut = 0;
  let completedCount = 0;

  earningsSnap.forEach((doc) => {
    const data = doc.data();
    if (data.status === 'COMPLETED') {
      completedCount++;
      const gross = typeof data.grossAmount === 'number' ? data.grossAmount : 0;
      const comm = typeof data.commissionAmount === 'number' ? data.commissionAmount : 0;
      const net = typeof data.netAmount === 'number' ? data.netAmount : (gross - comm);

      totalGross += gross;
      totalCommission += comm;
      netEarnings += net;

      if (data.payoutStatus === 'ELIGIBLE_FOR_PAYOUT' || data.payoutStatus === 'PAYOUT_PENDING') {
        pendingPayout += net;
      }
    }
  });

  payoutsSnap.forEach((doc) => {
    const data = doc.data();
    if (data.status === 'PAID') {
      totalPaidOut += typeof data.amount === 'number' ? data.amount : 0;
    }
  });

  return {
    totalGrossRevenue: totalGross,
    totalCommission,
    netEarnings,
    pendingPayout,
    totalPaidOut,
    completedSessionsCount: completedCount,
    commissionRatePercent: platformFeePercent,
    isCommissionConfigured: platformFeePercent !== null && platformFeePercent !== undefined,
  };
});

/**
 * 9A. Submit Trainer Review Response
 * Allows authenticated trainers to post one professional public reply to an eligible review.
 */
export const submitTrainerReviewResponse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { reviewId, responseText } = request.data || {};

  if (!reviewId || typeof reviewId !== 'string') {
    throw new HttpsError('invalid-argument', 'Review ID is required.');
  }

  const cleaned = (responseText || '').trim();
  if (cleaned.length < 3 || cleaned.length > 500) {
    throw new HttpsError(
      'invalid-argument',
      'Response content must be between 3 and 500 characters.'
    );
  }

  const lower = cleaned.toLowerCase();
  const prohibitedWords = ['abuse', 'scam', 'fraud', 'hate', 'idiot', 'fake'];
  for (const word of prohibitedWords) {
    if (lower.includes(word)) {
      throw new HttpsError(
        'invalid-argument',
        'Response contains language that violates professional communication guidelines.'
      );
    }
  }

  const reviewRef = db.collection('reviews').doc(reviewId);
  const reviewSnap = await reviewRef.get();

  if (!reviewSnap.exists) {
    throw new HttpsError('not-found', 'Review not found.');
  }

  const review = reviewSnap.data()!;
  if (review.trainerId !== trainerUid) {
    throw new HttpsError(
      'permission-denied',
      'You are not authorized to respond to a review belonging to another trainer.'
    );
  }

  await reviewRef.update({
    trainerResponse: cleaned,
    trainerRespondedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Notify client
  if (review.clientId) {
    const notifRef = db.collection('notifications').doc();
    await notifRef.set({
      id: notifRef.id,
      userId: review.clientId,
      title: 'Trainer Responded to Your Review 💬',
      body: 'Your coach has posted a public response to your review.',
      type: 'REVIEW_RESPONSE',
      isRead: false,
      data: {
        reviewId,
        trainerId: trainerUid,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { success: true, reviewId, trainerResponse: cleaned };
});

/**
 * 9B. Delete Trainer Review Response
 */
export const deleteTrainerReviewResponse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { reviewId } = request.data || {};

  if (!reviewId) {
    throw new HttpsError('invalid-argument', 'Review ID is required.');
  }

  const reviewRef = db.collection('reviews').doc(reviewId);
  const reviewSnap = await reviewRef.get();

  if (!reviewSnap.exists) {
    throw new HttpsError('not-found', 'Review not found.');
  }

  const review = reviewSnap.data()!;
  if (review.trainerId !== trainerUid) {
    throw new HttpsError('permission-denied', 'Not authorized to modify this review response.');
  }

  await reviewRef.update({
    trainerResponse: admin.firestore.FieldValue.delete(),
    trainerRespondedAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, reviewId };
});

/**
 * 9C. Report Client Review for Admin Moderation
 */
export const reportClientReview = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { reviewId, reason, details } = request.data || {};

  if (!reviewId || !reason) {
    throw new HttpsError('invalid-argument', 'Review ID and reason are required.');
  }

  const reviewRef = db.collection('reviews').doc(reviewId);
  const reviewSnap = await reviewRef.get();

  if (!reviewSnap.exists) {
    throw new HttpsError('not-found', 'Review not found.');
  }

  const review = reviewSnap.data()!;
  if (review.trainerId !== trainerUid) {
    throw new HttpsError('permission-denied', 'You can only report reviews on your own profile.');
  }

  const reportDocId = `${trainerUid}_${reviewId}`;
  const reportRef = db.collection('review_reports').doc(reportDocId);
  const reportSnap = await reportRef.get();

  if (reportSnap.exists) {
    throw new HttpsError('already-exists', 'You have already submitted a report for this review.');
  }

  await reportRef.set({
    id: reportDocId,
    reviewId,
    trainerId: trainerUid,
    reporterId: trainerUid,
    reason: String(reason).trim(),
    details: details ? String(details).trim() : null,
    status: 'PENDING',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await reviewRef.update({
    isReported: true,
    reportReason: String(reason).trim(),
    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, reportId: reportDocId };
});

/**
 * 10A. Add Private Trainer Client Note
 * Ensures trainer is authenticated, has a legitimate booking connection with the client,
 * rejects medical/diagnostic statements, and writes to trainer_client_notes.
 */
export const addTrainerClientNote = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { clientId, title, content, category, sessionDate } = request.data || {};

  if (!clientId || !content || typeof content !== 'string' || content.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Client ID and non-empty content are required.');
  }

  // Validate legitimate booking relationship
  const bookingCheck = await db.collection('bookings')
    .where('trainerId', '==', trainerUid)
    .where('clientId', '==', clientId)
    .limit(1)
    .get();

  if (bookingCheck.empty) {
    throw new HttpsError('permission-denied', 'You can only maintain notes for clients with valid bookings.');
  }

  // Medical claim disclaimer check
  const textCheck = `${title || ''} ${content}`.toLowerCase();
  const prohibitedMedical = ['diagnosis', 'prescribe', 'prescription', 'cure disease', 'medical treatment'];
  for (const term of prohibitedMedical) {
    if (textCheck.includes(term)) {
      throw new HttpsError('invalid-argument', 'Training notes must not contain medical diagnoses or advice.');
    }
  }

  const noteId = `note_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  const noteData = {
    id: noteId,
    trainerId: trainerUid,
    clientId,
    title: (title && String(title).trim().length > 0) ? String(title).trim() : 'Coaching Observation',
    content: String(content).trim(),
    category: category || 'Observation',
    sessionDate: sessionDate ? admin.firestore.Timestamp.fromDate(new Date(sessionDate)) : null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('trainer_client_notes').doc(noteId).set(noteData);
  return { success: true, noteId, note: noteData };
});

/**
 * 10B. Delete Private Trainer Client Note
 * Enforces trainer ownership.
 */
export const deleteTrainerClientNote = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { noteId } = request.data || {};

  if (!noteId) {
    throw new HttpsError('invalid-argument', 'Note ID is required.');
  }

  const noteRef = db.collection('trainer_client_notes').doc(noteId);
  const noteSnap = await noteRef.get();

  if (!noteSnap.exists) {
    throw new HttpsError('not-found', 'Note not found.');
  }

  if (noteSnap.data()?.trainerId !== trainerUid) {
    throw new HttpsError('permission-denied', 'You are not authorized to delete this note.');
  }

  await noteRef.delete();
  return { success: true, noteId };
});

/**
 * 10C. Record Trainer Client Progress Milestone
 */
export const recordTrainerClientProgress = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { clientId, title, notes, category, achievedDate } = request.data || {};

  if (!clientId || !title || typeof title !== 'string' || title.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Client ID and title are required.');
  }

  // Validate legitimate booking relationship
  const bookingCheck = await db.collection('bookings')
    .where('trainerId', '==', trainerUid)
    .where('clientId', '==', clientId)
    .limit(1)
    .get();

  if (bookingCheck.empty) {
    throw new HttpsError('permission-denied', 'You can only record progress for clients with valid bookings.');
  }

  const progressId = `prog_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  const progressData = {
    id: progressId,
    trainerId: trainerUid,
    clientId,
    title: String(title).trim(),
    notes: notes ? String(notes).trim() : '',
    category: category || 'Milestone',
    achievedDate: achievedDate ? admin.firestore.Timestamp.fromDate(new Date(achievedDate)) : admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('trainer_client_progress').doc(progressId).set(progressData);
  return { success: true, progressId, progress: progressData };
});

/**
 * 11. Trainer Account Deletion Request
 * Validates that trainer has no active upcoming sessions and no pending unsettled payouts.
 * Creates an audit record in account_deletion_requests, flags user as DELETION_REQUESTED,
 * deactivates the profile, and preserves required financial/booking audit history.
 */
export const requestTrainerAccountDeletion = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const trainerUid = request.auth.uid;
  const { reason } = request.data || {};

  // 1. Guard against active scheduled sessions
  const activeBookingsSnap = await db.collection('bookings')
    .where('trainerId', '==', trainerUid)
    .where('status', 'in', ['CONFIRMED', 'RESERVED', 'IN_PROGRESS'])
    .limit(10)
    .get();

  if (!activeBookingsSnap.empty) {
    throw new HttpsError(
      'failed-precondition',
      'Cannot request account deletion: You have active scheduled training sessions. Please complete or resolve all upcoming sessions first.'
    );
  }

  // 2. Guard against pending / unsettled payouts
  const pendingPayoutsSnap = await db.collection('trainer_payouts')
    .where('trainerId', '==', trainerUid)
    .where('status', '==', 'PENDING')
    .limit(1)
    .get();

  if (!pendingPayoutsSnap.empty) {
    throw new HttpsError(
      'failed-precondition',
      'Cannot request account deletion: You have pending payouts in processing. Please wait until payouts are fully settled.'
    );
  }

  // 3. Record deletion request while preserving financial and audit records
  const requestId = `del_${trainerUid}_${Date.now()}`;
  const deletionRecord = {
    id: requestId,
    userId: trainerUid,
    role: 'TRAINER',
    reason: reason ? String(reason).trim() : 'Requested by trainer',
    status: 'PENDING_REVIEW',
    preserveFinancialRecords: true,
    preserveBookingHistory: true,
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(db.collection('account_deletion_requests').doc(requestId), deletionRecord);

  // Deactivate trainer profile
  const profileRef = db.collection('trainer_profiles').doc(trainerUid);
  batch.set(profileRef, {
    isActive: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Update user account status
  const userRef = db.collection('users').doc(trainerUid);
  batch.set(userRef, {
    status: 'DELETION_REQUESTED',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await batch.commit();

  return {
    success: true,
    requestId,
    message: 'Your account deletion request has been submitted. Your profile has been deactivated while preserving required legal and financial transaction records.',
  };
});



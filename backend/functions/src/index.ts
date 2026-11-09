import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

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

    transaction.update(bookingRef, {
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { bookingId, status: newStatus, returnedCredit };
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

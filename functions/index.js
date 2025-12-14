const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

/**
 * Automatically recalculates the shopping cart totals whenever an item is added, updated, or removed.
 *
 * Trigger: Firestore Write on `carts/{cartId}/items/{itemId}`.
 *
 * This function ensures that the client cannot tamper with the total price by
 * forcing a server-side recalculation based on the individual items currently in the database.
 */
exports.calculateCartTotal = functions.firestore
  .document("carts/{cartId}/items/{itemId}")
  .onWrite(async (change, context) => {
    const cartId = context.params.cartId;
    const cartRef = db.collection("carts").doc(cartId);
    const itemsRef = cartRef.collection("items");

    try {
      // We fetch all items to recalculate from scratch.
      // This prevents "drift" where the total might eventually mismatch the items due to
      // network errors or concurrent writes if we tried to increment/decrement instead.
      const itemsSnapshot = await itemsRef.get();
      let newTotalPrice = 0;
      let newItemCount = 0;

      itemsSnapshot.forEach((doc) => {
        const d = doc.data();
        // Use fallbacks (0) to prevent NaN errors if data is corrupted or missing during a write.
        const p = typeof d.productPrice === 'number' ? d.productPrice : 0;
        const q = typeof d.quantity === 'number' ? d.quantity : 0;
        newTotalPrice += p * q;
        newItemCount += q;
      });

      // We need the parent cart document to check for active gift cards.
      const cartDoc = await cartRef.get();
      const cartData = cartDoc.data() || {};
      
      let finalAmount = newTotalPrice;
      const giftAmt = (typeof cartData.giftCardAppliedAmount === 'number') ? cartData.giftCardAppliedAmount : 0;
      
      // If a gift card is active, we must re-apply the logic here to ensure
      // the final amount doesn't go below zero if the cart total dropped.
      if (cartData.appliedGiftCardCode && giftAmt > 0) {
          finalAmount = Math.max(0, newTotalPrice - giftAmt);
      }

      // Merge true is used to update totals without overwriting other fields like 'ownerUID'.
      await cartRef.set({
          totalPrice: newTotalPrice,
          itemCount: newItemCount,
          finalAmountToPay: finalAmount,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return null;
    } catch (e) { console.error(e); return null; }
  });

/**
 * Validates and applies a gift card code to a specific cart.
 *
 * This is an HTTPS Callable function because it requires complex validation logic
 * (expiry, balance check, already applied check) that is difficult to secure
 * using only Firestore Security Rules.
 *
 * @param {Object} data - The request payload containing `giftCardCode` and `cartId`.
 * @param {Object} context - The context containing auth information.
 * @returns {Promise<Object>} A success object if the operation completes.
 */
exports.applyGiftCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  const { giftCardCode, cartId } = data;
  const userId = context.auth.uid;

  if (!giftCardCode || !cartId || cartId !== userId) throw new functions.https.HttpsError("invalid-argument", "Invalid data.");

  const giftRef = db.collection("giftCards").doc(giftCardCode);
  const cartRef = db.collection("carts").doc(cartId);

  // Use a transaction to prevent race conditions.
  // Example: Two users trying to use the same gift card simultaneously,
  // or one user trying to double-apply a card before the balance updates.
  return db.runTransaction(async (t) => {
    const gDoc = await t.get(giftRef);
    const cDoc = await t.get(cartRef);

    if (!gDoc.exists) throw new functions.https.HttpsError("not-found", "Card not found.");
    const gData = gDoc.data();
    
    // Business logic validation: Ensure card is valid and has funds.
    if (!gData.isActive || gData.balance <= 0) throw new functions.https.HttpsError("failed-precondition", "Card invalid.");

    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart not found.");
    const cData = cDoc.data();
    
    // Enforce "one card per order" rule.
    if (cData.appliedGiftCardCode) throw new functions.https.HttpsError("failed-precondition", "Card already applied.");

    const total = cData.totalPrice || 0;
    // Cap the deduction at the total price so we don't end up with negative payment amounts.
    const amount = Math.min(gData.balance, total);
    
    if (amount <= 0) throw new functions.https.HttpsError("failed-precondition", "Nothing to apply.");

    // Atomically reduce gift card balance and update cart totals.
    t.update(giftRef, { balance: gData.balance - amount });
    t.update(cartRef, {
      giftCardAppliedAmount: amount,
      appliedGiftCardCode: giftCardCode,
      finalAmountToPay: total - amount,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

/**
 * Removes an applied gift card from a cart and refunds the balance to the card.
 *
 * @param {Object} data - The request payload containing `cartId`.
 * @param {Object} context - The context containing auth information.
 * @returns {Promise<Object>} A success object if the operation completes.
 */
exports.removeGiftCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  const cartId = data.cartId;
  const cartRef = db.collection("carts").doc(cartId);

  return db.runTransaction(async (t) => {
    const cDoc = await t.get(cartRef);
    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart not found.");
    
    const cData = cDoc.data();
    const code = cData.appliedGiftCardCode;
    const amt = cData.giftCardAppliedAmount || 0;

    // Fail gracefully if no card is actually applied.
    if (!code) return { message: "No card." };

    const gRef = db.collection("giftCards").doc(code);
    const gDoc = await t.get(gRef);
    
    // We check existence because the gift card document might have been deleted
    // by an admin. If so, we still want to clear the cart state.
    if (gDoc.exists) {
      t.update(gRef, { balance: gDoc.data().balance + amt });
    }

    // Reset cart fields using FieldValue.delete() to keep the document clean.
    t.update(cartRef, {
      giftCardAppliedAmount: admin.firestore.FieldValue.delete(),
      appliedGiftCardCode: admin.firestore.FieldValue.delete(),
      finalAmountToPay: cData.totalPrice || 0,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

/**
 * Finalizes the checkout process.
 *
 * This function performs the following critical steps atomically:
 * 1. Creates a permanent Order record.
 * 2. Clears the user's shopping cart.
 * 3. Triggers a confirmation email via the 'mail' collection.
 *
 * @param {Object} data - The request payload containing optional `email`.
 * @param {Object} context - The context containing auth information.
 * @returns {Promise<Object>} The `orderId` and success status.
 */
exports.completeOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  const userId = context.auth.uid;
  const cartId = userId;

  let email = data.email || context.auth.token?.email;
  if (typeof email === 'string') email = email.trim();
  if (!email) throw new functions.https.HttpsError("invalid-argument", "Email required.");

  const userRef = db.collection("users").doc(userId);
  const cartRef = db.collection("carts").doc(cartId);
  const itemsRef = cartRef.collection("items");

  // Transaction is mandatory here to ensure we don't create an order
  // without successfully clearing the cart (avoiding double orders).
  return db.runTransaction(async (t) => {
    const cDoc = await t.get(cartRef);
    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart empty.");
    
    const iSnaps = await t.get(itemsRef);
    if (iSnaps.empty) throw new functions.https.HttpsError("failed-precondition", "Cart empty.");

    const uDoc = await t.get(userRef);
    const uData = uDoc.exists ? uDoc.data() : {};
    const cData = cDoc.data();

    // Sanitize address data to ensure we don't pass 'undefined' to Firestore,
    // which would cause the entire transaction to throw an exception.
    const address = {
        name: uData.name || '',
        surname: uData.surname || '',
        address: uData.address || '',
        city: uData.city || '',
        postcode: uData.postcode || ''
    };

    // Reconstruct the items list explicitly.
    // This sanitization step prevents "undefined value" errors if legacy data
    // in the cart is missing new fields like 'productName'.
    const items = [];
    iSnaps.forEach(d => {
        const val = d.data();
        items.push({
            productId: val.productId || null,
            productName: val.productName || 'Unknown',
            productPrice: (typeof val.productPrice==='number')?val.productPrice:0,
            quantity: (typeof val.quantity==='number')?val.quantity:1,
            imageUrl: val.imageUrl || null
        });
    });

    const finalAmount = (typeof cData.finalAmountToPay==='number')?cData.finalAmountToPay:(cData.totalPrice||0);
    const orderId = `${userId}_${Date.now()}`;
    const orderRef = db.collection("orders").doc(orderId);

    // 1. Create the Order
    t.set(orderRef, {
      orderId: orderId,
      userId: userId,
      items: items,
      totalPrice: cData.totalPrice || 0,
      giftCardAppliedAmount: cData.giftCardAppliedAmount || 0,
      finalAmountPaid: finalAmount,
      appliedGiftCardCode: cData.appliedGiftCardCode || null,
      shippingAddress: address,
      status: "completed",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Clear Cart Items
    // We delete sub-collection items individually since Firestore doesn't support recursive delete in transactions.
    iSnaps.forEach(d => t.delete(d.ref));
    
    // 3. Reset Cart Metadata
    t.update(cartRef, {
        totalPrice: 0, 
        itemCount: 0,
        giftCardAppliedAmount: admin.firestore.FieldValue.delete(),
        appliedGiftCardCode: admin.firestore.FieldValue.delete(),
        finalAmountToPay: 0,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    // 4. Trigger Email
    // We write to the 'mail' collection to trigger the "Trigger Email" Firebase Extension.
    // This is done inside the transaction so the email is only queued if the order actually succeeds.
    if (email) {
        const rows = items.map(i => `<tr><td>${i.productName}</td><td>${i.quantity}</td><td>€${i.productPrice.toFixed(2)}</td></tr>`).join('');
        const html = `<h2>Order #${orderId}</h2>
                      <table border="1" style="border-collapse:collapse;width:100%">
                        <tr><th>Item</th><th>Qty</th><th>Price</th></tr>${rows}
                      </table>
                      <h3>Total: €${finalAmount.toFixed(2)}</h3>
                      <p>Ship to: ${address.address}, ${address.city}</p>`;
        
        const mailRef = db.collection("mail").doc();
        t.set(mailRef, { to: email, message: { subject: `Order #${orderId}`, html: html } });
    }

    return { orderId: orderId, success: true };
  });
});
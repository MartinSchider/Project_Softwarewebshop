const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

// 1. Cloud Function to automatically calculate cart total and item count
//    Triggered whenever an item is added, removed, or updated in a user's cart subcollection.
exports.calculateCartTotal = functions.firestore
  .document("carts/{cartId}/items/{itemId}")
  .onWrite(async (change, context) => {
    const cartId = context.params.cartId;
    const cartRef = db.collection("carts").doc(cartId);
    const itemsRef = cartRef.collection("items");

    try {
      const itemsSnapshot = await itemsRef.get();
      let newTotalPrice = 0;
      let newItemCount = 0;

      // Calculate total price and item count from all items in the subcollection
      itemsSnapshot.forEach((doc) => {
        const itemData = doc.data();
        const productPrice = typeof itemData.productPrice === 'number' ? itemData.productPrice : 0;
        const quantity = typeof itemData.quantity === 'number' ? itemData.quantity : 0;
        newTotalPrice += productPrice * quantity;
        newItemCount += quantity;
      });

      // Get the current cart document to check for applied gift card
      const cartDoc = await cartRef.get();
      const cartData = cartDoc.data() || {};

      let finalAmountToPay = newTotalPrice;
      let giftCardAppliedAmount = (typeof cartData.giftCardAppliedAmount === 'number') ? cartData.giftCardAppliedAmount : 0;
      let appliedGiftCardCode = cartData.appliedGiftCardCode;


      // If a gift card was applied previously, re-calculate the final amount
      // The finalAmountToPay should be the totalPrice MINUS the giftCardAppliedAmount
      if (appliedGiftCardCode && giftCardAppliedAmount > 0) {
          finalAmountToPay = Math.max(0, newTotalPrice - giftCardAppliedAmount);
      } else {
          // If no gift card applied, final amount is just the total price
          finalAmountToPay = newTotalPrice;
      }

      // Update the main cart document
      await cartRef.set(
        {
          totalPrice: newTotalPrice,
          itemCount: newItemCount,
          finalAmountToPay: finalAmountToPay, // Update final amount
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      console.log(`Cart ${cartId} total recalculated: ${newTotalPrice}, items: ${newItemCount}, finalAmount: ${finalAmountToPay}`);
      return null;
    } catch (error) {
      console.error("Error calculating cart total:", error);
      return null; // Don't rethrow, just log the error
    }
  });


  exports.applyGiftCard = functions.https.onCall(async (data, context) => {
  // 1. Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }
  const userId = context.auth.uid;

  // 2. Validate input
  const giftCardCode = data.giftCardCode;
  const cartId = data.cartId; // Should be userId for current setup

  if (!giftCardCode || typeof giftCardCode !== 'string' || giftCardCode.trim() === '') {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The 'giftCardCode' field is required and must be a non-empty string."
    );
  }
  if (!cartId || cartId !== userId) { // Ensure cartId matches authenticated user's ID
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The 'cartId' must match the authenticated user's ID."
    );
  }

  const giftCardRef = db.collection("giftCards").doc(giftCardCode);
  const cartRef = db.collection("carts").doc(cartId);

  return db.runTransaction(async (transaction) => {
    const giftCardDoc = await transaction.get(giftCardRef);
    const cartDoc = await transaction.get(cartRef);

    // 3. Validate Gift Card
    if (!giftCardDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Gift card not found."
      );
    }

    const giftCardData = giftCardDoc.data();
    if (!giftCardData.isActive) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gift card is not active."
      );
    }
    if (giftCardData.balance <= 0) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gift card has no remaining balance."
      );
    }
    if (giftCardData.expirationDate && giftCardData.expirationDate.toDate() < new Date()) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gift card has expired."
      );
    }

    // 4. Get Cart Total
    if (!cartDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Cart not found."
      );
    }
    const cartData = cartDoc.data();
    const currentCartTotal = (typeof cartData.totalPrice === 'number') ? cartData.totalPrice : 0;

    // Prevent applying the same gift card multiple times
    if (cartData.appliedGiftCardCode === giftCardCode) {
       throw new functions.https.HttpsError(
        "already-exists",
        "This gift card has already been applied to this cart."
      );
    }
    // Prevent applying a new gift card if one is already applied
    if (cartData.appliedGiftCardCode) { // If there's any appliedGiftCardCode, even if amount is 0
        throw new functions.https.HttpsError(
            "failed-precondition",
            `A different gift card (${cartData.appliedGiftCardCode}) is already applied. Please remove it first.`
        );
    }


    // 5. Calculate amount to apply
    // The amount applied is the MINIMUM of the gift card's balance OR the current cart total
    const amountToApply = Math.min(giftCardData.balance, currentCartTotal);

    if (amountToApply <= 0) {
        throw new functions.https.HttpsError(
            "failed-precondition",
            "No amount to apply from gift card or cart total is already zero/negative."
        );
    }

    // 6. Update Gift Card balance
    const newGiftCardBalance = giftCardData.balance - amountToApply;
    transaction.update(giftCardRef, { balance: newGiftCardBalance });

    // 7. Update Cart with applied amount
    // giftCardAppliedAmount now represents the specific discount from this card
    transaction.update(cartRef, {
      giftCardAppliedAmount: amountToApply, // Amount this specific gift card reduced
      appliedGiftCardCode: giftCardCode, // Store the applied gift card code
      // finalAmountToPay will be automatically set by calculateCartTotal
    });

    return {
      message: "Gift card applied successfully!",
      appliedAmount: amountToApply,
      newCartTotal: currentCartTotal, // This is current before final adjustment
      newFinalAmountToPay: Math.max(0, currentCartTotal - amountToApply),
      giftCardBalanceRemaining: newGiftCardBalance
    };
  });
});

exports.removeGiftCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }
  const userId = context.auth.uid;
  const cartId = data.cartId;

  if (!cartId || cartId !== userId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The 'cartId' must match the authenticated user's ID."
    );
  }

  const cartRef = db.collection("carts").doc(cartId);

  return db.runTransaction(async (transaction) => {
    const cartDoc = await transaction.get(cartRef);

    if (!cartDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Cart not found."
      );
    }

    const cartData = cartDoc.data();
    const appliedGiftCardCode = cartData.appliedGiftCardCode;
    const giftCardAppliedAmount = (typeof cartData.giftCardAppliedAmount === 'number') ? cartData.giftCardAppliedAmount : 0;

    if (!appliedGiftCardCode || giftCardAppliedAmount === 0) {
      return { message: "No gift card was applied to this cart." };
    }

    const giftCardRef = db.collection("giftCards").doc(appliedGiftCardCode);
    const giftCardDoc = await transaction.get(giftCardRef);

    // Restore gift card balance (if the card still exists)
    if (giftCardDoc.exists) {
      const giftCardData = giftCardDoc.data();
      const newGiftCardBalance = giftCardData.balance + giftCardAppliedAmount;
      transaction.update(giftCardRef, { balance: newGiftCardBalance });
    }
    // else: the gift card might have been deleted, just proceed to clear cart state

    // Clear cart gift card state.
    // calculateCartTotal will then automatically set finalAmountToPay back to totalPrice.
    transaction.update(cartRef, {
      giftCardAppliedAmount: admin.firestore.FieldValue.delete(),
      appliedGiftCardCode: admin.firestore.FieldValue.delete(),
      // finalAmountToPay will be automatically set by calculateCartTotal
    });

    return { message: "Gift card successfully removed from cart and balance restored." };
  });
});


exports.completeOrder = functions.https.onCall(async (data, context) => {
  // 1. Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }
  const userId = context.auth.uid;
  const cartId = userId;

  // Get email from data or fallback to auth token
  const customerEmail = data.email || context.auth.token.email; // PRIMARY CHANGE: get email from data

  if (!customerEmail || typeof customerEmail !== 'string' || customerEmail.trim() === '') {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Customer email is required to complete the order and send confirmation."
      );
  }

  const userRef = db.collection("users").doc(userId); // Assuming 'users' collection exists for shipping info
  const cartRef = db.collection("carts").doc(cartId);
  const cartItemsRef = cartRef.collection("items");

  return db.runTransaction(async (transaction) => {
    const cartDoc = await transaction.get(cartRef);
    if (!cartDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Cart not found or is empty."
      );
    }
    const cartData = cartDoc.data();
    const finalAmountToPay = (typeof cartData.finalAmountToPay === 'number') ? cartData.finalAmountToPay : cartData.totalPrice || 0;
    const totalPrice = (typeof cartData.totalPrice === 'number') ? cartData.totalPrice : 0;
    const giftCardAppliedAmount = (typeof cartData.giftCardAppliedAmount === 'number') ? cartData.giftCardAppliedAmount : 0;
    const appliedGiftCardCode = cartData.appliedGiftCardCode;

    // Ensure there are items in the cart
    const cartItemsSnapshot = await transaction.get(cartItemsRef);
    if (cartItemsSnapshot.empty) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Cannot complete an empty cart."
      );
    }
    if (finalAmountToPay > 0) {
      console.log(`Simulating payment for ${finalAmountToPay} for user ${userId}`);

    }

    // Generate a simple order ID
    const orderId = `${userId}_${Date.now()}`;
    const orderRef = db.collection("orders").doc(orderId);

    // Get shipping information from user profile
    const userDoc = await transaction.get(userRef);
    const userData = userDoc.exists ? userDoc.data() : {};
    const shippingAddress = userData.shippingAddress || null;

    // Get all items from the cart to copy them into the order
    const orderItems = [];
    cartItemsSnapshot.forEach(itemDoc => {
        orderItems.push(itemDoc.data());
        transaction.delete(itemDoc.ref); // Delete item from cart
    });

    // Create the order document
    const orderData = {
      orderId: orderId,
      userId: userId,
      items: orderItems,
      totalPrice: totalPrice, // Original cart total
      giftCardAppliedAmount: giftCardAppliedAmount,
      finalAmountPaid: finalAmountToPay, // Amount actually paid after gift card
      appliedGiftCardCode: appliedGiftCardCode,
      shippingAddress: shippingAddress,
      status: "completed", // e.g., "pending", "processing", "shipped", "completed"
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(orderRef, orderData); // The order has been saved

    // --- START: Send order confirmation email ---
    if (customerEmail) {
        let itemsHtml = orderItems.map(item => `
            <tr>
                <td style="padding: 8px; border: 1px solid #ddd;">${item.productName}</td>
                <td style="padding: 8px; border: 1px solid #ddd;">${item.quantity}</td>
                <td style="padding: 8px; border: 1px solid #ddd;">€${item.productPrice.toFixed(2)}</td>
                <td style="padding: 8px; border: 1px solid #ddd;">€${(item.quantity * item.productPrice).toFixed(2)}</td>
            </tr>
        `).join('');

        let giftCardHtml = '';
        if (giftCardAppliedAmount > 0) {
            giftCardHtml = `
                <tr>
                    <td colspan="3" style="text-align: right; padding: 8px; border: 1px solid #ddd; font-weight: bold;">Gift Card Discount (${appliedGiftCardCode || 'N/A'}):</td>
                    <td style="padding: 8px; border: 1px solid #ddd; color: #28a745; font-weight: bold;">-€${giftCardAppliedAmount.toFixed(2)}</td>
                </tr>
            `;
        }

        const emailHtml = `
            <p>Hello,</p>
            <p>Thank you for your purchase! Your order <strong>#${orderId}</strong> has been confirmed.</p>
            <p>Here is a summary of your order:</p>
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
                <thead>
                    <tr style="background-color: #f2f2f2;">
                        <th style="padding: 8px; border: 1px solid #ddd; text-align: left;">Product</th>
                        <th style="padding: 8px; border: 1px solid #ddd; text-align: left;">Quantity</th>
                        <th style="padding: 8px; border: 1px solid #ddd; text-align: left;">Unit Price</th>
                        <th style="padding: 8px; border: 1px solid #ddd; text-align: left;">Total</th>
                    </tr>
                </thead>
                <tbody>
                    ${itemsHtml}
                    <tr>
                        <td colspan="3" style="text-align: right; padding: 8px; border: 1px solid #ddd; font-weight: bold;">Subtotal:</td>
                        <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">€${totalPrice.toFixed(2)}</td>
                    </tr>
                    ${giftCardHtml}
                    <tr>
                        <td colspan="3" style="text-align: right; padding: 8px; border: 1px solid #ddd; font-weight: bold;">Total Paid:</td>
                        <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold; color: #007bff;">€${finalAmountToPay.toFixed(2)}</td>
                    </tr>
                </tbody>
            </table>
            <p>We will ship your order as soon as possible to the address:</p>
            <p>
                ${shippingAddress ? `
                ${shippingAddress.addressLine1 || ''}<br>
                ${shippingAddress.addressLine2 ? shippingAddress.addressLine2 + '<br>' : ''}
                ${shippingAddress.city || ''}, ${shippingAddress.postalCode || ''}<br>
                ${shippingAddress.country || ''}
                ` : 'No shipping address provided.'}
            </p>
            <p>Thank you again!<br>The Webshop Team</p>
        `;

        await db.collection("mail").add({
            message: {
                to: customerEmail,
                subject: `Order Confirmation #${orderId} from your Webshop`,
                html: emailHtml,
            }
        });
        console.log(`Confirmation email queued for ${customerEmail} for order ${orderId}`);
    } else {
        console.warn(`Customer email not found, confirmation email not sent for user ${userId}.`);
    }
    // --- END: Send order confirmation email ---

    transaction.update(cartRef, {
        totalPrice: 0, // Set total price to 0 (cart is empty)
        itemCount: 0,  // Set item count to 0 (cart is empty)
        giftCardAppliedAmount: admin.firestore.FieldValue.delete(), // Remove gift card amount
        appliedGiftCardCode: admin.firestore.FieldValue.delete(), // Remove gift card code
        finalAmountToPay: 0 // Explicitly set final amount to 0 as cart is empty
    });


    // Return order ID to the client
    return {
      orderId: orderId,
      message: "Order placed successfully!",
      finalAmountPaid: finalAmountToPay
    };
  });
});

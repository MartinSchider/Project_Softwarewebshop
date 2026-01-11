// functions/index.js
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ==================================================================
// 1. CALCULATE CART TOTAL
// ==================================================================
/**
 * Trigger: Firestore onWrite event for specific cart items.
 * Purpose: Automatically recalculates the shopping cart totals whenever an item is added, 
 * updated, or removed.
 * * Logic:
 * 1. Fetches all items currently in the cart to ensure the total is strictly accurate.
 * 2. Iterates through items to sum up the price and quantity.
 * 3. Checks for any applied Gift Cards in the parent cart document.
 * 4. Recalculates the final amount to pay, ensuring it doesn't drop below zero.
 * 5. Updates the cart document with the new totals and timestamp.
 */
exports.calculateCartTotal = functions.firestore
  .document("carts/{cartId}/items/{itemId}")
  .onWrite(async (change, context) => {
    const cartId = context.params.cartId;
    const cartRef = db.collection("carts").doc(cartId);
    const itemsRef = cartRef.collection("items");

    try {
      // Fetch all items to recalculate from scratch
      const itemsSnapshot = await itemsRef.get();
      let newTotalPrice = 0;
      let newItemCount = 0;

      itemsSnapshot.forEach((doc) => {
        const d = doc.data();
        // Robust fallback to handle different field names (productPrice vs price)
        const p = (typeof d.productPrice === 'number') ? d.productPrice : (d.price || 0);
        const q = (typeof d.quantity === 'number') ? d.quantity : 0;
        newTotalPrice += p * q;
        newItemCount += q;
      });

      // Fetch cart metadata to check for Gift Cards
      const cartDoc = await cartRef.get();
      const cartData = cartDoc.data() || {};
      
      let finalAmount = newTotalPrice;
      const giftAmt = (typeof cartData.giftCardAppliedAmount === 'number') ? cartData.giftCardAppliedAmount : 0;
      
      // Apply discount logic if a gift card is present
      if (cartData.appliedGiftCardCode && giftAmt > 0) {
          finalAmount = Math.max(0, newTotalPrice - giftAmt);
      }

      // Atomically update the cart totals
      await cartRef.set({
          totalPrice: newTotalPrice,
          itemCount: newItemCount,
          finalAmountToPay: finalAmount,
          subtotal: newTotalPrice, // Used for fidelity points calculation
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return null;
    } catch (e) { console.error(e); return null; }
  });

// ==================================================================
// 2. APPLY GIFT CARD
// ==================================================================
/**
 * Callable Function: Allows a user to apply a gift card to their cart.
 * * Logic:
 * 1. Validates authentication and input data.
 * 2. Uses a Transaction to ensure data integrity.
 * 3. Checks if the Gift Card exists, is active, and has a positive balance.
 * 4. Checks if the Cart exists and if a Gift Card is already applied (limit 1 per order).
 * 5. Calculates the discount amount (min(balance, total_cart_price)).
 * 6. Deducts the amount from the Gift Card balance and updates the Cart.
 */
exports.applyGiftCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  
  // Supports both naming conventions for the code
  const giftCardCode = data.giftCardCode || data.code;
  const cartId = context.auth.uid;

  if (!giftCardCode) throw new functions.https.HttpsError("invalid-argument", "Invalid data.");

  const giftRef = db.collection("giftCards").doc(giftCardCode);
  const cartRef = db.collection("carts").doc(cartId);

  return db.runTransaction(async (t) => {
    const gDoc = await t.get(giftRef);
    const cDoc = await t.get(cartRef);

    if (!gDoc.exists) throw new functions.https.HttpsError("not-found", "Card not found.");
    const gData = gDoc.data();
    
    // Validation: Check activity and balance
    if (gData.isActive === false || gData.balance <= 0) {
        throw new functions.https.HttpsError("failed-precondition", "Card invalid or empty.");
    }

    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart not found.");
    const cData = cDoc.data();
    
    // Validation: Prevent multiple cards
    if (cData.appliedGiftCardCode) throw new functions.https.HttpsError("failed-precondition", "Card already applied.");

    const total = cData.totalPrice || 0;
    // Calculate deductible amount
    const amount = Math.min(gData.balance, total);
    
    if (amount <= 0) throw new functions.https.HttpsError("failed-precondition", "Nothing to apply.");

    // Perform updates
    t.update(giftRef, { balance: gData.balance - amount });
    t.update(cartRef, {
      giftCardAppliedAmount: amount,
      appliedGiftCardCode: giftCardCode,
      finalAmountToPay: total - amount,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true, discountAmount: amount };
  });
});

// ==================================================================
// 3. REMOVE GIFT CARD
// ==================================================================
/**
 * Callable Function: Removes an applied gift card from the cart.
 * * Logic:
 * 1. Validates authentication.
 * 2. Uses a Transaction to restore the balance to the Gift Card.
 * 3. Removes the Gift Card metadata from the Cart and resets the final price.
 */
exports.removeGiftCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  const cartId = context.auth.uid;
  const cartRef = db.collection("carts").doc(cartId);

  return db.runTransaction(async (t) => {
    const cDoc = await t.get(cartRef);
    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart not found.");
    
    const cData = cDoc.data();
    const code = cData.appliedGiftCardCode;
    const amt = cData.giftCardAppliedAmount || 0;

    if (!code) return { message: "No card." };

    const gRef = db.collection("giftCards").doc(code);
    const gDoc = await t.get(gRef);
    
    // Restore balance if the card document still exists
    if (gDoc.exists) {
      t.update(gRef, { balance: gDoc.data().balance + amt });
    }

    // Reset cart fields
    t.update(cartRef, {
      giftCardAppliedAmount: admin.firestore.FieldValue.delete(),
      appliedGiftCardCode: admin.firestore.FieldValue.delete(),
      finalAmountToPay: cData.totalPrice || 0,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

// ==================================================================
// 4. COMPLETE ORDER (INCLUDES STOCK MANAGEMENT)
// ==================================================================
/**
 * Callable Function: Finalizes the checkout process.
 * * Logic:
 * 1. Validates user and email.
 * 2. Starts a Firestore Transaction (Critical for stock management).
 * 3. Fetches Cart, Items, User Profile, and Products.
 * 4. **Stock Management**: Iterates through cart items, checks availability in 'products' collection.
 * - If stock is insufficient, throws an error and aborts transaction.
 * - If sufficient, deducts the quantity from the product stock.
 * 5. Creates the Order document with full details (items, address, financial breakdown).
 * 6. Clears the Cart (deletes items and resets metadata).
 * 7. Triggers the confirmation email via the 'mail' collection.
 */
exports.completeOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  const userId = context.auth.uid;
  const cartId = userId;

  let email = data.email || context.auth.token?.email;
  if (typeof email === 'string') email = email.trim();
  if (!email) throw new functions.https.HttpsError("invalid-argument", "Email required.");

  // References
  const userRef = db.collection("users").doc(userId);
  const cartRef = db.collection("carts").doc(cartId);
  const itemsRef = cartRef.collection("items");
  const productsRef = db.collection("products"); 

  return db.runTransaction(async (t) => {
    // A. Read phase: Fetch all necessary documents first
    const cDoc = await t.get(cartRef);
    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart empty.");
    
    const iSnaps = await t.get(itemsRef);
    if (iSnaps.empty) throw new functions.https.HttpsError("failed-precondition", "Cart empty.");

    const uDoc = await t.get(userRef);
    const uData = uDoc.exists ? uDoc.data() : {};
    const cData = cDoc.data();

    // Construct Shipping Address from User Profile
    const address = {
        name: uData.name || '',
        surname: uData.surname || '',
        address: uData.address || '',
        city: uData.city || '',
        postcode: uData.postcode || ''
    };

    const items = [];
    
    // --- STOCK MANAGEMENT: Iterate to check and deduct stock ---
    for (const doc of iSnaps.docs) {
        const val = doc.data();
        const productId = val.productId;
        const quantity = (typeof val.quantity === 'number') ? val.quantity : 1;
        const productName = val.productName || 'Unknown';

        // 1. Fetch Product Data within the transaction
        if (!productId) throw new functions.https.HttpsError("data-loss", "Product ID missing in cart");
        const productDocRef = productsRef.doc(productId);
        const productSnapshot = await t.get(productDocRef);

        if (!productSnapshot.exists) {
            throw new functions.https.HttpsError("not-found", `Product not found: ${productName}`);
        }

        const productData = productSnapshot.data();
        // Support both 'stock' (preferred) and 'productStock' (legacy) fields
        const currentStock = (typeof productData.stock === 'number') ? productData.stock : (productData.productStock || 0);

        // 2. Check Availability
        if (currentStock < quantity) {
            throw new functions.https.HttpsError("resource-exhausted", `Insufficient stock for ${productName}. Available: ${currentStock}`);
        }

        // 3. Deduct Stock
        t.update(productDocRef, { stock: currentStock - quantity });

        // 4. Add to local items array for the Order document
        items.push({
            productId: productId,
            productName: productName,
            productPrice: (typeof val.productPrice==='number') ? val.productPrice : 0,
            quantity: quantity,
            imageUrl: val.imageUrl || productData.imageUrl || null
        });
    }
    // -----------------------------------------------------------

    // Calculate final financials
    const finalAmount = (typeof cData.finalAmountToPay==='number') ? cData.finalAmountToPay : (cData.totalPrice || 0);
    const orderId = `${userId}_${Date.now()}`;
    const orderRef = db.collection("orders").doc(orderId);

    // Save Order Document
    t.set(orderRef, {
      orderId: orderId,
      userId: userId,
      customerEmail: email,
      items: items,
      totalPrice: cData.totalPrice || 0,
      giftCardAppliedAmount: cData.giftCardAppliedAmount || 0,
      finalAmountPaid: finalAmount,
      appliedGiftCardCode: cData.appliedGiftCardCode || null,
      shippingAddress: address,
      status: "pending", 
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Cleanup: Delete cart items
    iSnaps.forEach(d => t.delete(d.ref));
    
    // Cleanup: Reset cart metadata
    t.update(cartRef, {
        totalPrice: 0, 
        itemCount: 0,
        giftCardAppliedAmount: admin.firestore.FieldValue.delete(),
        appliedGiftCardCode: admin.firestore.FieldValue.delete(),
        finalAmountToPay: 0,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    // Email Trigger
    if (email) {
        const prettyHtml = generateOrderEmailHtml({
            orderId: orderId,
            customerName: address.name || email.split('@')[0],
            items: items,
            subtotal: cData.totalPrice || 0,
            discount: cData.giftCardAppliedAmount || 0,
            total: finalAmount
        });
        
        const mailRef = db.collection("mail").doc();
        t.set(mailRef, { to: email, message: { subject: `Order Confirmation #${orderId}`, html: prettyHtml } });
    }

    return { orderId: orderId, success: true };
  });
});

// ==================================================================
// 5. ORDER STATUS MONITORING (SHIPPED / CANCELLED EMAILS)
// ==================================================================
/**
 * Trigger: Firestore onUpdate event for orders.
 * Purpose: Monitors changes in the 'status' field of an order.
 * * Logic:
 * 1. Compares old status vs new status. Exits if unchanged.
 * 2. Checks if the new status is 'shipped' or 'cancelled'.
 * 3. Retrieves the customer email and name from the order document.
 * 4. Generates the appropriate HTML email template.
 * 5. Writes to the 'mail' collection to trigger the email delivery extension.
 */
exports.onOrderStatusChange = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    // Exit if status hasn't changed
    if (newData.status === oldData.status) return null;

    const newStatus = newData.status;
    const orderId = context.params.orderId;
    const customerEmail = newData.customerEmail;
    
    // Safe retrieval of customer name
    let customerName = "Customer";
    if (newData.shippingAddress && newData.shippingAddress.name) {
       customerName = newData.shippingAddress.name;
    }

    if (!customerEmail) return null;

    let subject = "";
    let htmlContent = "";

    // Determine template based on status
    if (newStatus === "shipped") {
      subject = `Your Order #${orderId} has been Shipped! 🚚`;
      htmlContent = generateShippingEmailHtml({
        orderId: orderId,
        customerName: customerName,
        items: newData.items || []
      });
    } else if (newStatus === "cancelled") {
      subject = `Order #${orderId} Cancelled`;
      htmlContent = generateCancellationEmailHtml({
        orderId: orderId,
        customerName: customerName
      });
    } else {
      return null;
    }

    try {
      await db.collection("mail").add({
        to: customerEmail,
        message: { subject: subject, html: htmlContent },
      });
    } catch (e) { console.error(e); }

    return null;
  });


// ==================================================================
// HELPER FUNCTIONS (EMAIL TEMPLATES)
// ==================================================================

/**
 * Generates the HTML for the Order Confirmation email.
 */
function generateOrderEmailHtml(order) {
  const logoUrl = "https://via.placeholder.com/150x50?text=WebShop"; 
  const primaryColor = "#6200EA"; 
  const accentColor = "#FFD740";

  const itemsHtml = order.items.map(item => `
    <tr>
      <td style="padding: 10px; border-bottom: 1px solid #eee;">
        <img src="${item.imageUrl || 'https://via.placeholder.com/50'}" alt="${item.productName}" width="50" height="50" style="border-radius: 8px; object-fit: cover;">
      </td>
      <td style="padding: 10px; border-bottom: 1px solid #eee; font-family: Arial, sans-serif;">
        <strong style="color: #333;">${item.productName}</strong>
      </td>
      <td style="padding: 10px; border-bottom: 1px solid #eee; font-family: Arial, sans-serif; text-align: center;">
        x${item.quantity}
      </td>
      <td style="padding: 10px; border-bottom: 1px solid #eee; font-family: Arial, sans-serif; text-align: right;">
        €${Number(item.productPrice).toFixed(2)}
      </td>
    </tr>
  `).join('');

  return `
  <!DOCTYPE html>
  <html>
  <body style="margin: 0; padding: 0; background-color: #f4f4f4; font-family: Arial, sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
      <tr>
        <td align="center" style="padding: 20px 0;">
          <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1);">
            <tr>
              <td align="center" style="background-color: ${primaryColor}; padding: 30px;">
                <img src="${logoUrl}" alt="Logo" width="120" style="display: block; margin-bottom: 10px;">
                <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Order Confirmed!</h1>
                <p style="color: rgba(255,255,255,0.8); margin: 5px 0 0 0;">#${order.orderId}</p>
              </td>
            </tr>
            <tr>
              <td style="padding: 30px;">
                <p style="color: #555;">Hi <strong>${order.customerName}</strong>, thank you for your order.</p>
                <table width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-top: 20px;">
                  <thead>
                    <tr>
                      <th align="left" style="color: #999; font-size: 12px;">ITEM</th>
                      <th align="left" style="color: #999; font-size: 12px;">NAME</th>
                      <th align="center" style="color: #999; font-size: 12px;">QTY</th>
                      <th align="right" style="color: #999; font-size: 12px;">PRICE</th>
                    </tr>
                  </thead>
                  <tbody>${itemsHtml}</tbody>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding: 0 30px 30px 30px;">
                <table width="100%" cellspacing="0" cellpadding="0" border="0">
                  <tr>
                    <td align="right" style="padding: 5px 0; color: #666;">Subtotal:</td>
                    <td align="right" style="padding: 5px 0; font-weight: bold; width: 100px;">€${Number(order.subtotal).toFixed(2)}</td>
                  </tr>
                  <tr>
                    <td align="right" style="padding: 5px 0; color: #2ecc71;">Discount:</td>
                    <td align="right" style="padding: 5px 0; color: #2ecc71; font-weight: bold;">-€${Number(order.discount).toFixed(2)}</td>
                  </tr>
                  <tr>
                    <td colspan="2" style="border-top: 2px solid #eee; padding-top: 10px; margin-top: 10px;"></td>
                  </tr>
                  <tr>
                    <td align="right" style="font-size: 18px; font-weight: bold;">Total:</td>
                    <td align="right" style="font-size: 18px; color: ${primaryColor}; font-weight: bold;">€${Number(order.total).toFixed(2)}</td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
               <td style="padding: 0 30px 30px 30px;">
                 <div style="background-color: #fff8e1; border: 1px dashed ${accentColor}; padding: 15px; border-radius: 8px; text-align: center;">
                   <strong style="color: #ff8f00;">🌟 You earned ${Math.floor(Number(order.subtotal))} points!</strong>
                 </div>
               </td>
            </tr>
          </table>
          <p style="text-align: center; font-size: 12px; color: #bbb; margin-top: 20px;">© 2024 WebShop Inc.</p>
        </td>
      </tr>
    </table>
  </body>
  </html>
  `;
}

/**
 * Generates the HTML for the Shipping Notification email.
 */
function generateShippingEmailHtml(order) {
  const logoUrl = "https://via.placeholder.com/150x50?text=WebShop";
  const primaryColor = "#00C853"; 

  const itemsSummary = order.items.map(i => `<li style="margin-bottom: 5px;">${i.quantity}x <strong>${i.productName || i.name}</strong></li>`).join('');

  return `
  <!DOCTYPE html>
  <html>
  <body style="margin: 0; padding: 0; background-color: #f4f4f4; font-family: Arial, sans-serif;">
    <div style="max-width: 600px; margin: 20px auto; background: white; border-radius: 8px; overflow: hidden; font-family: sans-serif;">
        <div style="background-color: ${primaryColor}; padding: 20px; text-align: center;">
            <img src="${logoUrl}" alt="Logo" width="120" style="display: block; margin: 0 auto 10px;">
            <h1 style="color: white; margin:0;">Order Shipped! 🚚</h1>
        </div>
        <div style="padding: 20px;">
            <p>Hi <strong>${order.customerName}</strong>,</p>
            <p>Great news! Your order <strong>#${order.orderId}</strong> has been shipped and is on its way.</p>
            <div style="background-color: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <h3 style="margin-top:0;">Items:</h3>
                <ul style="padding-left: 20px;">${itemsSummary}</ul>
            </div>
            <p>Thank you for shopping with us!</p>
        </div>
    </div>
  </body>
  </html>`;
}

/**
 * Generates the HTML for the Order Cancellation email.
 */
function generateCancellationEmailHtml(order) {
  const logoUrl = "https://via.placeholder.com/150x50?text=WebShop";
  const primaryColor = "#D32F2F"; 

  return `
  <!DOCTYPE html>
  <html>
  <body style="margin: 0; padding: 0; background-color: #f4f4f4; font-family: Arial, sans-serif;">
    <div style="max-width: 600px; margin: 20px auto; background: white; border-radius: 8px; overflow: hidden; font-family: sans-serif;">
        <div style="background-color: ${primaryColor}; padding: 20px; text-align: center;">
            <img src="${logoUrl}" alt="Logo" width="120" style="display: block; margin: 0 auto 10px;">
            <h1 style="color: white; margin:0;">Order Cancelled</h1>
        </div>
        <div style="padding: 20px;">
            <p>Hi <strong>${order.customerName}</strong>,</p>
            <p>Your order <strong>#${order.orderId}</strong> has been cancelled.</p>
            <p>If you have already been charged, a refund will be processed shortly.</p>
        </div>
    </div>
  </body>
  </html>`;
}
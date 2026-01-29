/**
 * ============================================================================
 * WEB SHOP CLOUD FUNCTIONS
 * Backend logic for managing the shopping cart, orders, and stock management.
 * ============================================================================
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// =================================================================================
// 1. CALCULATE CART TOTAL (Background Trigger)
// =================================================================================
/**
 * Trigger: Firestore `onWrite` event on any item inside `carts/{cartId}/items`.
 * * Mechanism:
 * 1. Fetches all items in the cart to ensure the total is calculated from scratch (prevents drift).
 * 2. Sums up quantity and price.
 * 3. Checks the parent Cart document for any applied Gift Cards.
 * 4. Updates the parent Cart document with the new `totalPrice`, `itemCount`, and `finalAmountToPay`.
 */
exports.calculateCartTotal = functions.firestore
  .document("carts/{cartId}/items/{itemId}")
  .onWrite(async (change, context) => {
    const cartId = context.params.cartId;
    const cartRef = db.collection("carts").doc(cartId);
    const itemsRef = cartRef.collection("items");

    try {
      // 1. Fetch all items (Read Operation)
      const itemsSnapshot = await itemsRef.get();
      let newTotalPrice = 0;
      let newItemCount = 0;

      // 2. Iterate and Sum
      itemsSnapshot.forEach((doc) => {
        const d = doc.data();
        // Fallback logic for different naming conventions (price vs productPrice)
        const p = (typeof d.productPrice === 'number') ? d.productPrice : (d.price || 0);
        const q = (typeof d.quantity === 'number') ? d.quantity : 0;
        newTotalPrice += p * q;
        newItemCount += q;
      });

      // 3. Check for Discounts (Gift Cards)
      const cartDoc = await cartRef.get();
      const cartData = cartDoc.data() || {};
      
      let finalAmount = newTotalPrice;
      const giftAmt = (typeof cartData.giftCardAppliedAmount === 'number') ? cartData.giftCardAppliedAmount : 0;
      
      if (cartData.appliedGiftCardCode && giftAmt > 0) {
          // Ensure total doesn't go below zero
          finalAmount = Math.max(0, newTotalPrice - giftAmt);
      }

      // 4. Update Cart (Write Operation)
      await cartRef.set({
          totalPrice: newTotalPrice,
          itemCount: newItemCount,
          finalAmountToPay: finalAmount,
          subtotal: newTotalPrice, // Used for fidelity points
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      return null;
    } catch (e) { 
      console.error("[calculateCartTotal] Error:", e); 
      return null; 
    }
  });

// =================================================================================
// 2. APPLY GIFT CARD (HTTPS Callable)
// =================================================================================
/**
 * Callable Function: Applies a gift card code to the user's cart.
 * * Mechanism:
 * Uses a Transaction to ensure the Gift Card balance is checked and deducted atomically.
 * It prevents race conditions where a user might use the same card twice simultaneously.
 */
exports.applyGiftCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  
  const giftCardCode = data.giftCardCode || data.code;
  const cartId = context.auth.uid;

  if (!giftCardCode) throw new functions.https.HttpsError("invalid-argument", "Invalid data.");

  const giftRef = db.collection("giftCards").doc(giftCardCode);
  const cartRef = db.collection("carts").doc(cartId);

  return db.runTransaction(async (t) => {
    const gDoc = await t.get(giftRef);
    const cDoc = await t.get(cartRef);

    // Validations
    if (!gDoc.exists) throw new functions.https.HttpsError("not-found", "Card not found.");
    const gData = gDoc.data();
    
    if (gData.isActive === false || gData.balance <= 0) {
        throw new functions.https.HttpsError("failed-precondition", "Card invalid or empty.");
    }

    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart not found.");
    const cData = cDoc.data();
    
    if (cData.appliedGiftCardCode) throw new functions.https.HttpsError("failed-precondition", "Card already applied.");

    // Calculation
    const total = cData.totalPrice || 0;
    const amount = Math.min(gData.balance, total);
    
    if (amount <= 0) throw new functions.https.HttpsError("failed-precondition", "Nothing to apply.");

    // Updates
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

// =================================================================================
// 3. REMOVE GIFT CARD (HTTPS Callable)
// =================================================================================
/**
 * Callable Function: Removes a gift card from the cart.
 * * Mechanism:
 * Restores the deducted amount back to the Gift Card's balance and resets the cart totals.
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
    
    // Restore balance if card still exists
    if (gDoc.exists) {
      t.update(gRef, { balance: gDoc.data().balance + amt });
    }

    // Reset Cart
    t.update(cartRef, {
      giftCardAppliedAmount: admin.firestore.FieldValue.delete(),
      appliedGiftCardCode: admin.firestore.FieldValue.delete(),
      finalAmountToPay: cData.totalPrice || 0,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

// =================================================================================
// 4. COMPLETE ORDER
// =================================================================================
/**
 * Callable Function: Finalizes the order.
 * * Mechanism:
 * Uses a strict "Read-Before-Write" Transaction pattern to avoid Firestore "INTERNAL" errors.
 * * Steps:
 * 1. PHASE 1 (READS): Fetches User, Cart, Cart Items, and ALL referenced Products.
 * 2. PHASE 2 (LOGIC): Iterates through items in memory to check availability and calculate new stock.
 * 3. PHASE 3 (WRITES): Updates Product stocks, creates the Order, and deletes Cart content.
 */
exports.completeOrder = functions.https.onCall(async (data, context) => {
  // 1. Authentication Check
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  const userId = context.auth.uid;
  const cartId = userId;

  let email = data.email || context.auth.token?.email;
  if (typeof email === 'string') email = email.trim();
  if (!email) throw new functions.https.HttpsError("invalid-argument", "Email required.");

  // Database References
  const userRef = db.collection("users").doc(userId);
  const cartRef = db.collection("carts").doc(cartId);
  const itemsRef = cartRef.collection("items");
  const productsRef = db.collection("products"); 

  return db.runTransaction(async (t) => {
    // ---------------------------------------------------------
    // PHASE 1: READ
    // ---------------------------------------------------------
    
    const cDoc = await t.get(cartRef);
    if (!cDoc.exists) throw new functions.https.HttpsError("not-found", "Cart empty.");
    
    const iSnaps = await t.get(itemsRef);
    if (iSnaps.empty) throw new functions.https.HttpsError("failed-precondition", "Cart empty.");

    const uDoc = await t.get(userRef);
    const uData = uDoc.exists ? uDoc.data() : {};
    const cData = cDoc.data();

    // Prepare Address
    const address = {
        name: uData.name || '',
        surname: uData.surname || '',
        address: uData.address || '',
        city: uData.city || '',
        postcode: uData.postcode || ''
    };

    // LOAD PRODUCTS:
    // We collect all unique Product IDs first to avoid duplicate reads inside the loop.
    const productMap = {}; // Will hold { ref, data, currentStock }
    
    for (const doc of iSnaps.docs) {
        const pid = doc.data().productId;
        if (pid && !productMap[pid]) {
            const pRef = productsRef.doc(pid);
            const pSnap = await t.get(pRef); // Safe Read
            
            if (!pSnap.exists) throw new functions.https.HttpsError("not-found", `Product missing: ${pid}`);
            
            const pData = pSnap.data();
            const stock = (typeof pData.stock === 'number') ? pData.stock : (pData.productStock || 0);
            
            productMap[pid] = {
                ref: pRef,
                data: pData,
                currentStock: stock
            };
        }
    }

    // ---------------------------------------------------------
    // PHASE 2: BUSINESS LOGIC (No Reads, No Writes)
    // ---------------------------------------------------------
    const finalItems = [];
    
    for (const doc of iSnaps.docs) {
        const val = doc.data();
        const pid = val.productId;
        const qty = (typeof val.quantity === 'number') ? val.quantity : 1;
        
        // Retrieve loaded product data
        const pInfo = productMap[pid];
        if (!pInfo) continue; // Should not happen given Phase 1

        // Check Stock availability
        if (pInfo.currentStock < qty) {
            throw new functions.https.HttpsError("resource-exhausted", `Insufficient stock for ${pInfo.data.productName || 'product'}.`);
        }

        // Deduct from temporary memory (handles multiple rows of same product)
        pInfo.currentStock -= qty;

        finalItems.push({
            productId: pid,
            productName: pInfo.data.productName || val.productName || 'Unknown',
            productPrice: (typeof val.productPrice==='number') ? val.productPrice : 0,
            quantity: qty,
            imageUrl: val.imageUrl || pInfo.data.imageUrl || null
        });
    }

    // ---------------------------------------------------------
    // PHASE 3: WRITE
    // ---------------------------------------------------------

    // 1. Update Product Stocks in DB
    Object.values(productMap).forEach(info => {
        t.update(info.ref, { stock: info.currentStock });
    });

    // 2. Create Order Document
    const finalAmount = (typeof cData.finalAmountToPay==='number') ? cData.finalAmountToPay : (cData.totalPrice || 0);
    const orderId = `${userId}_${Date.now()}`;
    const orderRef = db.collection("orders").doc(orderId);

    t.set(orderRef, {
      orderId: orderId,
      userId: userId,
      customerEmail: email,
      items: finalItems,
      totalPrice: cData.totalPrice || 0,
      giftCardAppliedAmount: cData.giftCardAppliedAmount || 0,
      finalAmountPaid: finalAmount,
      appliedGiftCardCode: cData.appliedGiftCardCode || null,
      shippingAddress: address,
      status: "pending", 
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Clear Cart Items
    iSnaps.forEach(d => t.delete(d.ref));
    
    // 4. Reset Cart Metadata
    t.update(cartRef, {
        totalPrice: 0, 
        itemCount: 0,
        giftCardAppliedAmount: admin.firestore.FieldValue.delete(),
        appliedGiftCardCode: admin.firestore.FieldValue.delete(),
        finalAmountToPay: 0,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    // 5. Trigger Email (Write to 'mail' collection)
    if (email) {
        const prettyHtml = generateOrderEmailHtml({
            orderId: orderId,
            customerName: address.name || email.split('@')[0],
            items: finalItems,
            subtotal: cData.totalPrice || 0,
            discount: cData.giftCardAppliedAmount || 0,
            total: finalAmount
        });
        
        const mailRef = db.collection("mail").doc();
        t.set(mailRef, { 
            to: email, 
            message: { subject: `Order Confirmation #${orderId}`, html: prettyHtml } 
        });
    }

    return { orderId: orderId, success: true };
  });
});

// =================================================================================
// 5. ORDER STATUS MONITORING (Background Trigger)
// =================================================================================
/**
 * Trigger: Firestore `onUpdate` event for orders.
 * * Mechanism:
 * Monitors the 'status' field. If it changes to 'shipped' or 'cancelled', 
 * it sends a formatted HTML email to the customer.
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
    
    let customerName = "Customer";
    if (newData.shippingAddress && newData.shippingAddress.name) {
       customerName = newData.shippingAddress.name;
    }

    if (!customerEmail) return null;

    let subject = "";
    let htmlContent = "";

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


// =================================================================================
// HELPER FUNCTIONS (Email Templates)
// =================================================================================

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
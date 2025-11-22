[CLICK HERE FOR THE WEBPAGE](https://softwarewebshop-7ff5a.web.app)

| Date | TO DO | DONE |
| :---- | :---- | :---- |
| 03/11/2025 |  | Homepage Product Page Access Cart Shipment page Payment page Searchbar |
| 10/11/2025 |  | Fix Search Bar Fix Cart  |
| 17/11/2025 | AI chatbot | Order management Improve graphics Gift Card (payment) working |
| 24/11/2025 |  | Automatic email to the customer when the order is complete  |

Dart	programming language  
Flutter	framework  

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_  
17.10.2025  
Group members: Martin Schider (12317896), Marco Terranova (12507589)

Our project is to implement a webshop with the following specifications:

* Homepage, where all the products are listed  
* at the top a searchbar, where it leads to the products  
* Filter, for products  
* Cart button (which is sending the cart)  
* AI-Chatbot (for any questions about the products from the customer)  
* Checkout-page (shipment method, payment method)  
* Sending an email to the customer after purchase

**DB CLIENT:**

ID\_CLIENT (P.K.) \- NAME \- SURNAME \- ADDRESS

**DB PRODUCT:**

ID\_PRODUCT (P.K.) \- NAME – COMPANY \-  QUANTITY – PRICE – EXPIRING DATE

**DB ORDER:**  
ID\_ORDER (P.K.) – REF\_CLIENT – REF\_PRODUCT  
(REF\_PRODUCT \= ID\_PRODUCT IN PRODUCT),(REF\_CLIENT \= ID\_CLIENT IN CLIENT)

**DATABASE**: MySQL  
**BACKEND**: Go  
**FRONTEND**: HTML, CSS,JavaScript

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_  
24.10.2025

**PRESENTATION**: [webshop2.0.pptx](https://docs.google.com/presentation/d/17tjFTzg7d7kB7LVZ57fAnTxoeiGZwSan/edit?usp=sharing&ouid=113812463948931690339&rtpof=true&sd=true)

**DESCRIPTON:**

The presentation illustrates the structural design and functionality of our webshop. The red buttons shown on the slides are interactive and lead the user to the corresponding section of the presentation.  
 The slides represent different user perspectives within the system:

* **Slides 1–8:** Customer (without login)  
* **Slides 9–15:** Seller  
* **Slides 16–20:** Customer (with login)

**Slide 2 – Homepage**

This slide presents the homepage of the webshop, which serves as the main entry point for customers.  
 It includes several key elements:

* a search bar  
* a login button  
* a cart icon  
* a list of featured products  
* and an AI button

The layout demonstrates the overall structure of the user interface and provides an overview of the main navigation components of the webshop.

**Slide 3 – Product Page**

This slide illustrates the layout of an individual product page. It contains all relevant product information required for an online display, including:

* Product image  
* Title  
* Price  
* Available quantity  
* Description  
* Add to Cart button

The search bar, cart, and login options remain visible to ensure consistent navigation across the website.

**Slide 4 – Homepage (bottom of the page)**

This slide displays the lower section of the homepage, which contains additional service-oriented elements:

* Download links for the webshop’s mobile app, available for both Android and iOS  
* a section for additional information

These features extend the functionality of the website beyond product browsing and purchasing.

**Slide 5 – AI Chat**

When the AI button on the homepage (Slide 2\) is selected, a chat window appears.  
 Through this interface, users can communicate with the AI bot via text or voice messages to ask questions about products.  
 Additionally, the AI bot allows users to complete a purchase directly through the chat.  
 This slide demonstrates how the AI assistant enhances customer interaction and support within the webshop.

**Slide 6 – Cart**

This slide presents the shopping cart view. All products added by the user are listed here, giving an overview of the current selections. A Checkout button is placed at the bottom of the page, guiding the user to the payment process. This slide visualizes the transition from product selection to order processing.

**Slide 7 – Checkout Page**

The checkout page is displayed on this slide.  
 It contains the required fields for order completion, including:

* Credit card number  
* First and last name

After entering the necessary information, the user clicks on *“Complete”* to finalize the purchase. This leads to **Slide 8** (Order Complete), where the order confirmation is displayed, and the customer receives a confirmation email.

It is important to note that only logged-in users can complete a purchase. Unregistered users may browse products but cannot place orders.

**Slide 10 – Seller Login**

This slide presents the login page for sellers.  
 The seller is required to enter:

* Username  
* Password

After successful login, the seller gains access to the administrative dashboard.

**Slide 11 – Seller page**

This slide provides an overview of the seller’s administrative interface. It includes three main management sections:

* Product list – displays all active listings  
* Orders – shows current and past transactions  
* Customers – lists all customer IDs registered in the system

**Slide 12 – List of products (seller)**

This slide focuses on product management functions.  
 Sellers can perform the following operations:

* Change price  
* Update quantity  
* Delete product

This functionality enables sellers to maintain and update their product catalog independently.

**Slide 13 – Order List (Seller View)**

The order list is presented on this slide. Each order entry includes:

* the customer name  
* the total amount  
* and a delete option

Additionally, a detailed order view (shown on **Slide 14**) displays:

* the list of ordered products  
* shipping and payment information  
* and the order status

This section visualizes how sellers can review and manage incoming orders.

**Slide 15 – List of clients (seller area)**

This slide depicts the customer management interface. Each customer is represented by their unique ID and can be removed from the list if necessary. This view supports the organization and maintenance of customer data within the seller’s system.

**Slide 17 – Customer Login**

This slide presents the login page for customers. Users enter their username and password to access their private account area (**Slide 18**). After logging in, customers can view their previous orders and place new ones.

**Slide 19 – Orders (Customer)**

This slide displays the customer’s order overview. Similar to the seller’s interface, the customer can view and, if needed, delete past orders. In the detailed view (**Slide 20**), each order contains:

* a product list  
* shipping and payment details  
* and the order status


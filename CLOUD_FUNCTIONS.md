# Firebase Cloud Functions API Documentation

This document outlines the contract between the Flutter Client and the Firebase Backend.
All functions are **HTTPS Callable Functions** intended to be called directly from the app using the Firebase SDK.

---

## 1. `completeOrder`

Finalizes the transaction, moves items from the cart to the orders collection, and triggers confirmation emails.

* **Trigger:** HTTPS Callable
* **Authentication:** Required (`context.auth` must exist)

### Request Parameters (Input)

| Parameter | Type     | Required | Description                                      |
| :-------- | :------- | :------- | :----------------------------------------------- |
| `email`   | `string` | Yes    | The customer's email address for notifications.  |

### Response (Output)

Returns a JSON object containing the order details.

```json
{
  "orderId": "ORD-12345-XYZ",
  "finalAmountPaid": 150.50
}
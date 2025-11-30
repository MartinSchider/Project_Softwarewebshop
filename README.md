# Webshop

A modern, scalable E-commerce application built with **Flutter** and **Firebase**.
This project implements a **Layered Architecture** using **Riverpod** for state management, ensuring separation of concerns, testability, and high performance.

---

## Tech Stack & Features

-   **Framework:** Flutter (Web, Android, iOS)
-   **Language:** Dart
-   **State Management:** Flutter Riverpod
-   **Backend:** Firebase (Auth, Firestore, Cloud Functions)
-   **Key Features:**
    -   Infinite Scroll Pagination (Performance Optimized)
    -   Real-time Cart Management
    -   Hybrid Cart Calculation (Client-side speed + Server-side validation)
    -   Cached Network Images
    -   Robust Error Handling & Retry Mechanisms

---

## Architecture Overview

The codebase follows a strict **Service-Repository Pattern** to decouple the UI from the Data Layer.

```mermaid
graph TD
    UI[UI / Widgets] -->|Watch| Providers[Riverpod Providers]
    Providers -->|Call| Services[Services Layer]
    Services -->|Call| Repositories[Repositories Layer]
    Repositories -->|Read/Write| Firebase[(Firebase / Ext. API)]
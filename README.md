# 🧵 Karigari

### *Where Every Piece Tells a Handmade Story*

Karigari is a full-stack e-commerce mobile application built with Flutter, designed to connect local artisans with buyers through a digital marketplace for handmade products.

The platform provides dedicated experiences for **buyers and sellers**, combining e-commerce, secure payments, seller analytics, and AI-powered shopping and growth tools.

---

## ✨ Features

### 🛍️ Buyer

- Browse handmade products
- View product details and craft stories
- Add products to cart
- Checkout and place orders
- Razorpay payment integration
- AI-powered shopping assistant

### 🎨 Seller

- Seller dashboard
- Upload and manage products
- Receive order notifications
- View orders and order details
- Sales and product analytics
- AI-powered growth insights
- AI-generated product listings
- AI-generated campaign ideas

---

## 🏗️ Architecture

```mermaid
flowchart TD

    APP["📱 Flutter App"]

    APP --> AUTH["🔐 Firebase Authentication"]
    APP --> DB[("🔥 Cloud Firestore")]
    APP --> AI["✨ Firebase AI"]
    APP --> CLOUD["☁️ Cloudinary"]
    APP --> PAY["💳 Razorpay"]

    AUTH --> BUYER["🛍️ Buyer"]
    AUTH --> SELLER["🎨 Seller"]

    DB --> PRODUCTS["📦 Products"]
    DB --> ORDERS["🧾 Orders"]
    DB --> SELLERDATA["🏪 Seller Data"]

    CLOUD --> IMAGES["🖼️ Product Images"]

    BUYER --> AIASSIST["🤖 AI Shopping Assistant"]
    SELLER --> ANALYTICS["📊 Seller Analytics"]
    ANALYTICS --> GROWTH["✨ AI Growth"]

    AI --> AIASSIST
    AI --> GROWTH

    PAY --> ORDERS
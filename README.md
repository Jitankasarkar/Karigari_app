<div align="center">

# 🧵 KARIGARI

### Where Every Piece Tells a Handmade Story.

**An AI-powered digital marketplace connecting artisans with buyers through handmade commerce.**

<br>

<p align="center">
  <img src="screenshots\karigari_readme_all_7_screens_soft.gif" alt="Karigari App Showcase" width="100%">
</p>

<br>

**Flutter** · **Firebase** · **Firebase AI** · **Cloudinary** · **Razorpay**

</div>

---

# ✨ What is Karigari?

**Karigari** is a full-stack Flutter e-commerce application designed to
connect **local artisans with buyers through a digital marketplace for handmade products.**

It brings together two sides of commerce:

| 🛍️ Buyer | 🎨 Seller |
|:---:|:---:|
| Discover handmade products | Manage products |
| Explore craft stories | Receive orders |
| Add to cart | Track sales |
| Razorpay checkout | View analytics |
| AI shopping assistant | AI-powered growth tools |

> **Make handmade commerce easier to discover, easier to sell, and smarter to grow.**

---

# 💡 Why Karigari?

Local artisans create unique products, but reaching customers and understanding
their business digitally can be difficult.

Karigari connects the complete journey:

<div align="center">

### ARTISAN → PRODUCT → DISCOVERY → PURCHASE → DATA → INSIGHT → GROWTH

</div>

A purchase is not treated as the end of the journey.

**Every order becomes useful business data for the artisan.**

---

# 🚀 What Can Karigari Do?

## 🛍️ Buyer

- Browse handmade products
- Search and explore categories
- View product details and craft stories
- Add products to cart
- Checkout with shipping details
- Pay through Razorpay
- Use the AI shopping assistant

## 🎨 Seller

- Seller authentication
- Seller dashboard
- Upload products
- Manage product catalogue
- Receive new-order notifications
- View order details
- Track revenue and orders
- Analyze product performance
- Generate AI growth insights
- Generate product listing content
- Generate campaign ideas

---

# 🤖 AI Experience

Karigari uses AI where it can actually improve the experience.

## Buyer AI

```mermaid
flowchart LR

    BUYER["🛍️ Buyer"]
    ASSISTANT["🤖 AI Shopping Assistant"]

    DISCOVERY["Product Discovery"]
    RECOMMENDATIONS["Recommendations"]
    SELECTION["Product Selection"]
    CART["🛒 Cart"]

    BUYER --> ASSISTANT

    ASSISTANT --> DISCOVERY
    ASSISTANT --> RECOMMENDATIONS
    ASSISTANT --> SELECTION

    SELECTION --> CART
```

The shopping assistant helps buyers discover products through a conversational experience.

---

## Seller AI

```mermaid
flowchart TD

    DATA[("🔥 Firestore Commerce Data")]

    ANALYTICS["📊 Seller Analytics"]
    GROWTH["✨ AI Growth"]

    INSIGHTS["Growth Insights"]
    ACTIONS["Action Plans"]
    LISTINGS["AI Product Listings"]
    CAMPAIGNS["Campaign Ideas"]

    DATA --> ANALYTICS
    ANALYTICS --> GROWTH

    GROWTH --> INSIGHTS
    GROWTH --> ACTIONS
    GROWTH --> LISTINGS
    GROWTH --> CAMPAIGNS
```

**AI helps buyers discover and helps sellers act.**

---

# 💳 Commerce & Payment Flow

```mermaid
flowchart LR

    BUYER["🛍️ Buyer"]
    CART["🛒 Cart"]
    CHECKOUT["Checkout"]
    RAZORPAY["💳 Razorpay"]
    ORDER["🧾 Firestore Order"]
    SELLER["🎨 Seller Dashboard"]

    BUYER --> CART
    CART --> CHECKOUT
    CHECKOUT --> RAZORPAY
    RAZORPAY --> ORDER
    ORDER --> SELLER
```

After successful payment, the order is stored in Firestore and becomes
available to the corresponding seller.

---

# 🏗️ Architecture

```mermaid
flowchart TB

    APP["📱 Flutter Application"]

    APP --> AUTH["🔐 Firebase Authentication"]
    APP --> FIRESTORE[("🔥 Cloud Firestore")]
    APP --> AI["✨ Firebase AI"]
    APP --> CLOUDINARY["☁️ Cloudinary"]
    APP --> RAZORPAY["💳 Razorpay"]

    AUTH --> BUYER["🛍️ Buyer Experience"]
    AUTH --> SELLER["🎨 Seller Experience"]

    FIRESTORE --> PRODUCTS["📦 Products"]
    FIRESTORE --> ORDERS["🧾 Orders"]
    FIRESTORE --> SELLERDATA["🏪 Seller Data"]

    CLOUDINARY --> IMAGES["🖼️ Product Images"]

    BUYER --> CATALOGUE["Product Catalogue"]
    BUYER --> DETAILS["Product Details"]
    BUYER --> CART["Cart & Checkout"]
    BUYER --> ASSISTANT["🤖 AI Shopping Assistant"]

    SELLER --> DASHBOARD["📊 Seller Dashboard"]

    DASHBOARD --> HOME["🏠 Home"]
    DASHBOARD --> UPLOAD["➕ Upload Product"]
    DASHBOARD --> ANALYTICS["📈 Analytics"]
    DASHBOARD --> GROWTH["✨ AI Growth"]

    AI --> ASSISTANT
    AI --> GROWTH

    RAZORPAY --> ORDERS

    ORDERS --> ANALYTICS
    PRODUCTS --> ANALYTICS
```

---

# 🔄 How It Works

## Product Flow

```mermaid
flowchart LR

    SELLER["🎨 Seller"]
    UPLOAD["Upload Product"]
    CLOUDINARY["☁️ Cloudinary"]
    IMAGE["🖼️ Product Image"]
    FIRESTORE[("🔥 Firestore")]
    CATALOGUE["🛍️ Buyer Catalogue"]

    SELLER --> UPLOAD

    UPLOAD --> CLOUDINARY
    CLOUDINARY --> IMAGE

    UPLOAD --> FIRESTORE
    IMAGE --> FIRESTORE

    FIRESTORE --> CATALOGUE
```

---

## Order Flow

```mermaid
flowchart LR

    BUYER["🛍️ Buyer"]
    CHECKOUT["Checkout"]
    PAYMENT["💳 Razorpay"]
    ORDER[("🧾 Firestore Order")]
    SELLER["🎨 Seller"]
    NOTIFICATION["🔔 Seller Notification"]

    BUYER --> CHECKOUT
    CHECKOUT --> PAYMENT
    PAYMENT --> ORDER
    ORDER --> SELLER
    ORDER --> NOTIFICATION
```

---

## Analytics Flow

```mermaid
flowchart TD

    ORDERS[("🧾 Firestore Orders")]

    ANALYTICS["📊 Seller Analytics"]

    REVENUE["Revenue"]
    ACTIVITY["Order Activity"]
    PRODUCTS["Product Performance"]

    GROWTH["✨ AI Growth"]

    ORDERS --> ANALYTICS

    ANALYTICS --> REVENUE
    ANALYTICS --> ACTIVITY
    ANALYTICS --> PRODUCTS

    ANALYTICS --> GROWTH
```

---

# 🧩 Application Structure

```text
Karigari_app/
│
├── assets/
│   └── images/
│
├── screenshots/
│   └── karigari_showcase.gif
│
├── lib/
│   │
│   ├── Authentication
│   │   ├── Buyer Login
│   │   └── Seller Login
│   │
│   ├── Buyer
│   │   ├── Product Catalogue
│   │   ├── Product Details
│   │   ├── Cart
│   │   ├── Checkout
│   │   └── AI Shopping Assistant
│   │
│   ├── Seller
│   │   ├── Seller Dashboard
│   │   ├── Seller Home
│   │   ├── Product Upload
│   │   ├── Orders
│   │   ├── Order Details
│   │   ├── Analytics
│   │   └── AI Growth
│   │
│   └── ...
│
├── android/
├── ios/
├── pubspec.yaml
└── README.md
```

> The application is organized around its buyer and seller experiences and their
> respective features rather than following a formal architecture pattern such
> as Clean Architecture or BLoC.

---

# 🛠️ Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| 📱 Frontend | Flutter + Dart | Mobile application |
| 🔐 Authentication | Firebase Authentication | User authentication |
| 🗄️ Database | Cloud Firestore | Products, orders & seller data |
| 🤖 AI | Firebase AI | Buyer & seller AI features |
| 🖼️ Media | Cloudinary | Product images |
| 💳 Payments | Razorpay | Payment processing |

---

# 📊 Seller Intelligence

Karigari turns commerce data into actionable information.

```mermaid
flowchart LR

    ORDERS["🧾 Orders"]
    DATA["📊 Data"]
    ANALYTICS["📈 Analytics"]
    INSIGHTS["✨ Insights"]
    ACTION["🚀 Action"]

    ORDERS --> DATA
    DATA --> ANALYTICS
    ANALYTICS --> INSIGHTS
    INSIGHTS --> ACTION
```

Seller analytics provide visibility into:

- Revenue
- Orders
- Order activity
- Product performance
- Strong-performing products
- Products without completed sales
- Growth opportunities

These insights can lead to:

**Insights → Actions → Listings → Campaigns**

---

# 🎨 Design Philosophy

### 🧵 Human

Handmade products are presented as more than inventory.

### ⚡ Simple

Complex technology stays behind a simple shopping and selling experience.

### 🧠 Intelligent

Data and AI should help users **make decisions and take action**.

---

# 🔐 Services

```mermaid
flowchart TB

    KARIGARI["📱 KARIGARI"]

    FIREBASE["🔥 Firebase"]
    AUTH["Authentication"]
    DB["Firestore"]
    AI["Firebase AI"]

    CLOUDINARY["☁️ Cloudinary"]
    RAZORPAY["💳 Razorpay"]

    KARIGARI --> FIREBASE
    KARIGARI --> CLOUDINARY
    KARIGARI --> RAZORPAY

    FIREBASE --> AUTH
    FIREBASE --> DB
    FIREBASE --> AI
```

---

# 🎯 Complete User Journey

## Buyer

```mermaid
flowchart LR

    ONBOARDING["Onboarding"]
    LOGIN["Sign In"]
    DISCOVER["Discover"]
    PRODUCT["Product"]
    CART["Cart"]
    CHECKOUT["Checkout"]
    PAYMENT["Razorpay"]
    CONFIRMED["Order Confirmed"]

    ONBOARDING --> LOGIN
    LOGIN --> DISCOVER
    DISCOVER --> PRODUCT
    PRODUCT --> CART
    CART --> CHECKOUT
    CHECKOUT --> PAYMENT
    PAYMENT --> CONFIRMED
```

## Seller

```mermaid
flowchart LR

    LOGIN["Seller Sign In"]
    HOME["Seller Home"]
    ORDER["New Order"]
    DETAILS["Order Details"]
    ANALYTICS["Analytics"]
    GROWTH["AI Growth"]

    LOGIN --> HOME
    HOME --> ORDER
    ORDER --> DETAILS
    DETAILS --> ANALYTICS
    ANALYTICS --> GROWTH
```

---

# 🚀 Getting Started

## Requirements

- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- Firebase project
- Cloudinary account
- Razorpay account

Check your Flutter setup:

```bash
flutter doctor
```

## Installation

```bash
git clone <your-repository-url>

cd Karigari_app

flutter pub get

flutter run
```

---

# 🔑 Configuration

Karigari requires configuration for:

```text
Firebase
├── Authentication
├── Firestore
└── Firebase AI

Cloudinary
└── Product Images

Razorpay
└── Payments
```

Add the required project configuration before running the application.

> ⚠️ Never commit production secrets or private API credentials to GitHub.

---

# 🎬 The Complete Loop

```mermaid
flowchart LR

    BUYER["🛍️ Buyer"]

    DISCOVER["Discover"]
    PURCHASE["Purchase"]

    SELLER["🎨 Seller"]

    ORDER["Order"]
    ANALYTICS["Analytics"]
    AI["✨ AI Growth"]

    BUYER --> DISCOVER
    DISCOVER --> PURCHASE
    PURCHASE --> ORDER

    ORDER --> SELLER
    SELLER --> ANALYTICS
    ANALYTICS --> AI

    AI --> SELLER
```

<div align="center">

### Discover → Purchase → Learn → Grow

<br>

## 🧵 KARIGARI

### Where Every Piece Tells a Handmade Story.

<br>

**Built with Flutter · Firebase · Firebase AI · Cloudinary · Razorpay**

</div>
# 🧵 Karigari

### *Where Every Piece Tells a Handmade Story*

Karigari is a full-stack e-commerce mobile application designed to connect **local artisans and handicraft makers with buyers** through a modern, accessible, and story-driven shopping experience.

The platform goes beyond simply selling products — it helps artisans showcase the **craft, culture, and story behind every handmade piece** while giving buyers an engaging way to discover authentic handicrafts.

---

## ✨ Features

### 🛍️ Buyer Experience

- Browse and discover handmade products
- Dynamic product listings
- Product details with pricing and images
- **"Story Behind the Craft"** section to connect buyers with artisans
- Shopping cart and checkout
- Secure online payments with **Razorpay**
- Order placement and tracking
- AI-powered shopping assistance
- Regional language support for a more accessible shopping experience

### 🎨 Seller Experience

- Seller dashboard for managing the shop
- Upload and manage products
- View incoming orders
- Order notifications
- Sales and revenue analytics
- AI-powered business insights
- AI-assisted product listing generation
- AI-assisted campaign generation
- Data-driven growth recommendations

### 🤖 AI-Powered Growth

Karigari uses AI not only to assist buyers but also to help artisans grow their businesses.

The seller can:

- Generate growth insights from shop data
- Identify high-performing products
- Find products that need more attention
- Get actionable growth recommendations
- Generate product listings with AI
- Create promotional campaign ideas

This creates a continuous loop:

**Discover → Buy → Analyze → Improve → Grow**

---

## 🌍 Regional Accessibility

Karigari is designed with accessibility in mind, including **regional language support** to make digital commerce easier for artisans and buyers from different parts of India.

---

## 💳 Payments

Karigari integrates **Razorpay** for online payments, providing a seamless checkout experience for buyers.

The application supports:

- Online payments
- Payment confirmation
- Order creation after successful payment
- Order data storage in Firebase

---

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform mobile application |
| **Dart** | Application development |
| **Firebase Authentication** | User authentication |
| **Cloud Firestore** | Product, user and order data |
| **Firebase AI** | AI-powered insights and generation |
| **Cloudinary** | Product image storage |
| **Razorpay** | Online payment processing |
| **Easy Localization** | Regional language support |

---

## 🏗️ Architecture

Karigari follows a full-stack mobile application architecture:

```text
                    ┌─────────────────────┐
                    │       KARIGARI      │
                    │   Flutter Mobile UI │
                    └──────────┬──────────┘
                               │
             ┌─────────────────┼─────────────────┐
             │                 │                 │
             ▼                 ▼                 ▼
      Firebase Auth      Cloud Firestore    Cloudinary
      User Login         Products/Orders    Product Images
      & Accounts         Seller Data
             │
             │
             ▼
       Firebase AI
       AI Assistant
       Seller Insights
       AI Listings
       AI Campaigns
             │
             ▼
          Razorpay
       Online Payments
# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Primary Users: Market shoppers and local residents in Ligao City, Albay.
Situation & Job: Browsing, navigating, and locating stalls, specific ingredients, fresh produce, and services inside Ligao City Public Market; requesting assistance via AI chatbot ("Kado") and reporting stall information issues. Secondary role for Market Administrators managing stall directories and user reports.

## Product Purpose

MerkadoGo is an interactive public market directory, navigation helper, and AI assistant dedicated to Ligao City Public Market. It exists to eliminate confusion when shopping in a large municipal market by digitizing stall locations, offering ingredient-to-stall search, providing real-time AI assistance, and maintaining an accurate stall directory. Success means shoppers quickly find what they need with minimal friction.

## Positioning

The definitive digital market guide specifically engineered for Ligao City Public Market, featuring real-time interactive stall mapping, ingredient-level search (e.g. searching "pork chop" or "sinigang mix" maps to exact section/stall), and a localized AI chatbot assistant ("Kado").

## Operating Context

- Mobile Android environments (smartphones used while walking inside or planning a visit to Ligao City Public Market).
- Low/variable connectivity in crowded market areas.
- Physical walking navigation between market sections (Pork, Poultry, Beef, Vegetables, Fruits, Dry Goods, etc.).

## Capabilities and Constraints

- **Platform**: Android only (API level 21+).
- **Backend Services**: Firebase Auth (Email/Password + Verification), Cloud Firestore, Firebase Cloud Messaging (FCM).
- **Image Storage**: Cloudinary (unsigned uploads for stall photos and profile pictures; no Firebase Storage).
- **Navigation & Search**: Google Maps Flutter, Google Places API, stall category filtering, product/ingredient search.
- **AI Assistant**: Gemini 1.5 Pro ("Kado") providing market-specific guidance and contextual Q&A.
- **Constraints**: No iOS support required; no phone/SMS OTP authentication; flat design UI rules strictly enforced (no drop shadows, consistent iconography, clean typography).

## Brand Commitments

- **Name**: MerkadoGo (or MERKADO GO).
- **Visual Branding**: Primary Forest/Emerald Green (`#1B5E20`), Red Accent (`#E53935`), Neutral Dark (`#1A241A`), Neutral Light/White.
- **Logo Asset**: `assets/icons/MerkadoGo_Transparent Logo.png`.
- **Typography**: Two-tone "Merkado" (White or `#1B5E20`) + "Go" (`#E53935`) in Poppins w800 for main branding; DM Sans for section headings and UI titles.
- **AI Persona**: "Kado", a friendly, knowledgeable local market guide.

## Evidence on Hand

- Project source repository at `R:\Code\MerkadoGo`.
- Brand asset `assets/icons/MerkadoGo_Transparent Logo.png`.
- Scene and UI illustrations (`assets/images/sign-in_illustration.png`, `signup_illustration.png`, `forgot_password_illustration.png`, `email_verification_illustration.png`).
- Firestore schema definitions for `users`, `stalls`, `reports`, `usernames`.

## Product Principles

1. **Clarity First**: Information density must never obscure quick decision-making while walking through the market.
2. **Local Relevance**: Terminology, categories, and AI responses reflect authentic Ligao City Public Market structures and products.
3. **Flat & Professional Civic Craft**: Clean modern typography, high contrast, explicit states (loading, success, error), zero unnecessary visual noise.
4. **Predictable Navigation**: Persistent layout structures, responsive split-panel desktop/mobile adaptivity for auth, and zero layout shifts.

## Accessibility & Inclusion

- High contrast text ratio (4.5:1 minimum).
- Clear touch target sizing (minimum 48×48 px).
- Readable fonts (DM Sans & Poppins) with clean hierarchy.

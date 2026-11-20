# DARB Design System

Version: 1.0  
Scope: Flutter mobile app (customer, driver, vendor, administration)  
Source of truth: `mobile-overrides/design_system.dart`

This document records the design tokens already implemented in the app and defines how new and revised screens must use them. It does not authorize changing product behavior or backend contracts.

## Product principles

- Arabic-first experience with correct RTL layout; English and Turkish remain supported.
- Clear primary action on every screen. Avoid competing calls to action.
- Use real API data. Never fill empty screens with invented stores, orders, prices, ratings, or driver offers.
- Every network-driven screen must represent loading, success, empty, and recoverable error states.
- Keep forms short, validate before sending, and preserve entered data after recoverable failures.
- Maintain accessible contrast, readable touch targets, and responsive layouts for small Android devices.
- Separate API/business logic from presentation when adding or restructuring screens.
- Preserve authentication, package identity, release signing, and existing API contracts unless a separately reviewed change requires otherwise.

## Color tokens

| Token | Hex | Usage |
|---|---|---|
| forest | #102B26 | Primary brand, primary actions, headings on light surfaces |
| forestSoft | #1C443B | Secondary brand surfaces and dark hero gradients |
| mint | #B9E4D2 | Selected states and soft supporting surfaces |
| lime | #C8F169 | High-emphasis accent on dark backgrounds only |
| canvas | #F5F6F2 | Main application background |
| surface | #FFFFFF | Cards, sheets, fields |
| ink | #17231F | Main text |
| muted | #77837D | Secondary text and hints |
| line | #E4E9E3 | Dividers and subtle borders |
| borderStrong | #CBD5CE | Stronger boundaries |
| danger | #B94747 | Destructive actions and errors |
| success | #287A50 | Confirmed/success states |
| warning | #B7791F | Pending/attention states |
| info | #356D9A | Informational states |
| scrim | #990B1713 | Modal backdrops |

Do not introduce near-duplicate brand colors in individual screens. If a new semantic color is genuinely required, add it centrally to `DarbColors` and document its use.

## Spacing

Use the `DarbSpace` scale:
- xxs: 4
- xs: 8
- sm: 12
- md: 16
- lg: 20
- xl: 24
- xxl: 32
- section: 40

Prefer 16–20 px screen gutters, 12–16 px internal card spacing, and 24–40 px between major sections. Avoid arbitrary spacing values unless a specific visual alignment requires them.

## Shape and elevation

Use `DarbRadius`:
- sm: 12
- md: 16
- lg: 22
- xl: 28
- hero: 36
- pill: 999

Use `DarbElevation.card` for ordinary cards and `DarbElevation.floating` for floating/high-priority surfaces. Do not stack heavy shadows on every element. Prefer borders and tonal separation.

## Typography

Use the shared `DarbTheme.light` text theme:
- headlineLarge: 28 / 900
- headlineMedium: 23 / 900
- titleLarge: 19 / 800
- titleMedium: 15 / 700
- bodyLarge: 15
- bodyMedium: 13
- labelLarge: 13 / 800

Keep titles concise, body copy comfortably readable, and secondary labels visually subordinate. Avoid long all-bold paragraphs. Use localized strings through the existing localization helpers.

## Motion

Use `DarbMotion`:
- fast: 160 ms
- standard: 260 ms
- expressive: 420 ms
- enter: easeOutCubic
- exit: easeInCubic

Use motion to communicate state and hierarchy: screen transitions, selected navigation, expanding details, and confirmation feedback. Keep motion subtle and interruptible. Never delay a critical action for decorative animation.

## Components and interaction

- Primary action: `FilledButton`, one clear primary action per view.
- Secondary action: `OutlinedButton` or `TextButton`.
- Destructive action: use `DarbColors.danger` and require confirmation when consequential.
- Cards: white surface, 22 px default radius, subtle line, restrained elevation.
- Inputs: shared `InputDecorationTheme`; show validation beside the relevant field.
- Navigation: shared Material 3 `NavigationBar`; preserve role-specific destinations.
- Dialogs and sheets: shared `DarbTheme` shapes and surfaces.
- Loading: use a clear progress indicator or skeleton that matches the final content footprint.
- Empty: explain what is absent and offer a relevant next action where possible.
- Error: explain the failure in user language and provide retry without discarding user input.
- Success: confirm the completed action and make the next step clear.

## Role-specific information architecture

### Customer
Home, store discovery, store catalog, cart/checkout, independent parcel delivery, active orders, order history, saved addresses, account and support.

### Driver
Availability and online status, available delivery requests, fare/offer flow where supported by the API, active deliveries, pickup/drop-off progression, delivery history, account.

### Vendor
Store status, incoming orders, order detail and status progression, product catalog, account.

### Administration
Pending vendor/driver approvals, delivery-zone and fee configuration, operational order visibility, account. Do not expose administrative capabilities to non-admin roles.

## RTL and localization

- Use the app's existing locale state and localization helper.
- Let directional layout follow the active locale; do not hard-code left/right for semantic navigation.
- Phone numbers, email addresses, URLs, and numeric identifiers should retain appropriate LTR direction.
- Do not remove Arabic, English, or Turkish support while redesigning screens.

## Architecture and quality gates

- Keep widgets focused on rendering and interaction.
- Move API orchestration, validation, and state transitions into dedicated controllers/services when refactoring.
- Do not duplicate endpoint strings or business rules across screens.
- Preserve current endpoint payloads until backend compatibility is verified.
- Run `flutter analyze` and the available tests before publishing.
- A UI phase is not complete until tested on a real device for RTL, small screens, loading, empty, error, and success states.
- Build a signed APK with the existing release keystore and a versionCode greater than the installed version. Never ask the user to uninstall the working app as a routine update step.

## Current implementation notes

The current token implementation lives in `mobile-overrides/design_system.dart`. This document is aligned to that file. If tokens change, update both locations in the same reviewed change.

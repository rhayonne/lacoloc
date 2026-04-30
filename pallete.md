---
colors:
  surface: '#f6fafd'
  surface-dim: '#d6dade'
  surface-bright: '#f6fafd'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f4f8'
  surface-container: '#eaeef2'
  surface-container-high: '#e5e9ec'
  surface-container-highest: '#dfe3e6'
  on-surface: '#181c1f'
  on-surface-variant: '#3e484e'
  inverse-surface: '#2c3134'
  inverse-on-surface: '#edf1f5'
  outline: '#6e797f'
  outline-variant: '#bec8cf'
  surface-tint: '#006685'
  primary: '#006685'
  on-primary: '#ffffff'
  primary-container: '#31a2cc'
  on-primary-container: '#003445'
  inverse-primary: '#6dd2fe'
  secondary: '#795900'
  on-secondary: '#ffffff'
  secondary-container: '#fec330'
  on-secondary-container: '#6f5100'
  tertiary: '#3c6a00'
  on-tertiary: '#ffffff'
  tertiary-container: '#70a636'
  on-tertiary-container: '#1c3600'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#bfe9ff'
  primary-fixed-dim: '#6dd2fe'
  on-primary-fixed: '#001f2a'
  on-primary-fixed-variant: '#004d65'
  secondary-fixed: '#ffdfa0'
  secondary-fixed-dim: '#f8bd2a'
  on-secondary-fixed: '#261a00'
  on-secondary-fixed-variant: '#5c4300'
  tertiary-fixed: '#b8f47a'
  tertiary-fixed-dim: '#9dd761'
  on-tertiary-fixed: '#0e2000'
  on-tertiary-fixed-variant: '#2c5000'
  background: '#f6fafd'
  on-background: '#181c1f'
  surface-variant: '#dfe3e6'
typography:
  display-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  display-md:
    fontFamily: Be Vietnam Pro
    fontSize: 36px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 30px
    fontWeight: '600'
    lineHeight: '1.3'
  headline-md:
    fontFamily: Be Vietnam Pro
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  title-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Be Vietnam Pro
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-md:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Be Vietnam Pro
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  3xl: 64px
---

## Brand & Style

This design system is built on the principles of clarity and utility. It aims to evoke a sense of reliability and professional competence through a structured visual language. The style is categorized as **Corporate / Modern**, leaning heavily into high-readability typography and a solid, intentional color application.

The target audience consists of professionals who value efficiency and precision. To meet their expectations, the UI prioritizes functional density and logical information architecture over decorative flourishes. Whitespace is used as a tool for grouping and separation, ensuring that even data-heavy interfaces remain approachable and easy to navigate.

## Colors

The color palette is derived from a quartet of solid, foundational hues that represent different functional states and brand pillars. 

- **Primary (Blue):** Used for main actions, navigation, and primary branding. It conveys stability and trust.
- **Secondary (Yellow):** Used for warnings, highlights, and attention-grabbing elements that require caution.
- **Tertiary (Green):** Reserved for success states, "go" actions, and positive growth metrics.
- **Quaternary (Orange):** Utilized for alerts, interactive secondary accents, or energetic call-outs.

The neutral scale uses a Slate-inspired palette to maintain a cool, professional temperature across the interface. Backgrounds are kept slightly off-white to reduce eye strain and improve the perceived depth of elevated components.

## Typography

The typography system relies exclusively on **Be Vietnam Pro** to provide a contemporary and approachable feel without sacrificing professional rigor. The type scale is designed for high readability in complex applications.

Bold weights are used sparingly for headlines to establish a clear information hierarchy. Body text is set with generous line heights (1.6) to facilitate scanning and long-form reading. Labels and utility text use medium weights (500) and slight letter-spacing to ensure legibility at smaller sizes.

## Layout & Spacing

This design system employs a strict 8px grid (spacing_base) to ensure mathematical harmony across all components and page layouts. 

The layout model is a **Fixed-Fluid Hybrid**: the content container centers itself and scales up to a maximum width of 1280px on desktop, while maintaining a 12-column grid. Gutters and margins are fixed to provide a consistent visual "breath" between content modules. 

For internal component padding, the 'md' (16px) unit is the default standard for spacing between elements, while 'sm' (8px) is used for tighter related groups like icon-and-label pairs.

## Elevation & Depth

Visual hierarchy is conveyed through **Ambient Shadows** and tonal layering. The design system avoids flat aesthetics in favor of a tactile, layered feel that makes interactive elements feel "plucked" from the surface.

- **Low Elevation (Resting):** Interactive elements like cards and buttons feature a subtle 1px border combined with a soft, low-opacity shadow (4-8% opacity) to distinguish them from the background.
- **Medium Elevation (Hover):** Upon interaction, shadows expand and slightly darken to provide clear feedback that an element is "lifted" and ready for activation.
- **High Elevation (Modals/Menus):** Large surfaces like modals use multi-layered shadows with a larger blur radius to create a distinct physical separation from the main content.

Shadow colors should be slightly tinted with the neutral navy tone (`#1E293B`) rather than pure black to maintain a sophisticated, professional look.

## Shapes

The shape language is defined as **Rounded**, striking a balance between the clinical feel of sharp corners and the overly casual nature of pill shapes. 

Standard components (buttons, inputs, cards) use a 0.5rem (8px) corner radius. This consistency creates a unified "container" language across the entire system. For larger surfaces like containers or dashboard panels, the radius may be increased to 1rem (16px) to emphasize the structural enclosure of information.

## Components

### Buttons
Buttons are the primary vehicle for action. Primary buttons use the brand blue with white text and a subtle drop shadow. Secondary buttons use a neutral outline or light gray fill. On hover, buttons should shift elevation upward using an expanded shadow rather than a simple color change.

### Input Fields
Fields feature a subtle gray border and a white background. Upon focus, the border color shifts to the primary blue, and a soft outer glow (using the primary color at 10% opacity) appears to signify active status. Labels are always placed above the field in `label-md` for maximum clarity.

### Cards
Cards are the core organizational unit. They use a white background, the standard 8px border radius, and a low elevation shadow. Card headers should use `title-lg` to clearly define the content within.

### Chips & Tags
Used for categorization, chips use the secondary, tertiary, or quaternary colors with highly desaturated backgrounds (10-15% opacity) and full-strength text color to ensure accessibility while adding visual variety.

### Lists
Lists are treated with horizontal dividers in a very light neutral tint. Interactive list items should have a subtle background hover state using the neutral-50 (lightest gray) to highlight the selection.
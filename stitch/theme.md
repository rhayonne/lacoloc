---
name: Lumière Long-Term
colors:
  surface: '#f7fafc'
  surface-dim: '#d7dadc'
  surface-bright: '#f7fafc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f4f6'
  surface-container: '#ebeef0'
  surface-container-high: '#e5e9eb'
  surface-container-highest: '#e0e3e5'
  on-surface: '#181c1e'
  on-surface-variant: '#3d4948'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eef1f3'
  outline: '#6d7a78'
  outline-variant: '#bcc9c7'
  surface-tint: '#006a66'
  primary: '#006a66'
  on-primary: '#ffffff'
  primary-container: '#38b2ac'
  on-primary-container: '#003f3d'
  inverse-primary: '#66d8d2'
  secondary: '#944b00'
  on-secondary: '#ffffff'
  secondary-container: '#fe9743'
  on-secondary-container: '#6b3500'
  tertiary: '#00629d'
  on-tertiary: '#ffffff'
  tertiary-container: '#53a7f0'
  on-tertiary-container: '#003b61'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#84f5ee'
  primary-fixed-dim: '#66d8d2'
  on-primary-fixed: '#00201e'
  on-primary-fixed-variant: '#00504d'
  secondary-fixed: '#ffdcc5'
  secondary-fixed-dim: '#ffb783'
  on-secondary-fixed: '#301400'
  on-secondary-fixed-variant: '#703700'
  tertiary-fixed: '#cfe5ff'
  tertiary-fixed-dim: '#99cbff'
  on-tertiary-fixed: '#001d34'
  on-tertiary-fixed-variant: '#004a78'
  background: '#f7fafc'
  on-background: '#181c1e'
  surface-variant: '#e0e3e5'
typography:
  h1:
    fontFamily: Be Vietnam Pro
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  h2:
    fontFamily: Be Vietnam Pro
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: -0.01em
  h3:
    fontFamily: Be Vietnam Pro
    fontSize: 24px
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
    lineHeight: '1.5'
  label-caps:
    fontFamily: Be Vietnam Pro
    fontSize: 12px
    fontWeight: '700'
    lineHeight: '1.0'
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 80px
  container-max: 1200px
  gutter: 24px
---

## Brand & Style

The design system is built to evoke a sense of clarity, reliability, and modern French living. The target audience includes students and young professionals seeking stability through long-term annual contracts (*contrats annuels*). 

The visual style is a blend of **Modern Minimalism** and **Airy Professionalism**. It prioritizes high legibility and breathability to reduce the stress associated with housing searches. By utilizing vast whitespace and a vibrant palette, the UI feels less like a transactional marketplace and more like a welcoming community gateway. The aesthetic emphasizes "Logement Durable" (Sustainable Housing) over temporary lodging.

## Colors

This design system utilizes a "Breezy Teal" (#38b2ac) as the primary anchor to signal trust and freshness. The background is strictly off-white (#f7fafc) to ensure the interface feels expansive and light. 

**Amber Accents** (#ed8936) are reserved for high-energy interactions and calls to action that drive the user toward long-term commitments, such as "Signer le bail" or "Déposer un dossier." A secondary "Sky Blue" (#4299e1) is used sparingly for informational elements and link states to maintain a professional, tech-forward appearance.

## Typography

This design system exclusively uses **Be Vietnam Pro** to achieve a contemporary and friendly tone. Headlines use a tight letter-spacing and heavy weights to provide a strong structural anchor for the brand. 

Body text is set with generous line heights to ensure readability during the review of complex rental agreements. The "Label-Caps" style is specifically designed for metadata regarding the property (e.g., "MEUBLÉ," "CHARGES COMPRISES"), ensuring that essential rental terms are immediately scannable.

## Layout & Spacing

The design system employs a **Fixed Grid** approach for desktop (12-column, 1200px max-width) and a fluid single-column layout for mobile. A strict 8px spacing scale ensures consistency. 

Generous "Air Pockets" (using the `lg` and `xl` spacing tokens) are mandated between sections to maintain the "airy" brand promise. Vertical rhythm should prioritize grouping related contract details tightly while separating distinct property features with significant whitespace.

## Elevation & Depth

To maintain a light and vibrant feel, this design system avoids heavy, muddy shadows. Instead, it uses **Ambient Tints**. 

Depth is created through two methods:
1.  **Subtle Surface Tiers:** The main background is #f7fafc, while interactive cards and containers are pure #ffffff. 
2.  **Soft Teal Shadows:** Elevations use extremely low-opacity shadows (4-8%) that are slightly tinted with the primary teal color rather than pure black. This keeps the "glow" of the UI clean and energetic. High-elevation elements (like modal dialogs) use a larger blur radius (24px+) with a very light diffusion.

## Shapes

The design system utilizes **Rounded** geometry (0.5rem base) to convey friendliness and safety. 

Cards and large containers should use `rounded-lg` (1rem) or `rounded-xl` (1.5rem) to soften the interface. Interactive elements like search bars and primary buttons benefit from these generous radii to feel approachable. Hard 90-degree angles are strictly avoided to distance the brand from traditional, "stiff" real estate corporate identities.

## Components

### Buttons & Inputs
*   **Primary Action:** Use the Amber accent (#ed8936) with white text for main conversion points like "Candidater."
*   **Secondary Action:** Use a ghost style with the Primary Teal (#38b2ac) border and text.
*   **Text Inputs:** Use white backgrounds with a subtle 1px border (#e2e8f0). On focus, the border transitions to the primary teal with a soft outer glow.

### Cards & Lists
*   **Property Cards:** Must emphasize the "Loyer Mensuel" (Monthly Rent) and the "Contrat Annuel" status. Remove all daily/nightly pricing indicators. Use a clean image-to-content ratio of 1:1.
*   **Amenity Chips:** Use a soft teal tint (5% opacity) background with teal text to indicate features like "Wi-Fi Haut Débit" or "Lave-linge."

### Long-Term Specific Components
*   **Timeline Tracker:** A vertical list component showing the steps of the annual contract process (Dossier, Visite, Signature, État des lieux).
*   **Document Vault:** A specialized list item with a "Secure" icon for uploading PDFs required for French rental dossiers (ID, Pay slips, etc.).
*   **Stability Badge:** A small, vibrant tag used on listings to indicate "Bail de 12 mois minimum" to reinforce the long-term focus.
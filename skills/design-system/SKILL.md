---
name: design-system
description: |
  Use when establishing a design system, choosing color palettes, defining typography,
  creating design tokens, setting spacing standards, writing a DESIGN.md document, or making
  foundational visual design decisions for a product. Triggers: "design system", "color palette",
  "typography", "design tokens", "brand", "visual design", "DESIGN.md", "spacing system",
  "what colors should I use", "font choice", "design language", "visual theme".
---

# Design System

Establish the foundational design language: tokens, color, typography, spacing, and motion philosophy.

**Core principle:** One coherent system, applied consistently. Design decisions made once, expressed everywhere.

## When to Use

- Starting a new product or major redesign
- Choosing color palette, typography, or spacing system
- Creating design tokens for a codebase
- Writing DESIGN.md to codify design decisions
- Evaluating whether UI is consistent with its design system

## When NOT to Use

- Building specific UI components (use ui-components skill)
- Reviewing visual quality of existing UI (use ui-components skill)
- Performance optimization of UI (use frontend-performance skill)

---

## Phase 1: Product Context Assessment

Before proposing a design system, answer:

1. **What is the product?** — Productivity tool, consumer app, developer tool, marketing site
2. **Who is the user?** — Enterprise knowledge worker, consumer, developer, creative professional
3. **What industry?** — Finance (trust, precision), Health (clarity, calm), Creative (expression, energy)
4. **What density?** — Information-dense dashboard vs. content-first editorial vs. e-commerce

---

## Phase 2: Visual Theme Axes

Rate on three axes to anchor all design decisions:

| Axis | Scale | Description |
|------|-------|-------------|
| **Density** | 1-10 | 1-3: Art Gallery Airy; 4-6: Balanced; 7-10: Cockpit Dense |
| **Variance** | 1-10 | 1-3: Predictable Symmetric; 7-10: Asymmetric Offset |
| **Motion** | 1-10 | 1-3: Static Restrained; 7-10: Cinematic Choreography |

---

## Design Preset Archetypes

When clients ask for a direction ("make it modern", "premium", "bold"), anchor to one of these named presets:

| Preset | Signature Traits | Best For |
|--------|-----------------|----------|
| **Minimalist Modern** | Whitespace-dominant, single accent, max 2 fonts, subtle 0-10% opacity shadows | SaaS, productivity, professional tools |
| **Bold Brutalist** | High contrast (black/white/red), raw typography 700-900 weight, zero border-radius, no decorative elements | Creative agencies, portfolios, bold brands |
| **Soft Neumorphic** | Inner shadows (light + dark), muted pastel palette, subtle depth, rounded 12-20px corners | Health, wellness, meditation apps |
| **Glass Aesthetic** | `backdrop-blur` + transparency, 1px inner border `border-white/10`, vivid single accent, layered surfaces | Fintech, premium dashboards, iOS-style apps |
| **Timeless Classic** | Serif display font, editorial grid, conservative 3-4 color palette, WCAG AAA accessible | Enterprise, government, accessibility-first |
| **Bleeding Edge Experimental** | Kinetic type, asymmetric layout, motion-first, unconventional grid (2fr 1fr), scroll-driven reveals | Tech showcases, innovation labs, creative portfolios |

---

## Phase 3: Color Palette

### 60-30-10 Color Rule

Every palette must allocate by visual weight:
- **60% dominant neutral** — backgrounds, surfaces, containers
- **30% secondary** — body text, borders, inactive states, supporting UI
- **10% accent** — CTAs, interactive focus, highlights, brand moments

### Mandatory Constraints

- Maximum **1 accent color** — saturation below 80%
- **Absolute neutral bases** — Zinc/Slate/Stone (no warm/cool gray fluctuation)
- **One palette** for the entire product — no per-section themes
- **Never pure black** (`#000000`) — use Zinc-950, Off-Black, or Charcoal
- **No neon AI aesthetic** — purple/indigo gradients, oversaturated accents banned

### WCAG 2.1 AA Minimum Contrast

| Text Type | Minimum Ratio |
|-----------|--------------|
| Normal text (<18pt) | 4.5:1 |
| Large text (18pt+ or 14pt bold) | 3:1 |
| UI components and icons | 3:1 |

### Palette Structure

```
Neutral scale:   50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950
Accent scale:    50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950
Semantic roles:  background, foreground, muted, border, primary, error, warning, success
```

---

## Phase 4: Typography

### Font Selection

Prefer distinctive fonts over generic defaults for premium contexts:
- **Display/Editorial:** Geist, Cabinet Grotesk, Satoshi, Outfit
- **UI/Product:** Inter, Geist, Plus Jakarta Sans
- **Monospace:** Geist Mono, JetBrains Mono, Fira Code

Generic fonts (`Arial`, `Helvetica`, system-ui` alone) are acceptable only for developer tools or ultra-minimal contexts.

### Type Scale

Use consistent increments:

```
12px — caption, label, badge
14px — body small, helper text
16px — body default (minimum on mobile)
18px — body large, lead text
24px — heading small (h3)
32px — heading medium (h2)
48px — heading large (h1)
64px — display
```

Use `clamp()` for responsive scaling:
```css
font-size: clamp(1.5rem, 3vw, 2rem);  /* scales between 24px and 32px */
```

### Typography Rules

| Element | Rule |
|---------|------|
| Display/Headlines | Track-tight (`letter-spacing: -0.02em`), weight for hierarchy not just size |
| Body text | Leading 1.5-1.75, max 65 characters per line |
| Mobile body | Minimum 16px (prevents browser zoom on iOS) |
| Heading hierarchy | h1→h2→h3 — no level skips |

---

## Phase 5: Spacing System

- **8pt grid — canonical scale:** 0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64px
- Use the 8pt grid as default; 4pt for fine-tuning within components
- **Proximity principle:** related elements 8-16px apart; section breaks 32-48px; page-level sections 64px+
- CSS Grid over Flexbox calc hacks
- Max-width containment: 1400px centered for content
- Touch targets minimum 44px on mobile

---

## Phase 6: Motion Philosophy

| Rule | Value |
|------|-------|
| Default physics | Spring: stiffness 100, damping 20 |
| Micro-interaction duration | 150-300ms |
| Maximum duration | 500ms |
| Animate only | `transform` and `opacity` — never `top`, `left`, `width`, `height` |
| Exit vs enter | Exit = 60-70% of enter duration |
| Reduced motion | Always respect `prefers-reduced-motion` |

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## Phase 7: Design Token Architecture

Three layers — never use raw values in components:

```
Primitive (raw values):   --color-blue-600: #2563EB
Semantic (purpose):       --color-action-primary: var(--color-blue-600)
Component (specific):     --button-bg: var(--color-action-primary)
```

**Name tokens by role, not color value:**

```
❌  --color-blue-500        (describes the color — breaks when brand changes)
✅  --color-action-primary  (Primary Action color — survives brand pivots)
✅  --color-feedback-error  (Error state — meaningful without knowing it's red)
✅  --color-surface-raised  (Elevated surface — not "white" or "gray-50")
```

```css
@layer base {
  :root {
    /* Primitives */
    --color-zinc-950: #09090b;
    --color-zinc-50: #fafafa;
    --color-blue-600: #2563eb;

    /* Semantic */
    --background: var(--color-zinc-50);
    --foreground: var(--color-zinc-950);
    --primary: var(--color-blue-600);
    --muted: 210 40% 96.1%;  /* HSL for Tailwind compatibility */
  }

  .dark {
    --background: var(--color-zinc-950);
    --foreground: var(--color-zinc-50);
  }
}
```

---

## DESIGN.md Output

```markdown
# Design System: [Project Title]

## 1. Visual Theme & Atmosphere
- Density: X/10 — [description]
- Variance: X/10 — [description]
- Motion: X/10 — [description]

## 2. Color Palette & Roles
- Neutral base: Zinc/Slate/Stone [chosen scale]
- Accent: [color name, hex, usage]
- Semantic roles: background, foreground, primary, muted, error, success, warning

## 3. Typography
- Display: [font name], track-tight
- Body: [font name], 1.6 leading, max 65ch
- Scale: 12/14/16/18/24/32/48px

## 4. Spacing
- System: 4pt base (4/8/12/16/24/32/48/64px)
- Max content width: 1400px

## 5. Motion
- Physics: spring(100, 20)
- Duration: 150-300ms
- Properties: transform + opacity only

## 6. Anti-Patterns (Banned)
- [Specific things that are never allowed in this product]
```

---

## Verification Checklist

- [ ] Max 1 accent color, saturation <80%
- [ ] No pure black (#000000) anywhere
- [ ] Neutral base consistent (no warm/cool gray mixing)
- [ ] WCAG 2.1 AA contrast verified (4.5:1 text, 3:1 UI)
- [ ] Type scale uses consistent increments
- [ ] Mobile body text ≥16px
- [ ] Spacing system documented (4pt grid)
- [ ] Motion only uses transform + opacity
- [ ] `prefers-reduced-motion` respected
- [ ] Design tokens follow primitive → semantic → component hierarchy
- [ ] No raw hex values in component code
- [ ] DESIGN.md written and covers all 6 sections

---
name: expo-tailwind
description: "Use when setting up or using Tailwind CSS in Expo or React Native projects with NativeWind v5 and react-native-css for universal styling across iOS, Android, and web. Covers Metro config setup, PostCSS configuration, CSS component wrappers, platform-specific styles, Apple system colors, and dark mode. Triggers: \"NativeWind\", \"Tailwind Expo\", \"Tailwind React Native\", \"react-native-css\", \"Tailwind mobile\", \"Expo Tailwind setup\", \"NativeWind v5\", \"Tailwind v4 Expo\", \"universal styling\", \"Tailwind iOS\", \"Tailwind Android\"."
---

# Expo + Tailwind CSS (NativeWind v5)

## When to Use

- Setting up Tailwind CSS v4 in a new or existing Expo / React Native project
- Adding `className` support to React Native components via `react-native-css`
- Configuring platform-specific styles, Apple system colors, or dark mode for iOS/Android/web
- Migrating from NativeWind v4 / Tailwind v3 to the CSS-first v4 stack

## When NOT to Use

- Broader Expo project patterns (routing, navigation, app structure) — use `expo-app-design`
- Design token architecture, theming systems, or multi-brand token pipelines — use `design-system`

---

## Package Installation

```bash
npx expo install tailwindcss@^4 nativewind@5.0.0-preview.2 \
  react-native-css@0.0.0-nightly.5ce6396 @tailwindcss/postcss \
  tailwind-merge clsx
```

Add to `package.json` for lightningcss compatibility (`autoprefixer` is NOT needed — lightningcss handles it; `postcss` ships with Expo):

```json
{
  "resolutions": {
    "lightningcss": "1.30.1"
  }
}
```

**No `babel.config.js` needed.** Remove any NativeWind babel presets — v5 is CSS-first.

---

## Metro Config

```js
// metro.config.js
const { getDefaultConfig } = require("expo/metro-config");
const { withNativewind } = require("nativewind/metro");

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

module.exports = withNativewind(config, {
  inlineVariables: false,      // inline variables break PlatformColor in CSS vars
  globalClassNamePolyfill: false, // className support added manually via useCssElement
});
```

---

## PostCSS Config

```js
// postcss.config.mjs
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

---

## global.css

```css
/* src/global.css */
@import "tailwindcss";

/* Custom theme tokens */
@theme {
  /* Fonts */
  --font-rounded: "SF Pro Rounded", sans-serif;

  /* Custom line heights */
  --text-xs--line-height: calc(1em / 0.75);
  --text-sm--line-height: calc(1.25em / 0.875);
  --text-base--line-height: calc(1.5em / 1);

  /* Register Apple system colors as Tailwind utilities */
  --color-sf-blue:    var(--sf-blue);
  --color-sf-green:   var(--sf-green);
  --color-sf-red:     var(--sf-red);
  --color-sf-text:    var(--sf-text);
  --color-sf-text-2:  var(--sf-text-2);
  --color-sf-bg:      var(--sf-bg);
  --color-sf-bg-2:    var(--sf-bg-2);
}

/* Platform-specific font defaults */
@media ios {
  :root {
    --font-mono:    ui-monospace;
    --font-serif:   ui-serif;
    --font-sans:    system-ui;
    --font-rounded: ui-rounded;
  }
}

@media android {
  :root {
    --font-mono:    monospace;
    --font-rounded: normal;
    --font-serif:   serif;
    --font-sans:    normal;
  }
}
```

Import this file in your app entry point (e.g., `app/_layout.tsx`):

```ts
import "@/src/global.css";
```

---

## `useCssElement` Pattern

`react-native-css` requires explicit wrapping so `className` is resolved to a `style` prop at runtime. The second argument maps `className` props to their style prop equivalents.

```tsx
// src/tw/index.tsx
import { useCssElement } from "react-native-css";
import {
  View as RNView,
  Text as RNText,
  Pressable as RNPressable,
  ScrollView as RNScrollView,
  TextInput as RNTextInput,
} from "react-native";

export const View = (
  props: React.ComponentProps<typeof RNView> & { className?: string }
) => useCssElement(RNView, props, { className: "style" });

export const Text = (
  props: React.ComponentProps<typeof RNText> & { className?: string }
) => useCssElement(RNText, props, { className: "style" });

export const Pressable = (
  props: React.ComponentProps<typeof RNPressable> & { className?: string }
) => useCssElement(RNPressable, props, { className: "style" });

export const TextInput = (
  props: React.ComponentProps<typeof RNTextInput> & { className?: string }
) => useCssElement(RNTextInput, props, { className: "style" });

export const ScrollView = (
  props: React.ComponentProps<typeof RNScrollView> & {
    className?: string;
    contentContainerClassName?: string;
  }
) =>
  useCssElement(RNScrollView, props, {
    className: "style",
    contentContainerClassName: "contentContainerStyle",
  });
```

Import from `@/tw` instead of `react-native`. For `ScrollView`, `contentContainerClassName` maps to `contentContainerStyle`.

---

## Custom Theme Variables (`@theme {}`)

Define design tokens inside `@theme` in `global.css`. These become Tailwind utility classes automatically.

```css
@theme {
  --color-brand:        #6366f1;
  --color-brand-dark:   #4f46e5;
  --spacing-safe-top:   env(safe-area-inset-top);
  --radius-card:        16px;
}
```

Usage: `className="bg-brand rounded-card"`.

---

## Apple System Colors (`platformColor()`)

On iOS, use `platformColor()` inside `@media ios {}` to map CSS variables to native UIKit semantic colors. Provide `light-dark()` fallbacks for web and Android.

```css
/* src/css/sf.css  — import this in global.css */
:root {
  /* Web / Android fallbacks using light-dark() */
  --sf-blue:    light-dark(rgb(0 122 255),    rgb(10 132 255));
  --sf-green:   light-dark(rgb(52 199 89),    rgb(48 209 88));
  --sf-red:     light-dark(rgb(255 59 48),    rgb(255 69 58));
  --sf-text:    light-dark(rgb(0 0 0),        rgb(255 255 255));
  --sf-text-2:  light-dark(rgb(60 60 67 / 0.6), rgb(235 235 245 / 0.6));
  --sf-bg:      light-dark(rgb(255 255 255),  rgb(0 0 0));
  --sf-bg-2:    light-dark(rgb(242 242 247),  rgb(28 28 30));
}

/* iOS: swap to native UIKit colors */
@media ios {
  :root {
    --sf-blue:   platformColor(systemBlue);
    --sf-green:  platformColor(systemGreen);
    --sf-red:    platformColor(systemRed);
    --sf-text:   platformColor(label);
    --sf-text-2: platformColor(secondaryLabel);
    --sf-bg:     platformColor(systemBackground);
    --sf-bg-2:   platformColor(secondarySystemBackground);
  }
}
```

Common `platformColor()` values: `systemBlue`, `systemGreen`, `systemRed`, `systemOrange`, `systemYellow`, `systemPurple`, `systemGray`, `label`, `secondaryLabel`, `tertiaryLabel`, `systemBackground`, `secondarySystemBackground`, `systemGroupedBackground`.

---

## Platform-Specific Styles

Use `@media ios {}` and `@media android {}` blocks in CSS. Declarations outside any block serve as the web default.

```css
@media ios    { .card { border-radius: 16px; } }
@media android { .card { border-radius: 8px;  } }
```

---

## Dark Mode

Use CSS `color-scheme` and `prefers-color-scheme`. The `light-dark()` function on CSS variables handles switching automatically.

```css
@layer base {
  html { color-scheme: light dark; }
}

:root {
  --bg-surface: light-dark(#ffffff, #1c1c1e);
  --text-primary: light-dark(#000000, #ffffff);
}

@theme {
  --color-surface:  var(--bg-surface);
  --color-primary:  var(--text-primary);
}
```

On iOS, `platformColor()` handles dark mode natively — no extra CSS needed.

---

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| Dynamic class names don't apply | Class strings must be **static** — never build with string interpolation (`"bg-" + color`). Tailwind purges classes it cannot statically detect. |
| Class order matters | Later classes in a string win. Use `tailwind-merge` (`twMerge`) when merging props + defaults. |
| `inlineVariables: true` in Metro config | Breaks `platformColor()` in CSS variables. Keep it `false`. |
| Missing `useCssElement` wrapper | Component ignores `className` silently. Every component that uses `className` must be wrapped. |
| Babel NativeWind preset still present | Conflicts with v5 CSS-first approach. Remove `nativewind/babel` and `jsxImportSource: "nativewind"` from `babel.config.js`. |
| `autoprefixer` in PostCSS config | Not needed — lightningcss handles vendor prefixes. Adding it may cause conflicts. |
| Global CSS not imported at app entry | Styles never load. Confirm `import "@/src/global.css"` is in `app/_layout.tsx` or equivalent root. |

---

## Verification Checklist

- [ ] `tailwindcss@^4`, `nativewind@5.x`, `react-native-css`, `@tailwindcss/postcss` installed
- [ ] `lightningcss` resolution pinned in `package.json`
- [ ] `metro.config.js` wraps config with `withNativewind({ inlineVariables: false, globalClassNamePolyfill: false })`
- [ ] `postcss.config.mjs` uses `@tailwindcss/postcss` (not `tailwindcss`)
- [ ] `global.css` starts with `@import "tailwindcss"` and defines `@theme` tokens
- [ ] Global CSS imported at app entry point
- [ ] All components using `className` are wrapped with `useCssElement`
- [ ] Apple system colors defined with `platformColor()` inside `@media ios {}` blocks
- [ ] Web/Android color fallbacks use `light-dark()` outside the iOS media block
- [ ] No dynamic class name construction (all class strings are static)
- [ ] NativeWind babel preset removed from `babel.config.js` (or no babel config at all)

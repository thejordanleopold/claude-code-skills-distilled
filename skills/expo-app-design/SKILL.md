---
name: expo-app-design
description: |
  Use when building mobile or universal apps with Expo and Expo Router. Covers file-based
  routing, native tabs, form sheets, Reanimated animations, scroll-driven effects, media
  handling, storage patterns, visual effects (blur, glass), 3D graphics, and platform-
  specific design patterns for iOS and Android. Triggers: "Expo", "Expo Router", "React
  Native UI", "native tabs", "form sheet", "native navigation", "Expo app", "mobile UI",
  "React Native animations", "expo-image", "native modal", "Reanimated", "expo-blur",
  "expo-sqlite", "SF Symbols", "Apple design".
---

# Expo App Design

## When to Use

- Building mobile or universal apps with Expo and Expo Router
- Implementing native navigation: tabs, stacks, modals, form sheets
- Adding animations, visual effects, or platform-specific behaviors to React Native apps
- Working with native iOS/Android UI conventions (SF Symbols, haptics, blur, glass)

## When NOT to Use

- **Tailwind styling setup** — use `expo-tailwind` skill
- **Framer Motion or web animations** — use `animation` skill (web-only)
- **React Native performance optimization** (FlatList, Hermes, JS thread) — use `react-native` skill

---

## Expo Go vs Custom Builds

**Always try Expo Go first** (`npx expo start`). It supports all `expo-*` packages, Expo Router, Reanimated, Gesture Handler, and push notifications out of the box.

Only use `npx expo run:ios` / `npx expo run:android` when you need:
- Local Expo modules (`modules/` with custom native code)
- Apple targets (widgets, app clips via `@bacons/apple-targets`)
- Third-party native modules not bundled in Expo Go

---

## Expo Router: File-Based Routing

```
app/
  _layout.tsx          — Root layout (NativeTabs, Theme provider)
  (index,search)/
    _layout.tsx        — Stack shared by both tabs
    index.tsx
    search.tsx
  i/[id].tsx           — Dynamic route
```

- Never co-locate components, types, or utilities in `app/`
- Always define stacks in `_layout.tsx` — never inline in screens
- App must always have a route matching `/`
- Use kebab-case filenames; remove old route files when restructuring

---

## Native Tabs with SF Symbols

```tsx
// app/_layout.tsx
import { NativeTabs, Icon, Label } from "expo-router/unstable-native-tabs";

export default function Layout() {
  return (
    <NativeTabs>
      <NativeTabs.Trigger name="(index)">
        <Icon sf="list.dash" />
        <Label>Items</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(search)" role="search" />
    </NativeTabs>
  );
}

// app/(index,search)/_layout.tsx
import { Stack } from "expo-router/stack";
import { PlatformColor } from "react-native";

export default function Layout({ segment }: { segment: string }) {
  const screen = segment.match(/\((.*)\)/)?.[1]!;
  const titles: Record<string, string> = { index: "Items", search: "Search" };
  return (
    <Stack
      screenOptions={{
        headerTransparent: true,
        headerLargeTitle: true,
        headerLargeStyle: { backgroundColor: "transparent" },
        headerTitleStyle: { color: PlatformColor("label") },
        headerShadowVisible: false,
        headerBackButtonDisplayMode: "minimal",
      }}
    >
      <Stack.Screen name={screen} options={{ title: titles[screen] }} />
      <Stack.Screen name="i/[id]" options={{ headerLargeTitle: false }} />
    </Stack>
  );
}
```

---

## Form Sheets / Modals

Navigate to sheets with `router.push()`. Configure in `_layout.tsx`:

```tsx
<Stack.Screen
  name="sheet"
  options={{
    presentation: "formSheet",
    sheetGrabberVisible: true,
    sheetAllowedDetents: [0.5, 1.0],
    contentStyle: { backgroundColor: "transparent" }, // liquid glass on iOS 26+
  }}
/>
```

For a basic modal: `presentation: "modal"`. Always prefer route-based sheets over custom modal components.

---

## Reanimated

```tsx
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring,
  useAnimatedScrollHandler, interpolate,
} from "react-native-reanimated";

// Press scale
const scale = useSharedValue(1);
const style = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));
// onPressIn: scale.value = withSpring(0.96)
// onPressOut: scale.value = withSpring(1)

// Scroll-driven header
const scrollY = useSharedValue(0);
const onScroll = useAnimatedScrollHandler((e) => { scrollY.value = e.contentOffset.y; });
const headerStyle = useAnimatedStyle(() => ({
  opacity: interpolate(scrollY.value, [0, 80], [1, 0]),
}));
```

Add entering/exiting animations for state changes. Use `withSpring` for natural feel.

---

## expo-image (Preferred Over `<Image>`)

```tsx
import { Image } from "expo-image";

// Remote with blur placeholder
<Image
  source={{ uri: "https://example.com/photo.jpg" }}
  placeholder={{ blurhash: "L6PZfSi_.AyE_3t7t7R**0o#DgR4" }}
  contentFit="cover"
  style={{ width: 200, height: 200, borderRadius: 12 }}
/>

// SF Symbol (iOS native icon)
<Image source="sf:star.fill" style={{ width: 24, height: 24, tintColor: "#FFD700" }} />
```

Never use the RN `<Image>` component or `<img>` element. Use `contentFit` not `resizeMode`.

---

## Storage: When to Use Each

| Data type | Package |
|---|---|
| Structured relational data | `expo-sqlite` |
| Simple key-value (non-sensitive) | `@react-native-async-storage/async-storage` |
| Sensitive data (tokens, secrets) | `expo-secure-store` |

Never use `AsyncStorage` from `react-native` core (removed) or `expo-permissions` (legacy).

---

## Visual Effects

```tsx
import { BlurView } from "expo-blur";
// Frosted overlay
<BlurView intensity={60} tint="systemMaterial" style={StyleSheet.absoluteFill} />

import { GlassView } from "expo-glass-effect";
// Liquid glass (iOS 26+) — pair with transparent sheet contentStyle
<GlassView style={{ flex: 1, borderRadius: 20 }}>
  <SheetContent />
</GlassView>
```

---

## Platform-Specific Patterns

```tsx
// Tree-shakeable platform detection
if (process.env.EXPO_OS === "ios") { /* iOS only */ }

// Semantic colors that adapt to dark mode
import { PlatformColor } from "react-native";
const color = PlatformColor("label");

// Haptics — guard to iOS only
import * as Haptics from "expo-haptics";
if (process.env.EXPO_OS === "ios") {
  await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
}
```

Prefer views with built-in haptics (`<Switch />`, `@react-native-community/datetimepicker`).

---

## Context Menus and Link Previews

Add `Link.Preview` and `Link.Menu` to navigable cards to follow iOS conventions:

```tsx
import { Link } from "expo-router";
<Link href="/item/123" asChild>
  <Link.Trigger><Pressable><Card /></Pressable></Link.Trigger>
  <Link.Preview />
  <Link.Menu>
    <Link.MenuAction title="Share" icon="square.and.arrow.up" onPress={handleShare} />
    <Link.MenuAction title="Delete" icon="trash" destructive onPress={handleDelete} />
  </Link.Menu>
</Link>
```

---

## Layout, Responsiveness, and Styling

- Use `<ScrollView contentInsetAdjustmentBehavior="automatic" />` — not `<SafeAreaView>`
- Apply `contentInsetAdjustmentBehavior="automatic"` to `FlatList` and `SectionList` too
- `useWindowDimensions()` over `Dimensions.get()` — reacts to orientation changes
- `contentContainerStyle` for padding on ScrollView (prevents clipping)
- Shadows: `boxShadow` CSS prop — never legacy `shadow*` or `elevation`
- `{ borderCurve: "continuous" }` for rounded corners (Apple squircle)
- `{ fontVariant: ["tabular-nums"] }` for numeric/counter text
- Always set `title` in `Stack.Screen options` — never a custom title element on the page
- Inline styles over `StyleSheet.create`; CSS/Tailwind not supported

---

## Hard Rules

- Never use `div` or `img` — use `View` and `expo-image`
- Never use removed RN modules: `Picker`, `WebView`, `SafeAreaView` (RN core), `AsyncStorage` (RN core)
- Never use `expo-av` — use `expo-audio` + `expo-video` separately
- Never use `expo-symbols` or `@expo/vector-icons` — use `expo-image` with `sf:` source
- Never use `Platform.OS` — use `process.env.EXPO_OS`
- Never co-locate components/utilities in `app/`

---

## Verification Checklist

- [ ] Expo Go used for development; custom build only when native modules required
- [ ] Routes in `app/`; no components co-located there
- [ ] `_layout.tsx` files define all stacks and tab layouts
- [ ] `NativeTabs` with `Icon sf=` for SF Symbols (not `@expo/vector-icons`)
- [ ] `expo-image` used for all images and SF Symbols
- [ ] `contentInsetAdjustmentBehavior="automatic"` on all ScrollView / FlatList / SectionList
- [ ] `process.env.EXPO_OS` used instead of `Platform.OS`
- [ ] Storage: correct package chosen (SQLite / AsyncStorage / SecureStore)
- [ ] No deprecated modules (Picker, WebView, SafeAreaView from RN core)
- [ ] Haptics guarded with `process.env.EXPO_OS === "ios"`
- [ ] Shadows use `boxShadow`, not legacy `shadow*` / `elevation`
- [ ] Form sheets use `presentation: "formSheet"` route config
- [ ] `Link.Preview` and `Link.Menu` added to navigable cards

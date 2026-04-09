---
name: animation
description: |
  Use when implementing animations, transitions, hover effects, page transitions, exit
  animations, scroll-linked animations, drag interactions, or motion design in React/Next.js.
  Triggers: "animation", "animate", "framer motion", "motion", "transition", "hover effect",
  "page transition", "AnimatePresence", "spring physics", "micro-interaction", "scroll
  animation", "exit animation", "layout animation", "shared element transition", "gesture".
---

# Animation

## When to Use

- Implementing any motion in React/Next.js: hover effects, page transitions, modals, drawers, toasts, lists, tabs, drag-and-drop
- Adding micro-interactions that respond to user gestures (tap, hover, drag, scroll)
- Orchestrating multi-element sequences (staggered lists, step wizards, shared element transitions)
- Replacing brittle CSS transitions with spring-physics or declarative state-driven motion

## When NOT to Use

- **Performance investigation** — if animation is causing jank, use `frontend-performance` instead
- **Automated interaction testing** — use `e2e-testing` to verify animated components behave correctly
- **Pure CSS hover states** on static marketing pages — plain CSS transitions are sufficient and have no JS overhead

---

## Core Concepts

### motion components + animate / initial / exit props

Convert any HTML element by prefixing `motion.`. The three essential props:

```tsx
import { motion } from "framer-motion";

// Fade-up on mount, fade-down on exit
<motion.div
  initial={{ opacity: 0, y: 16 }}
  animate={{ opacity: 1, y: 0 }}
  exit={{ opacity: 0, y: -8 }}
  transition={{ duration: 0.25, ease: [0.33, 1, 0.68, 1] }}
>
  Content
</motion.div>
```

- `initial` — state before mount (set `initial={false}` to skip mount animation)
- `animate` — target state; re-animates whenever value changes
- `exit` — state when removed from DOM (requires `<AnimatePresence>`)
- `transition` — timing for `animate`; nest inside gesture props for gesture-specific timing

Easing cheat sheet:

| Scenario | Easing | Duration |
|---|---|---|
| Element entering | `ease-out` | 200–300ms |
| Element moving on screen | `ease-in-out` | 200–300ms |
| Element exiting | `ease-in` | 150–200ms |
| Hover / tap | `ease` | 100–150ms |

---

### Variants + staggerChildren

Variants name animation states and propagate through the tree — children with matching keys animate automatically when the parent's state changes.

```tsx
const container = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { when: "beforeChildren", staggerChildren: 0.08 },
  },
  exit: {
    opacity: 0,
    transition: { when: "afterChildren", staggerChildren: 0.05, staggerDirection: -1 },
  },
};
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0 } };

<motion.ul variants={container} initial="hidden" animate="visible" exit="exit">
  {items.map((i) => (
    <motion.li key={i.id} variants={item}>{i.label}</motion.li>
  ))}
</motion.ul>
```

---

### Gestures: whileHover / whileTap / whileDrag / whileInView

```tsx
<motion.button
  whileHover={{ scale: 1.05, transition: { duration: 0.12 } }}
  whileTap={{ scale: 0.95 }}
>
  Click me
</motion.button>

// Drag with visual feedback
<motion.div
  drag
  dragConstraints={{ left: -120, right: 120, top: -60, bottom: 60 }}
  dragElastic={0.15}
  whileDrag={{ scale: 1.08, boxShadow: "0 12px 32px rgba(0,0,0,0.18)" }}
/>

// Trigger when scrolled into view
<motion.section
  initial={{ opacity: 0, y: 24 }}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, amount: 0.4 }}
  transition={{ duration: 0.35 }}
/>
```

The `transition` nested inside a gesture prop applies on gesture *start*; the root `transition` applies on gesture *end*.

---

### AnimatePresence + exit animations

`AnimatePresence` holds components in the DOM until their `exit` animation completes. Two rules:

1. The animating component must be a **direct child** of `<AnimatePresence>`.
2. Each child **must have a stable `key` prop** — this is how AnimatePresence tracks mount/unmount.

```tsx
import { AnimatePresence, motion } from "framer-motion";

// Modal
<AnimatePresence>
  {isOpen && (
    <motion.div
      key="modal"                          // required
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={{ duration: 0.2, ease: "easeOut" }}
    />
  )}
</AnimatePresence>

// Page transitions — key changes drive enter/exit
<AnimatePresence mode="wait">
  <motion.main
    key={pathname}
    initial={{ opacity: 0, x: 12 }}
    animate={{ opacity: 1, x: 0 }}
    exit={{ opacity: 0, x: -12 }}
    transition={{ duration: 0.22 }}
  />
</AnimatePresence>
```

`mode` options: `"sync"` (default, enter + exit overlap), `"wait"` (exit first), `"popLayout"` (exit pops out of flow).

---

### Layout animations + shared element transitions (layoutId)

Add `layout` to animate size/position changes caused by DOM reflow automatically. `layout="position"` or `layout="size"` restricts what gets animated. `layoutId` connects two elements across different render locations for a shared element transition:

```tsx
// Tab underline pill
{tabs.map((tab) => (
  <button key={tab} onClick={() => setActive(tab)} className="relative px-4 py-2">
    {tab}
    {active === tab && (
      <motion.div
        layoutId="tab-pill"
        className="absolute inset-0 rounded bg-blue-500 -z-10"
        transition={{ type: "spring", stiffness: 400, damping: 30 }}
      />
    )}
  </button>
))}
```

---

### Spring physics

Springs produce natural, interruptible motion. Four named presets:

| Preset | stiffness | damping | Feel |
|---|---|---|---|
| Gentle | 100 | 20 | Slow, smooth |
| Wobbly | 200 | 10 | Bouncy |
| Stiff | 400 | 30 | Snappy, little bounce |
| Slow | 50 | 20 | Molasses |

Custom spring:

```tsx
transition={{
  type: "spring",
  stiffness: 320,   // higher → faster, snappier
  damping: 24,      // higher → less bounce
  mass: 1,          // higher → more inertia
}}

// Or use perceived-duration API (simpler)
transition={{ type: "spring", visualDuration: 0.4, bounce: 0.2 }}
```

---

### Hooks: useAnimate / useSpring / useInView

```tsx
import { useAnimate, useSpring, useInView, stagger } from "framer-motion";
import { useRef } from "react";

// useAnimate — imperative, sequenced (await each step)
const [scope, animate] = useAnimate();
await animate(scope.current, { opacity: 1 });
await animate("li", { y: 0, opacity: 1 }, { delay: stagger(0.06) });

// useSpring — spring-driven motion value, great for pointer tracking
const x = useSpring(0, { stiffness: 300, damping: 22 });
// x.set(newValue) on pointer move; bind via <motion.div style={{ x }} />

// useInView — boolean flag; use for conditional rendering or class toggling
const ref = useRef(null);
const isInView = useInView(ref, { once: true, amount: 0.5 });
// <div ref={ref}>{isInView && <HeavyChart />}</div>
```

---

### useReducedMotion — accessibility

Always respect the OS-level reduced-motion preference:

```tsx
import { useReducedMotion, motion } from "framer-motion";

function FadeCard({ children }: { children: React.ReactNode }) {
  const reduce = useReducedMotion();
  return (
    <motion.div
      initial={{ opacity: 0, y: reduce ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: reduce ? 0 : 0.3 }}
    >
      {children}
    </motion.div>
  );
}
```

CSS alternative: `@media (prefers-reduced-motion: reduce) { * { transition: none !important; } }`

---

### Performance: only animate transform and opacity

GPU-composited — never trigger layout or paint:

| Safe to animate | Never animate |
|---|---|
| `x`, `y`, `scale`, `rotate`, `skew`, `opacity` | `left`, `top`, `width`, `height`, `margin`, `padding` |

```tsx
<motion.div animate={{ x: 100, opacity: 0.8 }} />   // GPU — good
<motion.div animate={{ left: 100, width: 200 }} />  // layout recalc — bad
```

---

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Missing `AnimatePresence` wrapper | `exit` prop silently ignored | Wrap conditional render in `<AnimatePresence>` |
| Missing or non-unique `key` on children | Elements don't animate out | Add stable `key={item.id}` to every AnimatePresence child |
| Animating layout properties | Jank at 60fps | Switch to `x`/`y`/`scale`; use `layout` prop for DOM reflow |
| Root `transition` on gesture end only | Hover feels instant | Put `transition` inside the gesture prop for enter timing |
| Overusing `layout` on long lists | Expensive per-frame FLIP reads | Apply `layout` only to the container or to items that actually reflow |
| Forgetting `useReducedMotion` | Accessibility violation, motion sickness | Check preference; reduce or disable non-essential motion |

---

## Verification Checklist

- [ ] Only `transform` and `opacity` are animated (no layout-triggering properties)
- [ ] Every conditional element inside `<AnimatePresence>` has a unique, stable `key`
- [ ] `exit` animation duration is ~75% of enter duration
- [ ] `useReducedMotion` disables or minimizes motion for users who prefer it
- [ ] Springs used for gesture-driven or interruptible animations (not tween)
- [ ] `viewport={{ once: true }}` set on `whileInView` unless repeat is intentional
- [ ] `layout` prop scoped to elements that actually change layout (not entire lists)
- [ ] No `console.error` from Framer Motion about missing `key` or `AnimatePresence`

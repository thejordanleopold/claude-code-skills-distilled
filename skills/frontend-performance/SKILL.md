---
name: frontend-performance
description: |
  Use when optimizing frontend performance, improving Core Web Vitals (LCP, INP, CLS),
  reducing JavaScript bundle size, fixing slow page loads, debugging React re-renders,
  implementing performance budgets, or setting up Lighthouse CI. Triggers: "slow page",
  "LCP", "INP", "CLS", "Core Web Vitals", "bundle size", "frontend performance", "re-renders",
  "Lighthouse", "page load", "large bundle", "layout shift", "interaction delay".
---

# Frontend Performance

Measure, diagnose, and fix frontend performance problems: Core Web Vitals, bundle size, and rendering.

**Core principle:** Never optimize without a measurement. Never ship an optimization without verifying it helped.

## When to Use

- Core Web Vitals are failing (LCP >4s, INP >200ms, CLS >0.1)
- JavaScript bundle is large (>200KB gzip)
- Page loads feel slow to users
- React components are re-rendering unnecessarily
- Setting up performance budgets and CI enforcement

## When NOT to Use

- Backend API latency (use backend-performance skill)
- Database query optimization (use backend-performance skill)
- Initial build without any measured performance problem

---

## Core Web Vitals Targets

| Metric | Good | Needs Work | Poor | Measures |
|--------|------|-----------|------|---------|
| **LCP** | ≤ 2.5s | 2.5-4.0s | > 4.0s | Loading performance |
| **INP** | ≤ 200ms | 200-500ms | > 500ms | Interactivity |
| **CLS** | ≤ 0.1 | 0.1-0.25 | > 0.25 | Visual stability |

---

## Profiling Tools

| Tool | What It Measures | When |
|------|-----------------|------|
| Chrome DevTools Performance | JS execution, paint, layout | Any rendering issue |
| Chrome DevTools Network | Waterfall, TTFB, resource size | Load time issues |
| Lighthouse | All Core Web Vitals | Overall audit |
| WebPageTest | Real browser, multiple locations | External user experience |
| webpack-bundle-analyzer / vite-bundle-visualizer | Bundle composition | Large bundle |
| React DevTools Profiler | Component render time, causes | React re-renders |

---

## LCP Optimization

LCP is almost always one of: hero image, large text block, video poster.

### Diagnose LCP Element

```javascript
new PerformanceObserver((list) => {
  const lcp = list.getEntries().at(-1);
  console.log('LCP element:', lcp.element, 'time:', lcp.startTime);
}).observe({ entryTypes: ['largest-contentful-paint'] });
```

### Fix by Root Cause

| Root Cause | Fix |
|-----------|-----|
| Slow server (high TTFB) | CDN, caching headers, server optimization |
| Large hero image | WebP/AVIF format, compress, add `fetchpriority="high"` |
| Image not preloaded | `<link rel="preload" as="image" href="hero.webp">` |
| Render-blocking CSS | Inline critical CSS, defer non-critical |
| Render-blocking JS | `defer` or `async` on non-critical scripts |
| Web font blocks render | `font-display: optional` or preload font |

```html
<!-- Preload LCP image -->
<link rel="preload" as="image" href="/hero.webp" fetchpriority="high">

<!-- LCP image markup -->
<img src="/hero.webp" alt="..." loading="eager" fetchpriority="high"
     width="1200" height="600">
```

---

## INP Optimization

INP measures response to user interactions (click, keypress, tap).

### Diagnose Slow Interactions

```javascript
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    if (entry.duration > 200) {
      console.log('Slow interaction:', entry.name, Math.round(entry.duration) + 'ms');
    }
  }
}).observe({ entryTypes: ['event'] });
```

### Fixes

| Problem | Fix |
|---------|-----|
| Long task blocking main thread | Break into smaller tasks with `scheduler.yield()` |
| Heavy computation on interaction | Move to Web Worker |
| Long list rendering | Virtualize with `react-window` or `react-virtual` |
| Unthrottled input handlers | Debounce search (300ms), throttle scroll (100ms) |
| Forced reflow in loop | Batch DOM reads, then DOM writes |

```typescript
// Debounce search input
const debouncedSearch = useMemo(
  () => debounce((query: string) => performSearch(query), 300),
  []
);

// Break long task
async function processLargeList(items: Item[]) {
  for (const item of items) {
    processItem(item);
    await scheduler.yield();  // Yield to browser between items
  }
}
```

---

## CLS Optimization

CLS = content shifting unexpectedly as elements load.

| Cause | Fix |
|-------|-----|
| Images without dimensions | Always set `width` and `height` on `<img>` |
| Dynamic content injected above existing | Reserve space with `min-height` |
| Web fonts causing FOUT | `font-display: optional` or preload |
| Ads without reserved space | `min-height` container before ad loads |
| Animations using `top`/`left` | Use `transform: translateY()` instead |

```html
<!-- Always specify dimensions to prevent CLS -->
<img src="photo.jpg" alt="..." width="800" height="600">

<!-- Reserve space for dynamic content -->
<div style="min-height: 200px">
  <!-- async content loads here -->
</div>
```

---

## Bundle Size Optimization

### Diagnose

```bash
# Webpack
npx webpack-bundle-analyzer dist/stats.json

# Vite
npx vite-bundle-visualizer
```

### Fix Common Issues

| Problem | Fix |
|---------|-----|
| Importing entire library | Named imports: `import { debounce } from 'lodash-es'` |
| Large dependency | Find lighter alternative or inline the function |
| Non-critical code in main bundle | Dynamic import: `const mod = await import('./heavy')` |
| Duplicate dependencies | `npm dedupe`, check for version conflicts |
| No code splitting | Route-based splitting with React.lazy |

```typescript
// Dynamic import for non-critical features
const HeavyChart = React.lazy(() => import('./HeavyChart'));

// Route-based code splitting
const AdminPanel = React.lazy(() => import('./pages/AdminPanel'));
```

---

## React Re-render Optimization

### Diagnose

React DevTools Profiler → Record → Interact → Check "Why did this render?"

### Fixes

```typescript
// Memoize expensive computation
const sortedTasks = useMemo(
  () => [...tasks].sort((a, b) => a.dueDate - b.dueDate),
  [tasks]
);

// Stable callback references
const handleDelete = useCallback(
  (id: string) => deleteTask(id),
  [deleteTask]
);

// Memoize component to prevent parent re-renders from cascading
const TaskItem = React.memo(({ task }: { task: Task }) => (
  <li>{task.title}</li>
));
```

**Rule:** Profile before optimizing. `useMemo` and `useCallback` have overhead — only add them when you've measured a re-render problem.

---

## Performance Budgets

### Targets

| Metric | Budget |
|--------|--------|
| JS bundle (gzip) | < 200KB |
| CSS bundle (gzip) | < 50KB |
| LCP | < 2.5s |
| INP | < 200ms |
| CLS | < 0.1 |

### Lighthouse CI Enforcement

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-byte-weight': ['error', { maxNumericValue: 500_000 }],
      },
    },
  },
};
```

```yaml
# CI step
- name: Lighthouse CI
  run: npx lhci autorun
  env:
    LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Optimizing without measuring | Profile first, then optimize |
| Adding useMemo/useCallback everywhere | Profile to confirm re-render problem first |
| `h-screen` on mobile | Use `min-h-[100dvh]` (iOS Safari fix) |
| No `width`/`height` on images | Always specify to prevent CLS |
| All code in main bundle | Code split by route and feature |

## Verification Checklist

- [ ] LCP element identified and optimized (preload, format, size)
- [ ] INP measured on key interactions (<200ms)
- [ ] CLS <0.1 (image dimensions set, space reserved for dynamic content)
- [ ] JS bundle <200KB gzip (analyzer run)
- [ ] No unnecessary React re-renders (Profiler used)
- [ ] Performance budgets defined and enforced in CI (Lighthouse CI)
- [ ] WebP/AVIF used for images
- [ ] Code splitting on routes and heavy features
- [ ] No `h-screen` — use `min-h-[100dvh]`

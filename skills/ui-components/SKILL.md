---
name: ui-components
description: |
  Use when building UI components, implementing accessible interfaces, creating responsive
  layouts, auditing UI for visual quality or AI aesthetic anti-patterns, implementing component
  variants, reviewing component architecture, or ensuring WCAG 2.1 AA compliance. Triggers:
  "build a component", "UI component", "accessible", "responsive", "modal", "form", "button",
  "layout", "ARIA", "keyboard navigation", "screen reader", "visual QA", "component library".
---

# UI Components

Build accessible, responsive, and visually intentional UI components. Production quality — not AI-generated boilerplate.

**Core principle:** Every component ships with: keyboard navigation, screen reader support, loading/error/empty states, and responsive behavior. Accessibility is not optional.

## When to Use

- Building new UI components
- Reviewing existing components for quality
- Implementing accessibility (WCAG 2.1 AA)
- Detecting and removing AI aesthetic anti-patterns
- Creating component variants with consistent API

## When NOT to Use

- Design system setup (color, typography, tokens) — use design-system skill
- Performance optimization of components — use frontend-performance skill

---

## Component Architecture

### Atomic Design Hierarchy

| Level | Examples |
|-------|---------|
| **Atoms** | Button, Input, Label, Icon, Badge, Avatar |
| **Molecules** | Search bar, Form field (label + input + error), Card |
| **Organisms** | Header, Sidebar, Data table, Form with submit |
| **Templates** | Dashboard layout, Settings page shell |
| **Pages** | Full user-facing pages |

### Composition Over Configuration

```tsx
// Good: composable — caller controls structure
<Card>
  <CardHeader>
    <CardTitle>Tasks</CardTitle>
    <CardDescription>Your pending work</CardDescription>
  </CardHeader>
  <CardContent>
    <TaskList tasks={tasks} />
  </CardContent>
</Card>

// Avoid: over-configured — caller can't customize structure
<Card title="Tasks" subtitle="Your pending work" content={<TaskList />} />
```

### Container/Presentation Split

```tsx
// Container: fetches and manages data
function TaskListContainer() {
  const { tasks, isLoading, error } = useTasks();
  if (isLoading) return <TaskListSkeleton />;
  if (error) return <ErrorState message="Failed to load tasks" />;
  if (tasks.length === 0) return <EmptyState message="No tasks yet" action={<CreateTaskButton />} />;
  return <TaskList tasks={tasks} />;
}

// Presentation: pure display, no data fetching
function TaskList({ tasks }: { tasks: Task[] }) {
  return (
    <ul role="list">
      {tasks.map(task => <TaskItem key={task.id} task={task} />)}
    </ul>
  );
}
```

### Component Variants (class-variance-authority)

```typescript
import { cva } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        outline: 'border border-input hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
      },
      size: {
        sm: 'h-9 px-3 text-sm',
        default: 'h-10 px-4 py-2',
        lg: 'h-11 px-8 text-base',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  }
);
```

---

## Required States

Every interactive component must handle all states:

| State | How to Handle |
|-------|--------------|
| **Default** | Normal, no interaction |
| **Hover** | Visual feedback (`hover:`) |
| **Focus** | Visible focus ring — never `outline: none` without replacement |
| **Active** | Press state for buttons |
| **Disabled** | `disabled` attribute, `aria-disabled`, reduced opacity |
| **Loading** | Skeleton or spinner, `aria-busy="true"` |
| **Error** | Error message linked via `aria-describedby` |
| **Empty** | Empty state with guidance or call-to-action |

---

## WCAG 2.1 AA Accessibility

### Keyboard Navigation

```tsx
// All interactive elements must be keyboard accessible
// Tab moves focus, Enter/Space activates, Escape closes modals/dropdowns

// Modal: trap focus inside
function Modal({ isOpen, onClose, children }) {
  const ref = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    if (!isOpen) return;
    const firstFocusable = ref.current?.querySelector<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    firstFocusable?.focus();
  }, [isOpen]);

  return isOpen ? (
    <div role="dialog" aria-modal="true" ref={ref} onKeyDown={e => {
      if (e.key === 'Escape') onClose();
    }}>
      {children}
    </div>
  ) : null;
}
```

### ARIA Checklist

```html
<!-- Icon-only button: must have label -->
<button aria-label="Close dialog"><XIcon aria-hidden="true" /></button>

<!-- Toggle button: announce state -->
<button aria-expanded="false" aria-controls="menu">Menu</button>

<!-- Live region for dynamic content -->
<div aria-live="polite" aria-atomic="true">3 items in cart</div>

<!-- Form input: label association -->
<label for="email">Email address</label>
<input id="email" type="email" aria-required="true" 
       aria-describedby="email-hint email-error">
<p id="email-hint">We'll never share your email.</p>
<p id="email-error" role="alert">Email is required.</p>
```

### Full Accessibility Checklist

- [ ] Keyboard navigation works (Tab through entire page)
- [ ] Screen reader announces content and structure correctly
- [ ] Color contrast passes (4.5:1 text, 3:1 UI elements)
- [ ] Focus indicators visible on every interactive element
- [ ] All form inputs have associated labels (not just placeholder)
- [ ] All images have descriptive alt text (or `alt=""` if decorative)
- [ ] Headings are hierarchical (h1→h2→h3, no skips)
- [ ] Link text is descriptive ("View task details" not "click here")
- [ ] Touch targets minimum 44×44px
- [ ] `aria-label` on all icon-only buttons
- [ ] Modals trap focus and restore focus on close

---

## Responsive Design

```
Breakpoints:
  375px  — mobile portrait (minimum)
  768px  — tablet portrait
  1024px — tablet landscape / small desktop
  1440px — desktop

Rules:
  - Mobile-first: start with mobile styles, add breakpoints upward
  - All multi-column layouts collapse below 768px
  - No horizontal scroll on any viewport (critical failure)
  - Touch targets ≥44px on mobile
  - Body text ≥16px on mobile
  - Use min-h-[100dvh] not h-screen (iOS Safari fix)
```

```tsx
// Mobile-first responsive grid
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  {items.map(item => <Card key={item.id} {...item} />)}
</div>
```

---

## AI Slop Anti-Patterns (Banned)

These patterns signal AI-generated UI without design intent:

| AI Default | Production Standard |
|---|---|
| Purple/indigo gradients on everything | Project's actual color palette |
| Excessive `rounded-2xl` on everything | Consistent border-radius from design system |
| Oversized padding everywhere (`p-8` on everything) | Consistent spacing scale |
| Generic hero sections ("Elevate your workflow") | Content-first, specific copy |
| Card grids of 6 generic cards | Real content with real hierarchy |
| Emojis in production UI | Text or proper icons |
| Pure black (`#000000`) | Zinc-950 or Off-Black |
| AI copywriting clichés ("Seamless", "Unleash", "Next-Gen") | Specific, direct language |
| Neon/outer glow shadows | Subtle or no shadows per design system |
| Oversaturated accent colors (>80% saturation) | Measured accent within constraints |

**8 specific forbidden patterns:**
| Pattern | Banned Form | Use Instead |
|---------|-------------|-------------|
| Neon glows | `box-shadow: 0 0 20px #accent` | Muted tinted `box-shadow` (hue-matched, low opacity) |
| Pure black text | `color: #000` | `zinc-900` or equivalent dark gray |
| Oversaturated accents | Saturation >80% | Desaturate accent to blend with neutrals |
| Gradient text | `background-clip: text` on large headings | Solid color or 1-stop gradient max |
| Generic stock avatars | Generic SVG "egg" user icon | Initials/monogram component or omit |
| Rounded fake numbers | "1,234" displayed as "1.2K" arbitrarily | Show real data, or label explicitly as "example" |
| Default 3-column card grid | Equal-width 3-card feature row | 2-column zig-zag, asymmetric grid, or horizontal scroll |
| Lorem ipsum in shipped UI | Filler text that will reach production | Real content or named placeholder (`[Client Name Here]`) |

## Interactive State Completeness Rule

Every component must implement all four data states before it is considered complete:

| State | Requirement |
|-------|-------------|
| **Loading** | Skeleton layout matching component shape, or contextual spinner with `aria-busy="true"` |
| **Empty** | Zero-state illustration or message explaining what goes here + a call-to-action to populate it |
| **Error** | Clear human-readable message, specific to what failed, with a retry action |
| **Success** | Confirmation feedback or updated content — never silently succeed |

A component missing any of these four states is incomplete and must not ship.

## Content Standards

- **Never lorem ipsum** — use realistic placeholder content
- **No broken image links** — use `picsum.photos` or SVG placeholders
- **No generic names** ("John Doe", "Acme Corp") — use realistic names
- **No placeholder copy** that will ship (it will ship)

---

## Component Quality Limits

| Limit | Threshold | Action |
|-------|-----------|--------|
| Component file length | 200 lines | Split into subcomponents |
| Props count | 8 | Extract to compound component pattern |
| Nesting depth | 5 levels | Extract inner elements |
| Logic in JSX | Any non-trivial | Extract to custom hook |

---

## Verification Checklist

- [ ] All interactive states handled (default, hover, focus, active, disabled, loading, error, empty)
- [ ] Keyboard navigation works (Tab, Enter, Escape)
- [ ] Screen reader announced content tested
- [ ] Color contrast passes (run axe DevTools or Lighthouse)
- [ ] Focus indicators visible and meet 3:1 contrast
- [ ] All icon-only buttons have `aria-label`
- [ ] All form inputs have associated `<label>`
- [ ] Touch targets ≥44px on mobile
- [ ] Responsive: works at 375px, 768px, 1024px, 1440px
- [ ] No horizontal scroll at any viewport
- [ ] No AI aesthetic patterns (purple gradients, excessive rounding, lorem ipsum)
- [ ] Semantic color tokens used throughout (no raw hex values)
- [ ] Component <200 lines
- [ ] No inline styles or arbitrary pixel values

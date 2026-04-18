---
name: remotion
description: "Use when creating programmatic videos using React and Remotion — composing video from React components, animating with useCurrentFrame and interpolate, adding transitions, handling audio, rendering to MP4, or integrating video assets. Triggers: \"Remotion\", \"programmatic video\", \"video in React\", \"React to MP4\", \"video composition\", \"video animation\", \"render video\", \"Remotion composition\", \"frame-based animation\", \"useCurrentFrame\", \"interpolate Remotion\", \"TransitionSeries\", \"video rendering\"."
---

# Remotion — Programmatic Video in React

## When to Use

- Building videos entirely from React components (data-driven, template-based, or generative)
- Animating elements frame-by-frame with `useCurrentFrame` and `interpolate`
- Composing multi-scene videos with transitions, audio tracks, and embedded video clips
- Rendering to MP4/ProRes from a CLI or render server pipeline
- Syncing visuals to voiceover or music timing

## When NOT to Use

- **UI animations** — use the `animation` skill (CSS/Framer Motion for in-app motion)
- **Video editing workflows** — use the `buttercut` skill for timeline editing, cut detection, FFmpeg pipelines
- **Recording browser sessions** — use the `e2e-testing` skill (Playwright screen capture)

---

## Core Principles

| Rule | Detail |
|------|--------|
| Frame-based only | Never use `setTimeout`, `setInterval`, or CSS `transition`/`animate-*` — they break deterministic rendering |
| 30fps convention | Standard project fps is 30; always derive timing as `seconds × fps` |
| Deterministic | Every frame must render identically given the same frame number — no random values outside `useMemo` seeded by frame |
| `useVideoConfig()` | Always read `fps`, `width`, `height`, `durationInFrames` from this hook, never hardcode |

---

## Core Patterns

### 1. `useCurrentFrame` + `interpolate`

The fundamental animation primitive. All motion must derive from the current frame number.

```tsx
import { useCurrentFrame, useVideoConfig, interpolate, AbsoluteFill } from 'remotion';

export const FadeInSlide = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Fade in over the first 0.5 seconds
  const opacity = interpolate(frame, [0, 0.5 * fps], [0, 1], {
    extrapolateRight: 'clamp',
  });

  // Slide up 40px → 0px over the first 0.75 seconds
  const translateY = interpolate(frame, [0, 0.75 * fps], [40, 0], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{ opacity, transform: `translateY(${translateY}px)` }}>
      <h1>Hello Remotion</h1>
    </AbsoluteFill>
  );
};
```

Always pass `extrapolateRight: 'clamp'` unless you intentionally want values to extend beyond the mapped range.

### 2. `delayRender` + `continueRender` for Async Data

Block rendering until data is ready. Always call `continueRender` in `.catch()` too.

```tsx
import { delayRender, continueRender } from 'remotion';

const [handle] = useState(() => delayRender('Loading data'));
useEffect(() => {
  fetch('/api/data')
    .then((r) => r.json())
    .then((json) => { setData(json); continueRender(handle); })
    .catch(() => continueRender(handle));
}, [handle]);
```

### 3. `OffthreadVideo` for Embedded Video Assets

Use `OffthreadVideo` (not `<Video>`) when embedding video clips. It decodes frames off the main thread for better performance in complex compositions.

```tsx
import { OffthreadVideo, staticFile } from 'remotion';

export const VideoScene = () => (
  <OffthreadVideo src={staticFile('clips/demo.mp4')} />
);
```

### 4. `staticFile()` for Public Assets

Place files in `public/` and reference with `staticFile()`. Works for images, audio, fonts, Lottie JSON, and GIFs.

```tsx
<Img src={staticFile('logo.png')} />
<Audio src={staticFile('music/bg.mp3')} volume={0.6} />
// Fonts:
const font = new FontFace('Inter', `url(${staticFile('fonts/Inter.woff2')})`);
await font.load(); document.fonts.add(font);
```

---

## Composition Structure

Register compositions in `src/Root.tsx`. Use `calculateMetadata` when duration or dimensions depend on runtime data.

```tsx
import { Composition, CalculateMetadataFunction } from 'remotion';
import { MyVideo, MyVideoProps } from './MyVideo';

const calcMeta: CalculateMetadataFunction<MyVideoProps> = async ({ props }) => {
  const duration = await getAudioDurationInSeconds(staticFile(props.audioFile));
  return { durationInFrames: Math.ceil(duration * 30) };
};

export const RemotionRoot = () => (
  <Composition
    id="MyVideo"
    component={MyVideo}
    fps={30}
    width={1920}
    height={1080}
    durationInFrames={300} // placeholder — overridden by calculateMetadata
    defaultProps={{ audioFile: 'voiceover/intro.mp3' }}
    calculateMetadata={calcMeta}
  />
);
```

---

## TransitionSeries

Arrange scenes with visual transitions. Each `<TransitionSeries.Transition>` overlaps adjacent sequences, shortening total duration.

```tsx
import { TransitionSeries, linearTiming } from '@remotion/transitions';
import { fade } from '@remotion/transitions/fade';
import { glitch, lightLeak, clockWipe } from '../../../../lib/transitions'; // custom toolkit transitions

<TransitionSeries>
  <TransitionSeries.Sequence durationInFrames={90}>
    <TitleSlide />
  </TransitionSeries.Sequence>
  <TransitionSeries.Transition
    presentation={glitch({ intensity: 0.8, slices: 8, rgbShift: true })}
    timing={linearTiming({ durationInFrames: 20 })}
  />
  <TransitionSeries.Sequence durationInFrames={120}>
    <ContentSlide />
  </TransitionSeries.Sequence>
  <TransitionSeries.Transition
    presentation={fade()}
    timing={linearTiming({ durationInFrames: 15 })}
  />
  <TransitionSeries.Sequence durationInFrames={90}>
    <OutroSlide />
  </TransitionSeries.Sequence>
</TransitionSeries>
// Total duration: 90 + 120 + 90 - 20 - 15 = 265 frames
```

### Available Custom Transitions

| Transition | Key Options | Best For |
|------------|-------------|----------|
| `glitch()` | `intensity`, `slices`, `rgbShift` | Tech demos, cyberpunk reveals |
| `rgbSplit()` | `direction`, `displacement` | Modern tech, energetic cuts |
| `zoomBlur()` | `direction`, `blurAmount` | CTAs, high-energy moments |
| `lightLeak()` | `temperature`, `direction` | Celebrations, warm film aesthetic |
| `clockWipe()` | `startAngle`, `direction`, `segments` | Time content, playful reveals |
| `pixelate()` | `maxBlockSize`, `glitchArtifacts`, `scanlines` | Retro/gaming, digital transforms |
| `checkerboard()` | `pattern`, `gridSize`, `squareAnimation` | Structured reveals, playful cuts |

**Checkerboard patterns:** `sequential`, `random`, `diagonal`, `alternating`, `spiral`, `rows`, `columns`, `center-out`, `corners-in`

### Transition Duration Guidelines

| Type | Frames | Notes |
|------|--------|-------|
| Quick cut | 15–20 | Fast, punchy |
| Standard | 30–45 | Most common |
| Dramatic | 50–60 | Slow reveals |
| Glitch effects | 20–30 | Should feel sudden |
| Light leak | 45–60 | Needs time to sweep |

---

## Audio Handling

```tsx
import { Audio } from '@remotion/media';
import { Sequence, staticFile } from 'remotion';

// Background music with fade-in
<Audio
  src={staticFile('music/bg.mp3')}
  volume={(f) => interpolate(f, [0, fps], [0, 0.6], { extrapolateRight: 'clamp' })}
  loop
/>

// Delayed voiceover (starts at 1 second)
<Sequence from={fps}>
  <Audio src={staticFile('voiceover/scene-01.mp3')} />
</Sequence>
```

**Get audio duration for `calculateMetadata`:**

```ts
import { getAudioDurationInSeconds } from '@remotion/media-utils';

const durationSec = await getAudioDurationInSeconds(staticFile('voiceover/scene-01.mp3'));
const durationFrames = Math.ceil(durationSec * 30);
```

---

## Text / DOM Measuring with `measureText`

Use `@remotion/layout-utils` to measure text before rendering to avoid overflow:

```tsx
import { measureText } from '@remotion/layout-utils';
const { width, height } = measureText({ text: 'Hello', fontFamily: 'Inter', fontSize: 48, fontWeight: '700' });
```

---

## Tailwind Integration

Supported — follow [remotion.dev/docs/tailwind](https://www.remotion.dev/docs/tailwind) to enable. Never use `transition-*` or `animate-*` classes; drive all motion with `useCurrentFrame()`.

---

## Rendering

```bash
# Render to MP4 (H.264)
npx remotion render MyVideo out/video.mp4

# Render to ProRes (for editing/compositing)
npx remotion render MyVideo out/video.mov --codec=prores

# Quality presets (CRF: lower = better quality)
npx remotion render MyVideo out/video.mp4 --crf=18    # high quality
npx remotion render MyVideo out/video.mp4 --crf=28    # smaller file

# Render a still frame
npx remotion still MyVideo out/thumb.png --frame=30

# Render via render server (headless)
npx remotion render --concurrency=4 MyVideo out/video.mp4
```

**Output formats:** H.264 (`.mp4`), ProRes (`.mov`), WebM (`.webm`), transparent WebM/MOV for compositing.

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| CSS `transition` or `animation` properties | Remove — use `interpolate()` instead |
| Hardcoded frame counts (e.g., `270`) | Use `fps` from `useVideoConfig()`: `9 * fps` |
| `setTimeout` / `setInterval` inside components | Forbidden — all timing is frame-driven |
| `Math.random()` per render | Seed with frame number or move to `useMemo` |
| `<Video>` for clip embedding | Use `<OffthreadVideo>` for better perf |
| Forgetting `continueRender` on async error | Always call in `.catch()` too |
| Asset path not via `staticFile()` | Files in `public/` must use `staticFile('file.mp3')` |
| Transition duration > adjacent sequence | Transition must be shorter than each neighboring sequence |

---

## Verification Checklist

- [ ] All animations read from `useCurrentFrame()` — no CSS transitions, no `setTimeout`
- [ ] `fps` read from `useVideoConfig()` — no hardcoded `30` in timing math
- [ ] All `interpolate()` calls use `extrapolateRight: 'clamp'` unless intentional
- [ ] Async data guarded with `delayRender` / `continueRender`
- [ ] Video assets use `<OffthreadVideo>`, not `<Video>`
- [ ] All `public/` assets referenced via `staticFile()`
- [ ] `<Composition>` registered in `Root.tsx` with correct `fps`, `width`, `height`
- [ ] Transition `durationInFrames` is less than each adjacent sequence duration
- [ ] Total composition duration accounts for transition overlap when using `TransitionSeries`
- [ ] No Tailwind `transition-*` or `animate-*` classes used
- [ ] License checked if commercial use: https://remotion.dev/license

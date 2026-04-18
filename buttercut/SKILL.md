---
name: buttercut
description: "Use when transcribing video audio, generating visual descriptions from video frames, or creating rough cut edit sequences from video footage. A three-phase AI-assisted video editing workflow: transcribe audio with WhisperX, analyze frames with FFmpeg, create rough cut YAML for Buttercut. Triggers: \"Buttercut\", \"rough cut\", \"video rough cut\", \"video transcription\", \"WhisperX\", \"video analysis\", \"visual transcript\", \"video sequence\", \"video scene\", \"Final Cut Pro XML\", \"video editing workflow\", \"video footage\"."
---

# Skill: Buttercut Video Editing Workflow

Three-phase AI-assisted workflow for turning raw video footage into an editable rough cut.

## When to Use

- **Phase 1 (Transcribe):** One or more video files need audio transcripts before visual analysis can begin. Each video must produce a `transcript.json` before moving to Phase 2.
- **Phase 2 (Analyze):** Audio transcripts exist for all target videos but visual transcripts (`visual_transcript.json`) have not yet been created. Requires Phase 1 to be complete.
- **Phase 3 (Rough Cut):** All clips have visual transcripts and the user wants a rough cut, sequence, or scene assembled and exported to Final Cut Pro XML. Requires Phase 2 to be complete for every clip in the cut.

## When NOT to Use

- **Programmatic video creation** (animations, generated visuals, data-driven video): use the `remotion` skill instead.
- **Browser session recording or screen capture testing**: use the `e2e-testing` skill instead.

---

## Phase 1: Transcribe Audio

**Tool: WhisperX** — mandatory. Standard Whisper discards leading silence and breaks timestamp alignment. WhisperX preserves the original video timeline with word-level timing.

### Step 1 — Read language from `library.yaml`

```yaml
library_name: my-library
language: en   # use this value for --language flag
```

### Step 2 — Run WhisperX directly on the video file

Do not extract audio separately; run on the video file to preserve timestamp alignment.

```bash
whisperx "/full/path/to/video.mov" \
  --language en \
  --model medium \
  --compute_type float32 \
  --device cpu \
  --output_format json \
  --output_dir libraries/[library-name]/transcripts
```

### Step 3 — Prepare the audio transcript

```bash
ruby .claude/skills/transcribe-audio/prepare_audio_script.rb \
  libraries/[library-name]/transcripts/video_name.json \
  /full/path/to/original/video_name.mov
```

This script adds the video source path as metadata, removes unnecessary fields, and prettifies JSON.

### Output schema — `transcript.json`

```json
{
  "source_video": "/full/path/to/video.mov",
  "segments": [
    {
      "start": 2.917,
      "end": 7.586,
      "text": "Hey, good afternoon everybody.",
      "words": [
        { "word": "Hey,", "start": 2.917, "end": 3.1 },
        { "word": "good", "start": 3.1, "end": 3.4 }
      ]
    }
  ]
}
```

### Parallel execution pattern

This phase is designed for concurrent Task agents — one agent per video file. The parent thread updates `library.yaml` sequentially after each agent completes to avoid race conditions.

```
Parent agent
  ├── Task agent → video_a.mov → transcript_a.json
  ├── Task agent → video_b.mov → transcript_b.json
  └── Task agent → video_c.mov → transcript_c.json
         ↓ (all complete)
  Parent updates library.yaml with transcript paths
```

Each agent returns:
```
✓ [video_filename.mov] transcribed successfully
  Audio transcript: libraries/[library-name]/transcripts/video_name.json
  Video path: /full/path/to/video_filename.mov
```

Do NOT update `library.yaml` inside the agent — the parent handles this.

---

## Phase 2: Analyze Video Frames

**Prerequisite:** `transcript.json` must exist for every video being analyzed.

**Tool: FFmpeg** with binary-search frame extraction — not sequential frame dumping.

### Step 1 — Copy and clean the audio transcript

```bash
cp libraries/[library]/transcripts/video.json \
   libraries/[library]/transcripts/visual_video.json

ruby .claude/skills/analyze-video/prepare_visual_script.rb \
   libraries/[library]/transcripts/visual_video.json
```

This strips word-level timing data and prettifies JSON for editing.

### Step 2 — Extract frames (binary search, not sequential)

Create the frame directory:
```bash
mkdir -p tmp/frames/[video_name]
```

Extraction rules:
- **Videos ≤ 30s:** extract one frame at 2s
- **Videos > 30s:** extract start (2s), middle (duration/2), end (duration − 2s)

```bash
ffmpeg -ss 00:00:02 -i video.mov -vframes 1 -vf "scale=1280:-1" \
  tmp/frames/[video_name]/start.jpg
```

**Subdivide when:** subject, setting, or camera angle changes between sampled frames.
**Stop when:** footage is no longer changing or only has minor changes.
**Never sample** more frequently than once per 30 seconds.

### Step 3 — Add visual descriptions

Read each extracted JPG with the Read tool, then Edit `visual_video.json` incrementally. No scripts needed — edit the JSON directly as you analyze each frame.

**Description guidelines:**
- 3 sentences maximum per segment
- First segment: full description (subject, setting, shot type, lighting, camera style)
- Continuing shots with same subject/setting: brief delta only
- B-roll or drastically different shot: up to 3 sentences

**Dialogue segment — add `visual` field:**
```json
{
  "start": 2.917,
  "end": 7.586,
  "text": "Hey, good afternoon everybody.",
  "visual": "Man in red shirt speaking to camera in medium shot. Home office with bookshelf. Natural lighting."
}
```

**B-roll segment — insert new entry:**
```json
{
  "start": 35.474,
  "end": 56.162,
  "text": "",
  "visual": "Green bicycle parked in front of building. Urban street with trees.",
  "b_roll": true
}
```

### Step 4 — Cleanup and return

```bash
rm -rf tmp/frames/[video_name]
```

Return structured response:
```
✓ [video_filename.mov] analyzed successfully
  Visual transcript: libraries/[library]/transcripts/visual_video.json
  Video path: /full/path/to/video_filename.mov
```

Do NOT update `library.yaml` inside the agent.

### Output schema — `visual_transcript.json`

```json
{
  "source_video": "/full/path/to/video.mov",
  "segments": [
    {
      "start": 2.917,
      "end": 7.586,
      "text": "Hey, good afternoon everybody.",
      "visual": "Man in red shirt speaking to camera in medium shot."
    },
    {
      "start": 35.474,
      "end": 56.162,
      "text": "",
      "visual": "Green bicycle parked in front of building.",
      "b_roll": true
    }
  ]
}
```

---

## Phase 3: Create Rough Cut

**Prerequisite:** `visual_transcript.json` must exist for every clip in the intended cut. If any are missing, inform the user and offer to complete Phases 1–2 first.

**Tool: Buttercut gem**

### Step 1 — Verify prerequisites

```bash
ls libraries/[library-name]/library.yaml
```

Read `library.yaml` and confirm every video entry has both `transcript` and `visual_transcript` populated. Do not proceed until all are present.

### Step 2 — Concatenate visual transcripts with file markers

Combine all relevant `visual_transcript.json` files into a single input, prepending each with a file marker so the agent tracks source clips:

```
=== FILE: video_a.mov ===
[contents of visual_transcript_a.json]

=== FILE: video_b.mov ===
[contents of visual_transcript_b.json]
```

### Step 3 — Create rough cut YAML

Make editorial decisions: select the best takes, cut dead air, sequence scenes logically, apply labels for intent.

**Output schema — `roughcut.yaml`**

```yaml
roughcut:
  library: my-library
  created: "2026-04-09T12:00:00Z"
  clips:
    - source: video_a.mov
      in: 2.917
      out: 45.2
      label: "Intro — founding story"
    - source: video_b.mov
      in: 0.0
      out: 30.5
      label: "Product demo"
    - source: video_a.mov
      in: 120.0
      out: 180.0
      label: "Call to action"
```

Save to: `libraries/[library-name]/roughcuts/[roughcut_name]_[datetime].yaml`

### Step 4 — Export to Final Cut Pro XML

```bash
buttercut export \
  libraries/[library-name]/roughcuts/[roughcut_name]_[datetime].yaml \
  --format fcpxml \
  --output libraries/[library-name]/roughcuts/roughcut.xml
```

### Step 5 — Report to user

Inform the user of the XML file location (not the YAML). The XML is what imports into their video editor.

---

## Verification Checklist

- [ ] WhisperX used (not standard Whisper) for all audio transcription
- [ ] WhisperX run directly on video files, not extracted audio
- [ ] `transcript.json` exists for every video before Phase 2 begins
- [ ] FFmpeg binary-search extraction used (not sequential frame dump)
- [ ] Frame sampling never exceeds once per 30 seconds
- [ ] First segment has full visual description; subsequent similar shots use delta only
- [ ] `visual_transcript.json` exists for every clip before Phase 3 begins
- [ ] `library.yaml` updated by parent agent only (no race conditions in parallel runs)
- [ ] `roughcut.yaml` saved with datetime in filename
- [ ] Final Cut Pro XML exported and path reported to user
- [ ] Temporary frame files cleaned up (`tmp/frames/[video_name]/`)

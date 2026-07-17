# AI pipeline (hybrid video → semantic 3D)

Offline research path for RoomScanner. Capture on **iPhone 15 Pro**, process on **MacBook M1 Max (MPS / 64 GB)**, view results back in the app.

## Comment and test conventions

- Swift and Python comments explain **what** and **why** at non-obvious boundaries (ARKit depth layout, package schema, MPS chunking).
- Each unit test starts with **one English line** stating what is under test.
- Unit tests must not download foundation-model weights; mock I/O and pure helpers only.

## Capture package schema

Written by iOS `CapturePackageExporter`:

```
Session_<uuid>/
  video.mp4              # required walkthrough recording
  metadata.json          # schema_version, has_lidar, intrinsics, timing
  frames/frame_XXXXX.jpg # optional RGB stills (or extracted by CLI)
  depth/frame_XXXXX.npy  # float32 meters, HxW, aligned to frames when LiDAR
```

`metadata.json` keys:

| Key | Meaning |
|-----|---------|
| `schema_version` | Currently `1` |
| `session_id` | UUID string |
| `has_lidar` | `true` when depth folder has matching maps |
| `duration_seconds` | Recording length |
| `frame_count` | Number of RGB frames written |
| `depth_count` | Number of depth maps |
| `intrinsics` | Optional `{fx,fy,cx,cy,width,height}` in pixels |
| `created_at` | ISO-8601 |

Soft-fail: missing depth → `has_lidar=false`; CLI still runs RGB-only geometry backends if installed.

## CLI

```bash
cd pipeline
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m room_pipeline.run --input /path/to/Session_xxx --out out/Session_xxx
```

Config defaults: [`configs/default.yaml`](../pipeline/configs/default.yaml) (`device: mps`, `max_views_per_chunk: 32`).

### Stages

1. **Validate package** — refuse empty sessions early.
2. **Extract / filter frames** — ffmpeg + Laplacian blur filter.
3. **Geometry** — prefer LiDAR depth unprojection when present (metric, no GPU). Else try MapAnything / Depth Anything 3 if installed. Else clear error.
4. **Semantics** — label vote helper; SAM 3.1 hook when credentials + package available (optional).
5. **Mesh / export** — Open3D TSDF when installed; always write PLY; GLB via trimesh when installed.

## Mac loop (AirDrop / Files)

1. On phone: **AI Capture** → record → Share / save to Files.
2. On Mac: copy `Session_*` into e.g. `~/Sessions/`.
3. Run CLI above.
4. On phone: **Results** → Import `room.glb` / `room.usdz`.

## Smoke checklist

- [ ] Existing **Scan (lab)** tab still opens and runs LiDAR mesh.
- [ ] AI Capture writes `metadata.json` + `video.mp4`.
- [ ] With LiDAR, `depth/` has `.npy` files and `has_lidar=true`.
- [ ] CLI produces `cameras.json`, `room_semantic.ply` (and `room.glb` if trimesh present).
- [ ] Results tab imports GLB without crash.
- [ ] Swift tests + `pytest pipeline/tests` pass without GPU weights.

## Failure modes

| Symptom | Likely cause | Mitigation |
|---------|--------------|------------|
| OOM on MPS | Too many views at once | Lower `max_views_per_chunk` |
| MapAnything import fails | CUDA-centric install | Use LiDAR unproject path; or DA3; or cloud GPU |
| SAM 3 HF 401 | No access / not logged in | `hf auth login` after requesting `facebook/sam3.1` |
| Empty mesh holes | Textureless walls / missing depth | Slower walk, more overlap; keep LiDAR on |
| Scale wrong | No depth + relative geometry | Prefer 15 Pro depth package |

## Optional foundation models

| Model | Role | Notes |
|-------|------|-------|
| MapAnything | Multi-view metric geometry | Primary when no / sparse LiDAR |
| Depth Anything 3 | Fallback any-view geometry | Apache metric variants preferred |
| SAM 3.1 | Concept masks | HF gate; optional for MVP labels |

Install instructions stay in upstream repos; this package keeps soft imports so unit tests stay offline.

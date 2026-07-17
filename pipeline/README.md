# room_pipeline

Offline Python CLI for RoomScanner capture packages. See [`docs/ai-pipeline.md`](../docs/ai-pipeline.md).

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
python -m room_pipeline.run --input /path/to/Session_xxx --out out/Session_xxx
pytest
```

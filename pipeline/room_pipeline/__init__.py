"""RoomScanner offline pipeline package.

Stages: validate → frames → geometry → semantics → mesh/export.
Heavy models (MapAnything, SAM 3.1) are soft-imported so tests stay offline.
"""

__version__ = "0.1.0"

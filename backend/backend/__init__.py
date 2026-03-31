"""Compatibility package for running ``uvicorn backend.app:app`` inside ``backend/``.

When the current working directory is the backend folder, Python cannot see the
repository root package named ``backend``. This nested package gives that
command a stable import target without changing the main application layout.
"""


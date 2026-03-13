# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the App

```bash
./run.sh
```

This starts the FastAPI server at `http://localhost:8000`. The script must be run from the repo root; it `cd`s into `backend/` before launching uvicorn.

To restart cleanly:
```bash
pkill -f "uvicorn app:app" && ./run.sh
```

## Dependency Notes (macOS Intel / macOS 12)

This project has pinned dependencies to work around platform compatibility issues on macOS 12 x86_64:

- **Python 3.12** (not 3.13) — PyTorch dropped macOS Intel support in 3.13-era wheels
- **`torch==2.2.2`** — last version with macOS x86_64 CPU wheels (2.5+ is ARM-only on macOS)
- **`onnxruntime==1.17.3`** — last version with Python 3.12 + macOS Intel support
- **`numpy<2.0`** — torch 2.2.2 was built against numpy 1.x; numpy 2.x breaks it

Always use `uv` to manage dependencies and run any Python file — never use `pip` or `python` directly. Use `uv run <script.py>` to execute Python files and `uv run uvicorn` to run the server. If changing dependencies: `uv sync`. The embedding model (`all-MiniLM-L6-v2`) is cached at `~/.cache/huggingface/` after first download.

## Environment

Requires a `.env` file in the repo root:
```
ANTHROPIC_API_KEY=your-key-here
```

## Architecture

The system is a full-stack RAG chatbot with a FastAPI backend and a static HTML/JS/CSS frontend.

**Request flow for a chat query:**

1. `frontend/script.js` POSTs to `/api/query`
2. `backend/app.py` hands the query to `RAGSystem.query()`
3. `RAGSystem` calls `AIGenerator.generate_response()` with Claude + a tool definition
4. Claude decides whether to call the `search_course_content` tool
5. If tool is called: `ToolManager` → `CourseSearchTool` → `VectorStore.search()` → ChromaDB
6. Tool results are sent back to Claude for a final response
7. Sources are extracted from `CourseSearchTool.last_sources` and returned to the frontend

**Key backend modules:**

- `rag_system.py` — top-level orchestrator; wires all components together
- `ai_generator.py` — wraps Anthropic SDK; handles the two-turn tool-use pattern (initial call → tool execution → follow-up call)
- `vector_store.py` — ChromaDB wrapper with two collections: `course_catalog` (for semantic course name resolution) and `course_content` (for chunk retrieval)
- `document_processor.py` — parses `.txt` course files and splits them into sentence-based chunks
- `search_tools.py` — `Tool` ABC + `CourseSearchTool` + `ToolManager`; adding a new tool means subclassing `Tool` and registering it with `ToolManager`
- `session_manager.py` — in-memory conversation history; history is passed as a formatted string in the system prompt (not as message history)
- `config.py` — all tuneable settings (`CHUNK_SIZE`, `MAX_RESULTS`, `MAX_HISTORY`, model name, etc.)

**Course document format** (files in `docs/`):
```
Course Title: <title>
Course Link: <url>
Course Instructor: <name>

Lesson 0: <title>
Lesson Link: <url>
<lesson content...>

Lesson 1: <title>
...
```

Course title is used as the unique ID in ChromaDB. Re-loading a folder skips already-indexed courses. To force a full re-index, call `add_course_folder(..., clear_existing=True)`.

**ChromaDB** is stored locally at `backend/chroma_db/` (persisted on disk). The embedding model is `all-MiniLM-L6-v2` via `SentenceTransformerEmbeddingFunction`.

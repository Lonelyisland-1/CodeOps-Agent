# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Service Management
- `make init` — One-click init: start Docker (Milvus), start services, upload docs
- `make start` — Start all services (CLS MCP + Monitor MCP + FastAPI)
- `make stop` — Stop all services
- `make restart` — Restart all services
- `make dev` — Dev mode with hot reload (uvicorn --reload)
- `make run` — Production mode (foreground)
- Windows: `.\start-windows.bat` / `.\stop-windows.bat`

### Code Quality
- `make format` — Format with ruff (or black as fallback)
- `make lint` — Lint with ruff
- `make fix` — Auto-fix with ruff
- `make type-check` — mypy type checking
- `make security` — bandit security scanning
- `make check-all` — format + lint + test

### Testing
- `make test` — pytest with coverage (--cov=app --cov-report=term-missing --cov-report=html)
- `make test-quick` — pytest without coverage
- `make coverage` — Coverage report
- Single test: `uv run pytest tests/test_file.py -k "test_name" -v`
- Tests use `asyncio_mode = "auto"` (async tests recognized automatically)

### Utilities
- `make logs` — Tail server.log
- `make clean` — Clean caches, pyc, logs
- `make shell` — Python shell with config pre-loaded
- `make docs` — Open API docs (`/docs`)

## Architecture

### Layer Structure (FastAPI + LangChain + LangGraph)

```
app/
├── api/           # FastAPI route handlers (chat, aiops, file, health)
├── services/      # Business logic layer
│   ├── rag_agent_service.py     # RAG Chat Agent (LangGraph + ChatQwen)
│   ├── aiops_service.py         # Plan-Execute-Replan orchestration
│   ├── vector_store_manager.py  # Milvus VectorStore wrapper
│   ├── vector_embedding_service.py  # DashScope Embeddings
│   ├── vector_index_service.py  # File→chunk→embed→store pipeline
│   ├── vector_search_service.py # Similarity search
│   └── document_splitter_service.py  # Text splitting
├── agent/         # AI agent logic
│   ├── mcp_client.py            # MultiServerMCPClient singleton + retry interceptor
│   └── aiops/                   # Plan-Execute-Replan core
│       ├── planner.py   # Step plan generation (LLM + knowledge retrieval)
│       ├── executor.py  # Single-step execution (ToolNode)
│       ├── replanner.py # Continue/replan/respond decision
│       ├── state.py     # PlanExecuteState TypedDict
│       └── utils.py     # Tool description formatting
├── tools/         # LangChain tools
│   ├── knowledge_tool.py        # Vector DB retrieval tool
│   ├── time_tool.py             # Current time tool
│   └── query_metrics_alerts.py  # Prometheus alerts API tool
├── core/          # Infrastructure
│   ├── llm_factory.py           # ChatOpenAI factory (DashScope-compatible)
│   └── milvus_client.py         # PyMilvus connection + collection management
├── models/        # Pydantic request/response models
└── utils/         # Loguru logger config
```

### Key Patterns

**Singletons** — Most services are module-level singletons instantiated at import time (config, rag_agent_service, aiops_service, vector_store_manager, milvus_manager, llm_factory).

**RAG Pipeline**: Upload → read → chunk (document_splitter_service) → embed (DashScopeEmbeddings via OpenAI-compatible API) → store in Milvus. Query → embed → similarity_search → format_docs → LLM context.

**AIOps (Plan-Execute-Replan)** — LangGraph StateGraph with three nodes:
1. `planner` — Retrieves knowledge base context, enumerates available tools (local + MCP), generates step plan
2. `executor` — Takes first plan step, binds tools to LLM, executes via ToolNode
3. `replanner` — Decides: respond (enough info) / continue / replan (adjust remaining steps)
- Conditional loop: replanner → executor (if steps remain) or END
- Hard cap: 8 max executed steps, >=5 steps forbids replanning

**MCP Integration** — Two servers configured in `.env`:
- `cls` (log query) — transport: sse, url: http://localhost:3000/sse
- `monitor` (metrics) — transport: streamable-http, url: http://localhost:8004/mcp
- Uses `langchain-mcp-adapters` `MultiServerMCPClient` (singleton)
- Retry interceptor with exponential backoff (3 retries)
- Errors are returned as `CallToolResult(isError=True)` — never thrown

**LLM** — All LLM calls use `ChatQwen` (from `langchain-qwq`) or `ChatOpenAI` pointing at DashScope's OpenAI-compatible endpoint. Model defaults to `qwen-max`. Embeddings use `text-embedding-v4` (1024 dims).

### External Dependencies

- **Vector DB**: Milvus via Docker Compose (`vector-database.yml` — etcd + minio + milvus-standalone + attu)
- **LLM**: Alibaba Cloud DashScope API key required in `.env`
- **Monitoring**: Prometheus at `http://127.0.0.1:9090` (for alert queries)

### Configuration

All config in `.env`, loaded via Pydantic Settings in `app/config.py`. Key vars:
- `DASHSCOPE_API_KEY` — Required. Also `DASHSCOPE_API_BASE`, `DASHSCOPE_MODEL`
- `MILVUS_HOST`, `MILVUS_PORT`
- `RAG_TOP_K`, `CHUNK_MAX_SIZE`, `CHUNK_OVERLAP`
- `MCP_CLS_TRANSPORT`, `MCP_CLS_URL`, `MCP_MONITOR_TRANSPORT`, `MCP_MONITOR_URL`
- `PROMETHEUS_BASE_URL`

### Static Frontend

`static/` — Pure HTML/JS/CSS frontend served by FastAPI. Three files: `index.html`, `app.js`, `styles.css`. No build step.

### MCP Servers

`mcp_servers/` — Two standalone FastMCP servers:
- `cls_server.py` — Log query service (port 3000, SSE transport)
- `monitor_server.py` — Monitoring data service (port 8004, streamable-http)

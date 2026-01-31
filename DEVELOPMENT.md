# Local Development Environment

This guide explains how to set up and use the local development environment for gcovr HTML report customization.

## Prerequisites

- Python 3.8+
- Docker (optional, for generating coverage data)

## Quick Start

### Option 1: Local Python venv (for template development)

If you already have `coverage.json` or `.info` files:

```bash
./setup-local-venv.sh
source .venv/bin/activate
./build.sh
```

This installs gcovr 8.4 in a local venv and generates the HTML report in `json/gcovr/`.

### Option 2: Docker (for generating coverage data)

To build Boost.JSON with coverage instrumentation and generate fresh coverage data:

```bash
./docker-build.sh
```

This will:
1. Build an Ubuntu 24.04 container with gcc-13, lcov v2.3, and gcovr 8.4
2. Compile Boost.JSON with coverage flags
3. Run tests
4. Generate `coverage.json` in `output/`

After completion, copy the coverage data and run the report generator:

```bash
cp output/coverage.json json/
./build.sh
```

### Interactive debugging

```bash
./docker-build.sh shell
```

## Workflow

1. **Edit templates** in `templates/html/`
2. **Run `./build.sh --quick`** to regenerate with sample data (faster)
3. **View results** in `json/gcovr/index.html`
4. **Run `./build.sh`** for a full build when ready

## Files

| File | Purpose |
|------|---------|
| `setup-local-venv.sh` | Creates Python venv with gcovr |
| `docker-build.sh` | Builds coverage data via Docker |
| `build.sh` | Generates HTML report (`--quick` for faster sample builds) |
| `templates/html/` | Custom gcovr HTML templates |
| `scripts/gcovr_wrapper.py` | Wrapper to register `.ipp` as C++ |

## Coverage Data Formats

- **`coverage.json`** (preferred): gcovr JSON tracefile with full function/branch data
- **`*.info`** (fallback): LCOV format, converted to Cobertura XML (loses some data)

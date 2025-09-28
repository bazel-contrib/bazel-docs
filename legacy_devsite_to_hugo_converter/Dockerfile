# Dockerfile with version variables and architecture-aware Hugo Extended installation

# Base Python image (overrideable)
ARG PYTHON_IMAGE=python:3.12-slim-bookworm
FROM ${PYTHON_IMAGE}

# Version arguments for easy updates
ARG HUGO_VERSION=0.146.0
ARG NODE_MAJOR_VERSION=22

# Install system dependencies, Go, Git, Hugo Extended (arch-aware), Node.js, PostCSS, and uv
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    golang-go \
    # Determine architecture and download matching Hugo Extended binary
    && ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
    amd64) HUGO_ARCH="Linux-64bit" ;; \
    arm64) HUGO_ARCH="Linux-ARM64" ;; \
    *) echo "Unsupported arch: ${ARCH}" >&2; exit 1 ;; \
    esac \
    && curl -sSL \
    "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_${HUGO_ARCH}.tar.gz" \
    | tar xz -C /usr/local/bin hugo \
    # Install Node.js LTS and PostCSS tools
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g autoprefixer postcss-cli postcss \
    # Install uv
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Ensure uv/uvx are on PATH and disable Python output buffering
ENV PATH="/root/.local/bin:$PATH" \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy project metadata
COPY pyproject.toml ./

# Copy the Hugo site from docs directory

# # Add venv binaries to PATH
ENV PATH="/app/.venv/bin:$PATH"
ENV NODE_PATH="/usr/lib/node_modules"

COPY . .

# Sync dependencies into virtual environment
RUN uv sync

RUN python cli.py convert --source work/bazel-source/site/en --output docs/

WORKDIR /app/docs

RUN hugo mod init github.com/alan707/bazel-docs && \
    hugo mod get github.com/google/docsy@v0.12.0 && \
    hugo mod tidy

RUN hugo --destination /workspace/public

EXPOSE 1313

# Default base URL can be overridden at build or run time
ARG BASE_URL=https://bazel-docs-68tmf.ondigitalocean.app/
ENV HUGO_BASEURL=${BASE_URL}

# Use shell form so the environment variable is expanded correctly
CMD ["sh","-c", "hugo server --bind 0.0.0.0 --baseURL \"$HUGO_BASEURL\" --disableFastRender"]

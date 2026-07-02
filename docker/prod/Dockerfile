# docker/prod/Dockerfile - Imagem de produção do SUAP (multi-stage build com UV)
# Referência: https://github.com/astral-sh/uv-docker-example/blob/main/multistage.Dockerfile
#
# A versão do Python é configurável via --build-arg PYTHON_VERSION=3.12
#
# Stage 1 (builder): instala dependências com UV
# Stage 2 (runtime): imagem mínima sem UV, apenas o venv e runtime libs

ARG PYTHON_VERSION=3.12

# ============================================================
# Stage 1: Builder
# ============================================================
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-trixie-slim AS builder

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_NO_DEV=1
ENV UV_PYTHON_DOWNLOADS=0
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências de compilação necessárias para build de pacotes Python
RUN apt-get update -qy && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    libldap2-dev \
    libsasl2-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    libfreetype6-dev \
    freetds-dev \
    libxml2-dev \
    libxslt1-dev \
    libxmlsec1-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libgdk-pixbuf2.0-dev \
    libffi-dev \
    swig \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalar dependências primeiro (sem o projeto — melhor cache de camadas)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv sync --locked --no-install-project

# Copiar código da aplicação
COPY . /app

# Sync final incluindo o projeto (non-editable para produção)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-editable

# Instalar gunicorn no venv
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install gunicorn

# ============================================================
# Stage 2: Runtime
# ============================================================
ARG PYTHON_VERSION
FROM python:${PYTHON_VERSION}-slim-trixie AS runtime

# IMPORTANTE: a imagem runtime deve ter a mesma versão de Python que o builder
# para que os paths do executável coincidam.

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Instalar apenas dependências de runtime (bibliotecas compartilhadas)
RUN apt-get update -qy && apt-get install -y --no-install-recommends \
    locales \
    curl \
    libpq5 \
    libldap-2.5-0 \
    libsasl2-2 \
    libjpeg62-turbo \
    libpng16-16 \
    zlib1g \
    libfreetype6 \
    libct4 \
    libxml2 \
    libxslt1.1 \
    libxmlsec1 \
    libcairo2 \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf-2.0-0 \
    libffi8 \
    libharfbuzz0b \
    libmagic1 \
    poppler-utils \
    qpdf \
    ghostscript \
    mupdf-tools \
    && rm -rf /var/lib/apt/lists/*

# Configurar locale pt_BR.UTF-8
RUN sed -i '/pt_BR.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Criar usuário não-root com GID/UID fixos
RUN groupadd --system --gid 999 suap \
    && useradd --system --gid 999 --uid 999 --create-home suap

# Criar diretórios necessários
RUN mkdir -p /opt/suap/deploy/static /opt/suap/deploy/media /opt/logs \
    && chown -R suap:suap /opt/suap /opt/logs

# Copiar a aplicação do builder (inclui .venv)
COPY --from=builder --chown=suap:suap /app /opt/suap

# Colocar o virtualenv no PATH
ENV PATH="/opt/suap/.venv/bin:$PATH"

WORKDIR /opt/suap

# Executar como usuário não-root
USER suap

# Expor porta do Gunicorn
EXPOSE 8000

# Comando padrão: Gunicorn servindo a aplicação SUAP
CMD ["gunicorn", "suap.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--timeout", "300", \
     "--access-logfile", "/opt/logs/gunicorn_access.log", \
     "--error-logfile", "/opt/logs/gunicorn_error.log"]

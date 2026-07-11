# docker/prod/Dockerfile - Imagem de produção do SUAP (multi-stage)
# Alinhado com Dockerfile oficial do SUAP + melhores práticas Docker
#
# Build context: raiz do repositório SUAP (onde ficam pyproject.toml e uv.lock)
# Build arg: PYTHON_VERSION (padrão: 3.12)
#
# Stage 1 (builder): compila e instala dependências Python com UV
# Stage 2 (runtime): imagem mínima com apenas runtime libs + /venv copiado

ARG PYTHON_VERSION=3.12

# ============================================================
# Stage 1: Builder
# ============================================================
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-trixie-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PYTHON=python${PYTHON_VERSION} \
    UV_PROJECT_ENVIRONMENT=/venv

ARG DEBIAN_FRONTEND=noninteractive

# Apenas headers de compilação (não ficam na imagem final)
RUN set -eux; \
    apt-get update -qy; \
    apt-get install -y --no-install-recommends \
      build-essential git swig \
      libpq-dev libldap2-dev libsasl2-dev \
      libjpeg-dev libfreetype6-dev zlib1g-dev \
      freetds-dev \
      libxml2-dev libxslt1-dev libxmlsec1-dev \
      libffi-dev \
    ; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/suap

# 1. Instalar deps sem o projeto (melhor cache — só invalida se lock mudar)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv sync --locked --group prod --no-dev --no-install-project

# 2. Copiar código + instalar projeto + gunicorn
COPY . /opt/suap
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --group prod --no-dev --no-editable && \
    uv pip install gunicorn

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM python:${PYTHON_VERSION}-slim-trixie AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LANG=pt_BR.UTF-8 \
    LANGUAGE=pt_BR:pt \
    LC_ALL=pt_BR.UTF-8 \
    TZ="America/Fortaleza" \
    PATH="/venv/bin:$PATH" \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=1 \
    GUNICORN_LOGFILE=deploy/logs/supervisor/gunicorn.log

ARG DEBIAN_FRONTEND=noninteractive

# Apenas runtime libs (sem -dev, sem compiladores)
RUN set -eux; \
    apt-get update -qy; \
    apt-get install -y --no-install-recommends \
      locales curl cron ntpdate tmpreaper \
      libpq5 libldap-2.5-0 libsasl2-2 \
      libjpeg62-turbo libfreetype6 zlib1g \
      libct4 \
      libxml2 libxslt1.1 libxmlsec1 \
      libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz-subset0 \
      libgdk-pixbuf-2.0-0 libffi8 \
      libmagic1 \
      qpdf ghostscript poppler-utils \
    ; \
    echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen pt_BR.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# Diretórios de deploy
RUN mkdir -p \
      /opt/suap/deploy/logs/supervisor \
      /opt/suap/deploy/logs/cron \
      /opt/suap/deploy/logs/history \
      /opt/suap/deploy/logs/email \
      /opt/suap/deploy/media \
      /opt/suap/static \
    && chown -R www-data:www-data /opt/suap

# Copiar artefatos do builder
COPY --from=builder --chown=www-data:www-data /opt/suap /opt/suap
COPY --from=builder --chown=www-data:www-data /venv /venv

WORKDIR /opt/suap

# NLTK + collectstatic (executa como root, depois troca)
RUN python -m nltk.downloader -d /usr/local/share/nltk_data \
      punkt_tab punkt stopwords && \
    cp suap/settings_sample.py suap/settings.py 2>/dev/null || true && \
    python manage.py collectstatic -c --no-input -v 0 2>/dev/null || true && \
    rm -f suap/settings.py && \
    ./bin/clean_pyc.sh 2>/dev/null || true

USER www-data

EXPOSE 8000

CMD ["sh", "-c", \
     "gunicorn suap.wsgi:application \
       -b 0.0.0.0:8000 \
       -w ${GUNICORN_WORKERS} \
       --threads ${GUNICORN_THREADS} \
       -t 360 \
       --max-requests 1000 \
       --max-requests-jitter 30 \
       2>&1 | tee -a ${GUNICORN_LOGFILE}"]

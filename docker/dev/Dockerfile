# docker/dev/Dockerfile - Imagem de desenvolvimento do SUAP
# Baseado na estrutura oficial do SUAP (Dockerfile.base + suap-dev)
#
# Build context: raiz do repositório SUAP (onde ficam pyproject.toml e uv.lock)
# Build arg: PYTHON_VERSION (padrão: 3.12)

ARG PYTHON_VERSION=3.12
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-trixie-slim

# --- Variáveis de ambiente ---
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PYTHON=python${PYTHON_VERSION} \
    UV_PROJECT_ENVIRONMENT=/venv \
    LANG=pt_BR.UTF-8 \
    LANGUAGE=pt_BR:pt \
    LC_ALL=pt_BR.UTF-8 \
    TZ="America/Fortaleza" \
    PATH="/venv/bin:$PATH"

# --- Dependências do sistema (camada única) ---
ARG DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    apt-get update -qy; \
    apt-get install -y --no-install-recommends \
      # Base e utilitários
      locales vim git build-essential cron ntpsec-ntpdate openssl curl wget \
      qpdf tmpreaper swig libpq-dev \
      # LDAP
      libldap2-dev libsasl2-dev \
      # Pillow
      libjpeg-dev libfreetype6-dev zlib1g-dev \
      # PyMSSQL
      freetds-dev \
      # lxml / xmlsec
      libxmlsec1-dev libxml2-dev libxslt1-dev \
      # WeasyPrint (runtime libs)
      libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz-subset0 \
      # Magic
      libmagic1 \
    ; \
    # Locale
    echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen pt_BR.UTF-8; \
    # Limpeza
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/suap

# --- Dependências Python (cache separado do código-fonte) ---
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv sync --locked --all-groups --no-install-project

# --- Dados NLTK ---
RUN python -m nltk.downloader -d /usr/local/share/nltk_data \
    punkt_tab punkt stopwords

# --- Crontab ---
COPY docker/crontab/tasks /etc/crontab

# --- Permissões e usuário ---
RUN chown www-data:www-data /opt/suap
USER www-data

EXPOSE 8000
CMD ["/bin/sh", "-c", "echo 'Starting dev container'; sleep infinity"]

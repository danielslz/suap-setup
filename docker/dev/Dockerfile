# docker/dev/Dockerfile - Imagem de desenvolvimento do SUAP
# Usa imagem oficial do UV com Python 3.12 pré-instalado
# Referência: https://docs.astral.sh/uv/guides/integration/docker/

FROM ghcr.io/astral-sh/uv:python3.12-trixie-slim

# Evitar prompts interativos durante instalação de pacotes
ENV DEBIAN_FRONTEND=noninteractive

# Configurações do UV
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=0

# Instalar dependências do sistema necessárias para compilação de pacotes Python
RUN apt-get update -qy && apt-get install -y --no-install-recommends \
    # Ferramentas de compilação e utilitários
    locales vim git build-essential openssl curl wget libpq-dev swig \
    # LDAP
    libldap2-dev libsasl2-dev \
    # Pillow
    libjpeg-dev libpng-dev zlib1g-dev libfreetype6-dev \
    # PyMSSQL
    freetds-dev \
    # lxml
    libxml2-dev libxslt1-dev libxmlsec1-dev \
    # WeasyPrint
    libcairo2-dev libpango1.0-dev libgdk-pixbuf2.0-dev libffi-dev \
    # PDF
    poppler-utils \
    # Python dev headers
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Configurar locale pt_BR.UTF-8
RUN sed -i '/pt_BR.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Definir diretório de trabalho
WORKDIR /app

# Instalar dependências (camada separada do código - melhor cache)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv sync --locked --group dev --no-install-project

# Copiar o código da aplicação
COPY . /app

# Sync final incluindo o projeto
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --group dev

# Colocar o virtualenv no PATH
ENV PATH="/app/.venv/bin:$PATH"

# Expor porta do servidor de desenvolvimento
EXPOSE 8000

# Comando padrão: rodar servidor de desenvolvimento
CMD ["uv", "run", "python", "manage.py", "runserver", "0.0.0.0:8000"]

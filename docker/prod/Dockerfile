# docker/prod/Dockerfile - Imagem de produção do SUAP (multi-stage build)
# Stage 1: builder - instala dependências Python
# Stage 2: runtime - imagem mínima com apenas o necessário para execução

# ============================================================
# Stage 1: Builder
# ============================================================
FROM python:3.12-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências de compilação necessárias para pip install
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

# Criar virtualenv para produção
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Copiar arquivos de dependências primeiro (cache de camadas)
WORKDIR /build
COPY pyproject.toml ./
COPY requirements/ ./requirements/

# Instalar dependências Python
RUN pip install --upgrade pip && \
    if [ -f pyproject.toml ]; then \
      pip install . --no-cache-dir || \
      pip install -r requirements/production.txt --no-cache-dir; \
    elif [ -d requirements ]; then \
      pip install -r requirements/production.txt --no-cache-dir; \
    fi && \
    pip install "setuptools<82.0.0" gunicorn --no-cache-dir

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM python:3.12-slim AS runtime

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

# Copiar virtualenv do builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Criar diretórios necessários
RUN mkdir -p /opt/suap /opt/suap/deploy/static /opt/suap/deploy/media /opt/logs

# Copiar código da aplicação
WORKDIR /opt/suap
COPY . .

# Criar usuário não-root para execução
RUN useradd -r -s /bin/false suap && \
    chown -R suap:suap /opt/suap /opt/logs

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

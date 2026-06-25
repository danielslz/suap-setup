# docker/dev/Dockerfile - Imagem de desenvolvimento do SUAP
# Contém todas as dependências necessárias para rodar o SUAP localmente

FROM python:3.12-slim

# Evitar prompts interativos durante instalação de pacotes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências do sistema (mesmas de deb/suap-dev.sh)
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

# Instalar UV (gerenciador de pacotes Python)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Definir diretório de trabalho
WORKDIR /app

# Copiar arquivos de dependências primeiro (para cache de camadas Docker)
COPY pyproject.toml uv.lock* ./

# Instalar dependências Python (se pyproject.toml existir)
RUN if [ -f pyproject.toml ]; then \
      uv sync --group dev || true; \
    fi

# Copiar o restante do projeto
COPY . .

# Expor porta do servidor de desenvolvimento
EXPOSE 8000

# Comando padrão: rodar servidor de desenvolvimento
CMD ["uv", "run", "python", "manage.py", "runserver", "0.0.0.0:8000"]

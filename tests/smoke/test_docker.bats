#!/usr/bin/env bats
# tests/smoke/test_docker.bats - Testes de fumaça para arquivos Docker
# Valida: Requisitos 22.1, 22.2, 23.1, 23.2

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    DEV_COMPOSE="$PROJECT_ROOT/docker/dev/docker-compose.yml"
    PROD_COMPOSE="$PROJECT_ROOT/docker/prod/docker-compose.prod.yml"
    DEV_DOCKERFILE="$PROJECT_ROOT/docker/dev/Dockerfile"
    PROD_DOCKERFILE="$PROJECT_ROOT/docker/prod/Dockerfile"
}

# ============================================================
# Validação de sintaxe YAML dos docker-compose files
# ============================================================

@test "docker-compose.yml de desenvolvimento é YAML válido" {
    run python3 -c "
import yaml, sys
with open('$DEV_COMPOSE', 'r') as f:
    yaml.safe_load(f)
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose.prod.yml de produção é YAML válido" {
    run python3 -c "
import yaml, sys
with open('$PROD_COMPOSE', 'r') as f:
    yaml.safe_load(f)
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

# ============================================================
# Validação de serviços obrigatórios no compose de desenvolvimento
# Requisito 22.2: serviços suap, db (PostgreSQL) e redis
# ============================================================

@test "docker-compose dev contém serviço 'web'" {
    run python3 -c "
import yaml
with open('$DEV_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'web' in data.get('services', {}), 'serviço web não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose dev contém serviço 'db'" {
    run python3 -c "
import yaml
with open('$DEV_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'db' in data.get('services', {}), 'serviço db não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose dev contém serviço 'redis'" {
    run python3 -c "
import yaml
with open('$DEV_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'redis' in data.get('services', {}), 'serviço redis não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

# ============================================================
# Validação de serviços obrigatórios no compose de produção
# Requisito 23.2: serviços suap, celery-worker, celery-beat,
#                  celery-flower, redis e nginx
# ============================================================

@test "docker-compose prod contém serviço 'web'" {
    run python3 -c "
import yaml
with open('$PROD_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'web' in data.get('services', {}), 'serviço web não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose prod contém serviço 'celery-worker'" {
    run python3 -c "
import yaml
with open('$PROD_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'celery-worker' in data.get('services', {}), 'serviço celery-worker não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose prod contém serviço 'celery-beat'" {
    run python3 -c "
import yaml
with open('$PROD_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'celery-beat' in data.get('services', {}), 'serviço celery-beat não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose prod contém serviço 'celery-flower'" {
    run python3 -c "
import yaml
with open('$PROD_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'celery-flower' in data.get('services', {}), 'serviço celery-flower não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose prod contém serviço 'redis'" {
    run python3 -c "
import yaml
with open('$PROD_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'redis' in data.get('services', {}), 'serviço redis não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "docker-compose prod contém serviço 'nginx'" {
    run python3 -c "
import yaml
with open('$PROD_COMPOSE', 'r') as f:
    data = yaml.safe_load(f)
assert 'nginx' in data.get('services', {}), 'serviço nginx não encontrado'
print('OK')
"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

# ============================================================
# Validação de Dockerfiles - diretivas essenciais
# Requisito 22.1: Dockerfile de desenvolvimento
# Requisito 23.1: Dockerfile de produção (multi-stage)
# ============================================================

@test "Dockerfile de desenvolvimento contém diretiva FROM" {
    run grep -q "^FROM " "$DEV_DOCKERFILE"
    [ "$status" -eq 0 ]
}

@test "Dockerfile de desenvolvimento contém diretiva COPY ou ADD" {
    run grep -qE "^(COPY|ADD) " "$DEV_DOCKERFILE"
    [ "$status" -eq 0 ]
}

@test "Dockerfile de desenvolvimento contém diretiva CMD ou ENTRYPOINT" {
    run grep -qE "^(CMD|ENTRYPOINT) " "$DEV_DOCKERFILE"
    [ "$status" -eq 0 ]
}

@test "Dockerfile de produção contém diretiva FROM" {
    run grep -q "^FROM " "$PROD_DOCKERFILE"
    [ "$status" -eq 0 ]
}

@test "Dockerfile de produção contém diretiva COPY ou ADD" {
    run grep -qE "^(COPY|ADD) " "$PROD_DOCKERFILE"
    [ "$status" -eq 0 ]
}

@test "Dockerfile de produção contém diretiva CMD ou ENTRYPOINT" {
    run grep -qE "^(CMD|ENTRYPOINT) " "$PROD_DOCKERFILE"
    [ "$status" -eq 0 ]
}

@test "Dockerfile de produção usa multi-stage build (múltiplos FROM)" {
    local from_count
    from_count=$(grep -c "^FROM " "$PROD_DOCKERFILE")
    [ "$from_count" -ge 2 ]
}

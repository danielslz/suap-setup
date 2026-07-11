#!/usr/bin/env bats
# tests/smoke/test_nginx_config.bats - Testes de fumaça para configuração Nginx
# Valida: Requisitos 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7, 21.8

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    NGINX_CONF="$PROJECT_ROOT/nginx/suap"
}

# ============================================================
# Requisito 21.1: upstream com least_conn apontando para porta 8000
# ============================================================

@test "nginx/suap contém bloco upstream com least_conn" {
    run grep -q "least_conn" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

@test "nginx/suap contém upstream apontando para porta 8000" {
    run grep -q "server 127.0.0.1:8000" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

# ============================================================
# Requisito 21.2: client_max_body_size 100m
# ============================================================

@test "nginx/suap define client_max_body_size 100m" {
    run grep -q "client_max_body_size 100m" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

# ============================================================
# Requisito 21.3: location para arquivos estáticos em /opt/suap/static
# ============================================================

@test "nginx/suap contém location para /static/" {
    run grep -q "location /static/" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

@test "nginx/suap aponta static para /opt/suap/static/" {
    run grep -q "/opt/suap/static/" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

# ============================================================
# Requisito 21.4: location para arquivos de mídia em /opt/suap/deploy/media
# ============================================================

@test "nginx/suap contém location para /media/" {
    run grep -q "location /media/" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

@test "nginx/suap aponta media para /opt/suap/deploy/media/" {
    run grep -q "/opt/suap/deploy/media/" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

# ============================================================
# Requisito 21.5: páginas de erro para 500, 502, 503, 504, 413
# ============================================================

@test "nginx/suap define error_page para 500 502 503 504" {
    run grep -q "error_page 500 502 503 504" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

@test "nginx/suap define error_page para 413" {
    run grep -q "error_page 413" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

# ============================================================
# Requisito 21.6: bloco server secundário na porta 8001
# ============================================================

@test "nginx/suap contém server block na porta 8001" {
    run grep -q "listen 8001" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

# ============================================================
# Requisito 21.7: log format customizado com request_time e upstream_response_time
# ============================================================

@test "nginx/suap define log_format customizado" {
    run grep -q "log_format" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

@test "nginx/suap inclui request_time no log format" {
    run grep -q "request_time" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

@test "nginx/suap inclui upstream_response_time no log format" {
    run grep -q "upstream_response_time" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

# ============================================================
# Requisito 21.8: proxy buffers aumentados
# ============================================================

@test "nginx/suap define proxy_buffer_size" {
    run grep -q "proxy_buffer_size" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

@test "nginx/suap define proxy_buffers" {
    run grep -q "proxy_buffers" "$NGINX_CONF"
    [ "$status" -eq 0 ]
}

### stage 1: render Jinja2 snippets
FROM python:3.12-alpine AS render
RUN pip install --no-cache-dir jinja2-cli==0.8.2
WORKDIR /work
COPY nginx/ ./nginx/
COPY frontend/ ./frontend/
# dev/stage defaults (переопределяются --build-arg)
ARG DS_NODE_ID=local-dev
ARG DS_CITY=Local
ARG DS_REGION=Dev
ARG DS_TZ=UTC
RUN set -eux; \
    mkdir -p out/etc/nginx/ds/server-includes; \
    for f in nginx/server-includes/*.j2; do \
      [ -e "$f" ] || continue; \
      jinja2 "$f" \
        -D ds_node_id="$DS_NODE_ID" \
        -D ds_city="$DS_CITY" \
        -D ds_region="$DS_REGION" \
        -D ds_tz="$DS_TZ" \
        > "out/etc/nginx/ds/server-includes/$(basename "${f%.j2}")"; \
    done; \
    cp nginx/server-includes/20-ds-api.conf out/etc/nginx/ds/server-includes/; \
    cp nginx/server-includes/30-ds-web.conf out/etc/nginx/ds/server-includes/; \
    mkdir -p out/etc/nginx/conf.d out/etc/nginx/snippets out/usr/share/nginx/html; \
    cp nginx/conf.d/00_ds_http.conf out/etc/nginx/conf.d/; \
    cp nginx/conf.d/site.conf out/etc/nginx/conf.d/; \
    cp nginx/snippets/security.conf out/etc/nginx/snippets/; \
    cp -r frontend/. out/usr/share/nginx/html/

### stage 2: runtime
FROM nginx:1.27-alpine
RUN rm -f /etc/nginx/conf.d/default.conf || true
COPY --from=render /work/out/ /
EXPOSE 80
HEALTHCHECK CMD wget -qO- http://127.0.0.1/api/ping || exit 1

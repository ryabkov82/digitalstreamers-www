FROM nginx:1.27-alpine
COPY frontend/ /usr/share/nginx/html/
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/snippets/security.conf /etc/nginx/snippets/security.conf
EXPOSE 80
HEALTHCHECK CMD wget -qO- http://127.0.0.1/api/ping || exit 1

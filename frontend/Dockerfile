# BEFORE: ~44 MB (nginx:alpine full variant + static files)
# AFTER:  ~13 MB (nginx:alpine-slim + static files, ~70% smaller)
# nginx:alpine-slim retains proxy_pass and static serving; unused modules stripped

FROM nginx:alpine-slim

COPY index.html /usr/share/nginx/html/
COPY css /usr/share/nginx/html/css
COPY js /usr/share/nginx/html/js
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

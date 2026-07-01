FROM nginx:1.27-alpine
COPY self-play-ui/ /usr/share/nginx/html/
EXPOSE 80

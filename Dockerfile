FROM ruby:3.2.2-alpine

RUN apk add postgresql-dev git build-base bash busybox-extras curl gcompat openjdk8-jre

RUN mkdir -p /data/scfair

RUN mkdir -p /opt/mimemagic
ENV FREEDESKTOP_MIME_TYPES_PATH=/opt/mimemagic

WORKDIR /srv/scfair

COPY src/Gemfile* ./
RUN bundle install

COPY ./src .

CMD ["./start.sh"]

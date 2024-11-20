FROM ruby:3.2.2-alpine

RUN apk add postgresql-dev git build-base bash busybox-extras curl gcompat

RUN mkdir -p /data/scfair

WORKDIR /srv/scfair

COPY src/Gemfile* ./
RUN bundle install

COPY ./src .

CMD ["./start.sh"]

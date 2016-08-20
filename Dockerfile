FROM hypriot/rpi-ruby

RUN apt-get update
RUN apt-get -y install build-essential 
RUN apt-get -y install vim

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
RUN bundle install --deployment --without test

COPY . /usr/src/app

CMD ["./stairlights.rb"]

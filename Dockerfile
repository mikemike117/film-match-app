FROM debian:latest AS build-env

# Install necessary build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-11-jdk

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter doctor -v
RUN flutter channel stable
RUN flutter upgrade

# Set up the app
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve the app
FROM nginx:1.21.1-alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html 
# Flutter Web Production Build
FROM debian:bullseye-slim AS build-env

# Flutter sürümü
ARG FLUTTER_VERSION=3.24.0

# Gerekli paketleri yükle
RUN apt-get update && \
    apt-get install -y curl git wget unzip libgconf-2-4 gdb libstdc++6 \
    libglu1-mesa fonts-droid-fallback lib32stdc++6 python3 && \
    apt-get clean

# Flutter SDK'yı indir ve kur
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter && \
    cd /usr/local/flutter && \
    git checkout stable

# Flutter path'i ayarla
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Flutter'ı önbelleğe al ve web desteğini etkinleştir
RUN flutter config --enable-web && \
    flutter precache --web && \
    flutter doctor -v

# Çalışma dizinini ayarla
WORKDIR /app

# Proje bağımlılıklarını kopyala
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Tüm proje dosyalarını kopyala
COPY . .

# Web için build al
RUN flutter build web --release

# Production stage - Nginx ile serve et
FROM nginx:alpine

# Build edilen dosyaları nginx'e kopyala
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Nginx konfigürasyonu
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;
    gzip_disable "MSIE [1-6]\.";
}
EOF

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

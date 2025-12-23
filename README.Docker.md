# Flutter Test_1 Docker Kullanım Kılavuzu

Bu proje Docker ile konteynerleştirilmiştir. Hem development hem de production ortamları için Docker yapılandırmaları mevcuttur.

## Gereksinimler

- Docker Desktop (Windows için)
- Docker Compose

## Production Build (Nginx ile)

Production ortamı için optimize edilmiş build:

### Build ve Çalıştırma

```powershell
# Docker image'ı oluştur ve çalıştır
docker-compose up -d --build

# Uygulamayı tarayıcıda aç
# http://localhost:8080
```

### Durdurma ve Temizleme

```powershell
# Container'ı durdur
docker-compose down

# Container ve image'ları temizle
docker-compose down --rmi all -v
```

## Development Ortamı

Hot-reload özelliği ile development:

### Çalıştırma

```powershell
# Development container'ı başlat
docker-compose -f docker-compose.dev.yml up --build

# Uygulamayı tarayıcıda aç
# http://localhost:8080
```

### Durdurma

```powershell
docker-compose -f docker-compose.dev.yml down
```

## Yararlı Docker Komutları

```powershell
# Çalışan container'ları listele
docker ps

# Tüm container'ları listele
docker ps -a

# Container loglarını görüntüle
docker logs test_1_flutter_web

# Container içine gir
docker exec -it test_1_flutter_web sh

# Image'ları listele
docker images

# Kullanılmayan image'ları temizle
docker image prune -a
```

## Port Yapılandırması

- **Production**: `http://localhost:8080`
- **Development**: `http://localhost:8080`

Port değiştirmek için `docker-compose.yml` veya `docker-compose.dev.yml` dosyalarındaki `ports` bölümünü düzenleyin:

```yaml
ports:
  - "YENİ_PORT:80"  # Production için
  - "YENİ_PORT:8080"  # Development için
```

## Notlar

- Production build, optimize edilmiş web uygulamasını Nginx ile serve eder
- Development ortamı, kod değişikliklerini gerçek zamanlı yansıtır (volume mount sayesinde)
- Asset dosyaları (`assets/sounds/`) otomatik olarak build'e dahil edilir
- Web renderer olarak CanvasKit kullanılmaktadır (daha iyi performans için)

## Sorun Giderme

### Build hatası alıyorsanız:

```powershell
# Cache'i temizle ve yeniden build al
docker-compose build --no-cache
```

### Port zaten kullanılıyorsa:

```powershell
# Kullanılan portu değiştirin veya çakışan uygulamayı kapatın
netstat -ano | findstr :8080
```

### Container başlamıyorsa:

```powershell
# Detaylı logları inceleyin
docker logs test_1_flutter_web --tail 100
```

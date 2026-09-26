#!/bin/bash
# Patakbuhin mula sa ROOT ng project mo (kasama ang App/ at AppWebApi/ folders)
# Usage: bash docker-setup.sh
set -e

echo "==> [1/6] AppWebApi/dockerfile"
if [ -f AppWebApi/dockerfile ]; then
  echo "May AppWebApi/dockerfile ka na -- hindi ito babaguhin."
else
  cat > AppWebApi/dockerfile << 'EOF'
# ---- Build Stage ----
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY Domain/Domain.csproj Domain/
COPY Application/Application.csproj Application/
COPY Infrastructure/Infrastructure.csproj Infrastructure/
COPY AppWebApi/AppWebApi.csproj AppWebApi/

RUN dotnet restore AppWebApi/AppWebApi.csproj

COPY . .

WORKDIR /src/AppWebApi
RUN dotnet publish -c Release -o /app/publish

# ---- Runtime Stage ----
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 80
ENTRYPOINT ["dotnet", "AppWebApi.dll"]
EOF
fi

echo "==> [2/6] App/nginx.conf"
if [ -f App/nginx.conf ]; then
  echo "May App/nginx.conf ka na -- hindi ito babaguhin."
else
  cat > App/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
fi

echo "==> [3/6] App/dockerfile"
if [ -f App/dockerfile ]; then
  echo "May App/dockerfile ka na -- hindi ito babaguhin."
else
  cat > App/dockerfile << 'EOF'
# ---- Build Stage ----
FROM node:22-alpine AS build
WORKDIR /app

ARG BUILD_CONFIG=production

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build -- --configuration=$BUILD_CONFIG

# ---- Runtime Stage ----
FROM nginx:alpine AS runtime
COPY --from=build /app/dist/App/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
EOF
fi

echo "==> [4/6] .env (env vars na kailangan ng docker-compose.yml)"
if [ -f .env ]; then
  echo "May .env ka na -- hindi ito babaguhin."
else
  cat > .env << 'EOF'
POSTGRES_PASSWORD=YourStrong@Passw0rd
DB_CONNECTION=Host=db;Port=5432;Database=App;Username=postgres;Password=YourStrong@Passw0rd
JWT_SECRET=CHANGE_ME
STRIPE_API_KEY=CHANGE_ME
STRIPE_WEBHOOK_SECRET=CHANGE_ME
XENDIT_API_KEY=CHANGE_ME
LALAMOVE_API_KEY=CHANGE_ME
LALAMOVE_API_SECRET=CHANGE_ME
EOF
  echo "Ginawa ang .env na may placeholder values -- palitan ang CHANGE_ME bago gamitin sa totoo."
fi

echo "==> [5/6] docker-compose.yml"
cat > docker-compose.yml << 'EOF'
services:
  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=App
    ports:
      - "5432:5432"
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 10

  backend:
    build:
      context: ./AppWebApi
      dockerfile: dockerfile
    ports:
      - "5000:8080"
    depends_on:
      db:
        condition: service_healthy
    env_file:
      - .env
    environment:
      - DOTNET_hostBuilder__reloadConfigOnChange=false
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__Defaultconnection=${DB_CONNECTION}
      - ConnectionStrings__ReadOnlyConnection=${DB_CONNECTION}
      - JwtSettings__Secret=${JWT_SECRET}
      - Stripe__ApiKey=${STRIPE_API_KEY}
      - Stripe__WebhookSecret=${STRIPE_WEBHOOK_SECRET}
      - Xendit__ApiKey=${XENDIT_API_KEY}
      - Lalamove__ApiKey=${LALAMOVE_API_KEY}
      - Lalamove__ApiSecret=${LALAMOVE_API_SECRET}

  frontend:
    build:
      context: ./App
      dockerfile: dockerfile
      args:
        BUILD_CONFIG: development
    ports:
      - "4200:80"
    depends_on:
      - backend

volumes:
  db_data:
EOF

echo "==> [6/6] docker compose up"
# COMPOSE_BAKE=false: may known bug ang bagong "bake" builder ng Docker sa
# Windows (native filesystem, hindi WSL) -- nasisira ang Dockerfile path
# resolution ("failed to read dockerfile: open dockerfile: no such file or
# directory"). Disabled dito para gamitin ang lumang classic builder.
export COMPOSE_BAKE=false
docker compose up -d --build

echo ""
echo "Frontend:  http://localhost:4200"
echo "Backend:   http://localhost:5000"
echo "DB:        localhost:5432"
echo "Logs:      docker compose logs -f"
echo "Stop:      docker compose down"
echo "Stop + wipe DB:  docker compose down -v"

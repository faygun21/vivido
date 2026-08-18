# Yalnızca docker-compose "full" profilinde kullanılır.
# Günlük geliştirmede API'yi host'ta çalıştırmak (pnpm dev:api) çok daha hızlıdır.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Önce sadece proje dosyaları — katman önbelleği için.
COPY Directory.Build.props ./
COPY Vivido.sln ./
COPY src/Vivido.Api/*.csproj                        src/Vivido.Api/
COPY src/Vivido.Application/*.csproj                src/Vivido.Application/
COPY src/Vivido.Domain/*.csproj                     src/Vivido.Domain/
COPY src/Vivido.Infrastructure/*.csproj             src/Vivido.Infrastructure/
COPY src/Vivido.Scoring/*.csproj                    src/Vivido.Scoring/
COPY tests/Vivido.Scoring.Tests/*.csproj            tests/Vivido.Scoring.Tests/
COPY tests/Vivido.Api.IntegrationTests/*.csproj     tests/Vivido.Api.IntegrationTests/
RUN dotnet restore Vivido.sln

# Sonra kaynak kodu
COPY . .
RUN dotnet publish src/Vivido.Api/Vivido.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# root olmayan kullanıcı
RUN adduser --disabled-password --gecos "" --uid 10001 vivido
USER vivido

COPY --from=build /app/publish .
EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000

ENTRYPOINT ["dotnet", "Vivido.Api.dll"]

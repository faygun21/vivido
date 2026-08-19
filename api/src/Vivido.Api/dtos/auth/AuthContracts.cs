namespace Vivido.Api.DTOs.Auth;

//Request
public record RegisterRequest(string Email, string Password, string? DisplayName);

public record LoginRequest(string Email, string Password);

public record RefreshRequest(string RefreshToken);

//Response
public record TokenPair(string AccessToken, string RefreshToken, int ExpiresIn);

//kullanıcı id'si string (uuid) formatında dönmeli, C# Guid tipini otomatik çevirir
public record AuthUser(Guid Id, string Email, string? DisplayName); 

//register ve login işlemleri aynı gövdeyi dönmelidir
public record AuthResponse(AuthUser User, TokenPair Tokens);
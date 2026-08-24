namespace Vivido.Application.dtos.location;

/// <summary>Dış konum arama sağlayıcılarının ortak sözleşmesi.</summary>
public interface IGeocodingProvider
{
    string Name { get; }
    string Attribution { get; }

    Task<IReadOnlyList<LocationSearchResultDto>> SearchAsync(
        string query,
        int limit,
        CancellationToken cancellationToken = default);
}

/// <summary>Tek bir dış konum sağlayıcısının isteği tamamlayamadığını belirtir.</summary>
public sealed class GeocodingProviderException : Exception
{
    public GeocodingProviderException(
        string providerName,
        string message,
        Exception? innerException = null)
        : base(message, innerException)
    {
        ProviderName = providerName;
    }

    public string ProviderName { get; }
}

namespace Vivido.Infrastructure.Services;

/// <summary>R-105 aramasının Çankaya dışına taşmasını önleyen coğrafi zarf.</summary>
internal static class CankayaGeocodingBounds
{
    internal const double West = 32.6265211;
    internal const double South = 39.6582726;
    internal const double East = 33.14353;
    internal const double North = 39.9374826;

    internal static bool Contains(double latitude, double longitude) =>
        latitude is >= South and <= North && longitude is >= West and <= East;
}

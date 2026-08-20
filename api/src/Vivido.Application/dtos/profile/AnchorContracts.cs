namespace Vivido.Application.dtos.profile;

/// <summary>
/// Anchor ekleme isteği.
///
/// ⚠️ <c>Priority</c> ALANI YOK — önceliği sunucu atar (K-G,
/// vivido-api-sozlesmesi.md §2). Sıralama yalnızca
/// <c>PUT /profile/anchors/order</c> ile değişir.
/// </summary>
public record CreateAnchorRequest(
    string Label,
    double Lat,
    double Lon,
    string Mode // 'foot' | 'car'
);

/// <summary>
/// Toplu yeniden sıralama. Dizideki <c>index + 1</c> = yeni <c>priority</c>.
/// </summary>
public record ReorderAnchorsRequest(
    List<string> Order
);

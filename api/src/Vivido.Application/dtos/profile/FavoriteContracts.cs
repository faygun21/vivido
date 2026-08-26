using Vivido.Application.dtos.property;

namespace Vivido.Application.Dtos.Profile;

public class AddFavoriteRequest
{
    public long PropertyId { get; set; }
}

/// <summary>
/// Favori kaydı.
///
/// <see cref="Property"/> alanı SONRADAN eklendi: eskiden yalnızca
/// `propertyId` dönüyordu ve profil sayfası "Ev ID: 4213" yazmak zorunda
/// kalıyordu — kullanıcının hangi evi favorilediğini anlamasının hiçbir yolu
/// yoktu. Konut silinmişse null olabilir (favori satırı ON DELETE CASCADE ile
/// gider, ama yarış durumunda okuma sırasında boş kalabilir).
/// </summary>
public class FavoriteResponse
{
    public long PropertyId { get; set; }
    public DateTime CreatedAt { get; set; }
    public PropertySummaryDto? Property { get; set; }
}

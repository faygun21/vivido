namespace Vivido.Application.Dtos.Profile;

public class AddFavoriteRequest
{
    public long PropertyId { get; set; }
}

public class FavoriteResponse
{
    public long PropertyId { get; set; }
    public DateTime CreatedAt { get; set; }
}
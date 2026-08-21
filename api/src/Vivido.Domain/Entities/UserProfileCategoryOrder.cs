namespace Vivido.Domain.Entities;

public class UserProfileCategoryOrder
{
    public Guid ProfileId { get; set; }

    public required string CategoryCode { get; set; }

    public short Priority { get; set; }

    public UserProfile Profile { get; set; } = null!;
}
namespace Domain.Entities
{
    public class Inventory
    {
       public int Id { get; set; }
        public string? ProductName { get; set; }
        public int AvailableQty { get; set; }
        public int ReorderPoint {  get; set; }
    }
}

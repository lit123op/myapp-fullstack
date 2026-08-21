namespace Application.Dto.Inventory.Response
{
    public class Inventorydto
    {
        //galing server
        public int Id { get; set; }
        public string? ProductName { get; set; }
        public int AvailableQty { get; set; }
        public int ReorderPoint { get; set; }
    }
}

namespace Application.Dto.Inventory.Request
{
    public class CreateInventoryRequest
    {
        //galing ui
        public string? ProductName {  get; set; }
        public int AvailableQty {  get; set; }
        public int ReorderPoint {  get; set; }
    }
}

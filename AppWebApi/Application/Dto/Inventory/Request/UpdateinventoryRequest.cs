using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Application.Dto.Inventory.Request
{
    public class UpdateInventoryRequest 
    {
        public int Id { get; set; }
        public string? ProductName { get; set; }
        public int AvailableQty { get; set; }
        public int ReorderPoint { get; set; }
    }
}

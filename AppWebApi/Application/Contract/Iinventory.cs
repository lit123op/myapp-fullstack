using Application.Dto.Generic;
using Application.Dto.Inventory.Request;
using Application.Dto.Inventory.Response;

namespace Application.Contract
{
    public interface Iinventory
    {
        Task<ApiResponse> AddInventoryAsync(CreateInventoryRequest addinventory);
        //kapag get naka Inumerable      
        Task<ApiResponse<IEnumerable<Inventorydto>>> GetAllInventoryAsync();
        Task<ApiResponse>UpdateAsync(UpdateInventoryRequest updateinventory);
        Task<ApiResponse> DeleteInventoryAsync(int id);
    }
}

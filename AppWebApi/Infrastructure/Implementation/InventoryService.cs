using Application.Contract;
using Application.Dto.Generic;
using Application.Dto.Inventory.Request;
using Application.Dto.Inventory.Response;
using Domain.Entities;
using Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
namespace Infrastructure.Implementation
{
    public class InventoryService(AppDbContext context): Iinventory
    {
        public async Task<ApiResponse> AddInventoryAsync(CreateInventoryRequest addinventory)
        {
            try
            {
                var checkname = await context.Inventory.FirstOrDefaultAsync(x => x.ProductName == addinventory.ProductName);
                if(checkname != null)
                {
                    return new ApiResponse(false, "Name Already Exist ");
                }
                else
                {
                    //
                    var newItem = new Inventory
                    {
                        ProductName = addinventory.ProductName,
                        AvailableQty = addinventory.AvailableQty,
                        ReorderPoint = addinventory.ReorderPoint
                    };
                    await context.Inventory.AddAsync(newItem);
                    await context.SaveChangesAsync();

                    return new ApiResponse(true, "Added Successful");
                }
            }
            catch(Exception ex){
            
                return new ApiResponse(false,ex.Message);
            }
        }

        public async Task<ApiResponse> DeleteInventoryAsync(int id)
        {
            try
            {
                var inventory = await context.Inventory.FirstOrDefaultAsync(x => x.Id == id);
                if (inventory == null)
                {
                    return new ApiResponse(false, "Inventory not found");
                }

                context.Inventory.Remove(inventory);
                await context.SaveChangesAsync();

                return new ApiResponse(true, "Deleted successfully");
            }
            catch (Exception ex)
            {
                return new ApiResponse(false, ex.Message);
            }
        }

        public async Task<ApiResponse<IEnumerable<Inventorydto>>> GetAllInventoryAsync()
        {
            var inventory = await context.Inventory.ToListAsync();
            if(inventory.Any())
            {
                var inventoryDtos = inventory.Select(i => new Inventorydto
                {  
                    Id= i.Id,
                    ProductName = i.ProductName,
                    AvailableQty = i.AvailableQty,
                    ReorderPoint = i.ReorderPoint
                }).ToList();
                return new ApiResponse<IEnumerable<Inventorydto>>(true,"fetched successfully", inventoryDtos);
            }
            else
            {
                return new ApiResponse<IEnumerable<Inventorydto>>(false, "No Inventory Found", null);
            }
        }


        public async Task<ApiResponse> UpdateAsync(UpdateInventoryRequest updateinventory)
        {
            try
            {
                var inventory = await context.Inventory.FirstOrDefaultAsync(x => x.Id == updateinventory.Id);
                if (inventory == null)
                {
                    return new ApiResponse(false, "Inventory not found");
                }

                inventory.ProductName = updateinventory.ProductName;
                inventory.AvailableQty = updateinventory.AvailableQty;
                inventory.ReorderPoint = updateinventory.ReorderPoint;

                context.Inventory.Update(inventory);
                await context.SaveChangesAsync();

                return new ApiResponse(true, "Updated successfully");
            }
            catch (Exception ex)
            {
                return new ApiResponse(false, ex.Message);
            }
        }
    }
}

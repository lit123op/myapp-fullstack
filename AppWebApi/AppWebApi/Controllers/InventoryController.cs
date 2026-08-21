using Application.Contract;
using Application.Dto.Inventory.Request;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace AppWebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class InventoryController(Iinventory _inventory): ControllerBase
    {
        [HttpPost]
        public async Task<IActionResult> AddInventoryAsync([FromBody] CreateInventoryRequest addinventory)
        {
            // Call the service to add inventory
            var result = await _inventory.AddInventoryAsync(addinventory);
            if (result.success)
            {
                return Ok(result);
            }
            else
            {
                return BadRequest(result);
            }
        }
        //get all inventory
        [HttpGet]
        public async Task<IActionResult> GetAllInventoryAsync()
        {
            // Call the service to get all inventory
            var result = await _inventory.GetAllInventoryAsync();
            if (result.success)
            {
                return Ok(result);
            }
            else
            {
                return BadRequest(result);
            }
        }
       
        [HttpPut] 
        public async Task<IActionResult> UpdateInventoryAsync([FromBody] UpdateInventoryRequest updateinventory)
        {
            // Call the service to update inventory
            var result = await _inventory.UpdateAsync(updateinventory);
            if (result.success)
            {
                return Ok(result);
            }
            else
            {
                return BadRequest(result);
            }
        }
         //get and need a parameter id
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteInventoryAsync(int id)
        {
            // Call the service to delete inventory
            var result = await _inventory.DeleteInventoryAsync(id);
            if (result.success)
            {
                return Ok(result);
            }
            else
            {
                return BadRequest(result);
            }
        }

    }
}

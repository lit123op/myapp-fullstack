import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CreateInventoryRequest, DeleteInventoryRequest, Inventorydto, UpdateInventoryRequest } from '../../model/Inventorydto';
import { InventoryService } from '../../services/inventoryService';

@Component({
  selector: 'app-inventory',
  imports: [FormsModule],
  templateUrl: './inventory.html',
  styleUrl: './inventory.css',
})

// Represents the Inventory component that handles inventory management.
export class Inventory implements OnInit {
  // Injects the inventoryService to handle API calls.
  constructor(private inventoryService: InventoryService) {}
  // Holds the list of inventory items retrieved from the API.
  inventoryList: Inventorydto[] = [];
// Holds the data for a new inventory item to be added.
  inventoryData: CreateInventoryRequest = {
    productName: '',
    availableQty: 0,
    reorderPoint: 0,
  };
  editData: UpdateInventoryRequest = {
    id: 0,
    productName: '',
    availableQty: 0,
    reorderPoint: 0,
  };
//delete data
  deleteData: DeleteInventoryRequest = {
    id: 0,
  };
// Lifecycle hook that is called after the component has been initialized.
  ngOnInit(): void {
    this.loadInventory();
  }

// Loads the inventory items from the API and updates the inventoryList.
  loadInventory(): void {
    this.inventoryService.GetAllInventory().subscribe({
      next: (res) => {
        if (res.success) {
          this.inventoryList = res.data ?? [];
        } else {
          alert('error: ' + res.message);
        }
      },
      error: (err) => {
        console.error('Failed to load inventory', err);
      },
    });
  }

  onsubmit(): void {
    // Validates the input fields before sending the request to add a new inventory item.
    if(this.inventoryData.productName.trim() === '' || this.inventoryData.availableQty < 0 || this.inventoryData.reorderPoint < 0) {
      alert('Please fill in all fields correctly.');
      return;
    }
    // Checks for duplicate product names in the existing inventory list.
    const checkDuplicate = this.inventoryList.find(
      item => item.productName.toLowerCase() === this.inventoryData.productName.toLowerCase());
    if (checkDuplicate) {
      alert('Product name already exists.');
      return;
    }
    // Calls the AddInventory method of the inventoryService to add a new inventory item.
    this.inventoryService.AddInventory(this.inventoryData).subscribe({
      next: (res) => {
        if (res.success) {
          alert(res.message);
          this.loadInventory();
        } else {
          alert('error: ' + res.message);
        }
      },
      error: (err) => {
        console.error('Request failed', err);
      },
    });
  }

  onEdit(item: UpdateInventoryRequest) {
    this.editData = { 
    id: item.id, 
    productName: item.productName,
    availableQty: item.availableQty,
    reorderPoint: item.reorderPoint
     };

  }
  onUpdate() {
    this.inventoryService.UpdateInventory(this.editData).subscribe({
      next: (res) => {
        if (res.success) {
          alert(res.message);
          this.loadInventory();
        } else {
          alert('error: ' + res.message);
        }
      },
      error: (err) => {
        console.error('Request failed', err);
      },
    });
  } 
  onDelete(item: Inventorydto) {
    this.deleteData.id = item.id;
    this.inventoryService.DeleteInventory(item.id).subscribe({
      next: (res) => {
        if (res.success) {
          alert(res.message);
          this.loadInventory();
        } else {
          alert('error: ' + res.message);
        }
      },
      error: (err) => {
        console.error('Request failed', err);
      },
    });
  }
}


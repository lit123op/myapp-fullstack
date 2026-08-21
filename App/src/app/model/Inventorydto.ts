//galing ui
export interface CreateInventoryRequest{

  productName: string;
  availableQty: number;
  reorderPoint: number;
}
export interface UpdateInventoryRequest{
  id: number;
  productName: string;
  availableQty: number;
  reorderPoint: number;
}
export interface DeleteInventoryRequest{
  id: number;
}
//galing server or Response from server
export interface Inventorydto{
  id: number;
  productName: string;
  availableQty: number;
  reorderPoint: number;
} 
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
//if development use environment.development.ts and for production use environment.ts
import { environment } from '../../environments/environment';
import { Inventorydto,CreateInventoryRequest, UpdateInventoryRequest } from '../model/Inventorydto';
import { ApiResponse, Response } from '../model/Api-Responsedto';

@Injectable({
  providedIn: 'root',
})
export class InventoryService {
  private apiUrl = `${environment.apiUrl}/inventory`;

  constructor(private http: HttpClient) {}

  // Sends a new inventory record to the API.
  AddInventory(request: CreateInventoryRequest): Observable<ApiResponse> {
    return this.http.post<ApiResponse>(this.apiUrl, request);
  }

  // Retrieves all inventory items from the API and expects the backend response envelope.
  GetAllInventory(): Observable<Response<Inventorydto[]>> {
    return this.http.get<Response<Inventorydto[]>>(this.apiUrl);
  }
  //update inventory
  UpdateInventory(request: UpdateInventoryRequest): Observable<ApiResponse> {
    return this.http.put<ApiResponse>(this.apiUrl, request);
  }

  //delete inventory
  DeleteInventory(id: number): Observable<ApiResponse> {
  
    return this.http.delete<ApiResponse>(`${this.apiUrl}/${id}`);
  }
}


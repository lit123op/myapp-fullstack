//for post,put,delete
export interface ApiResponse {
  success: boolean;
  message: string;
}
//for  get
export interface Response<T=any> {
    success:boolean;
    message:string;
    data:T;
}

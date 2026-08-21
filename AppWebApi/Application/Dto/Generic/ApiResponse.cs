namespace Application.Dto.Generic
{
    //for message only and use  post or put endpoint
    public record ApiResponse(bool success, string message);
    //for getting data and use in get enpoint
    //example use in interface:
    //Task<ApiResponse>serverDto>Name(requestdto name);
    public record ApiResponse<T>(bool success, string message, T? Data = default);
}



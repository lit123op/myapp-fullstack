using Infrastructure.Data;
using Infrastructure.DependencyInjection;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args
});

// Manually load config without file-watching (reloadOnChange: false)
// para maiwasan ang "inotify limit reached" crash sa restricted containers
// tulad ng Render free tier (limitado ang bilang ng file watchers doon)
builder.Configuration.Sources.Clear();
builder.Configuration
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: false)
    .AddEnvironmentVariables();

// Bind sa "PORT" environment variable na awtomatikong ibinibigay ni Render
// (nagbabago-bago ang value, hindi natin ito kinokontrol).
// "0.0.0.0" ay nagsasabing makinig sa LAHAT ng network interfaces sa loob
// ng container, hindi lang sa "localhost" (na naka-restrict lang sa loob).
// Kailangan ito dahil naghahanap si Render ng bukas na port sa 0.0.0.0
// para makumpirmang tumatakbo na ang service.
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

//install Swashbuckle.AspNetCore to enable swagger for api testing 
// Add services to the container.
builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddEndpointsApiExplorer();
//install Swashbuckle.AspNetCore to enable swagger for api testing 
//add "launchUrl": "swagger", sa launchSettings.json to open swagger page on start
builder.Services.AddSwaggerGen();

//cors
var Angularhttp = "http://localhost:4200";
//var Angularhttps = "https://localhost:4200";

builder.Services.AddCors(options=>
{
    options.AddPolicy("Angular", policy =>
       {
           policy
                 .WithOrigins(Angularhttp)
                 .AllowAnyHeader()
                 .AllowAnyMethod();
               
       });

});
var app = builder.Build();
// Auto-apply pending EF Core migrations on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}
// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
//cors
app.UseCors("Angular");
//https
// Enable HTTPS redirection
//app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
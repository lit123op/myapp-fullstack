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
builder.Services.AddHealthChecks();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddEndpointsApiExplorer();
//install Swashbuckle.AspNetCore to enable swagger for api testing 
//add "launchUrl": "swagger", sa launchSettings.json to open swagger page on start
builder.Services.AddSwaggerGen();

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();
if (allowedOrigins is null || allowedOrigins.Length == 0)
{
    allowedOrigins = new[]
    {
        "http://localhost:4200",
        "https://myapp-frontend-hr5r.onrender.com",
        "https://myapp-frontend-staging.onrender.com"
    };
}

builder.Services.AddCors(options=>
{
    options.AddPolicy("Angular", policy =>
       {
           policy
                 .WithOrigins(allowedOrigins)
                 .AllowAnyHeader()
                 .AllowAnyMethod();
               
       });

});
var app = builder.Build();
// Serialize migrations across replicas; PostgreSQL releases this session lock
// automatically if the process exits before reaching the unlock call.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.SetCommandTimeout(TimeSpan.FromMinutes(5));
    db.Database.OpenConnection();
    try
    {
        db.Database.ExecuteSqlRaw("SELECT pg_advisory_lock(74239102)");
        db.Database.Migrate();
        db.Database.ExecuteSqlRaw("SELECT pg_advisory_unlock(74239102)");
    }
    finally
    {
        db.Database.CloseConnection();
    }
}
// Configure the HTTP request pipeline.
//para lumabas ang swagger ui sa development mode lang, hindi sa production
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
app.MapHealthChecks("/health");

app.Run();
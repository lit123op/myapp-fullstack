using Application.Contract;
using Infrastructure.Data;
using Infrastructure.Implementation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
namespace Infrastructure.DependencyInjection
{
    public static class ServiceConatiner
    {
        public static IServiceCollection AddInfrastructure(this IServiceCollection services,IConfiguration config) 
        {
            services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(
            config.GetConnectionString("Defaultconnection"),
            b => b.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName)),
            ServiceLifetime.Scoped
            );

            // BAGONG DAGDAG: READ-ONLY context -- papunta sa REPLICA
            // database. Kinukuha ang "ReadOnlyConnection" mula sa
            // environment variables (na-set natin sa Terraform).
            // Hindi na natin kailangan ng MigrationsAssembly dito
            // dahil hindi naman tayo mag-mimigrate gamit ang replica.
            services.AddDbContext<AppReadOnlyDbContext>(options =>
            options.UseNpgsql(
            config.GetConnectionString("ReadOnlyConnection")),
            ServiceLifetime.Scoped
            );

            services.AddScoped<Iinventory,InventoryService>();

            return services;
        }
    }
}

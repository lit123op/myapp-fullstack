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
            var defaultConnection = config.GetConnectionString("Defaultconnection");
            if (string.IsNullOrWhiteSpace(defaultConnection))
            {
                throw new InvalidOperationException("Connection string 'Defaultconnection' is not configured.");
            }

            var readOnlyConnection = config.GetConnectionString("ReadOnlyConnection") ?? defaultConnection;

            services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(
            defaultConnection,
            b => b.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName)),
            ServiceLifetime.Scoped
            );

            // BAGONG DAGDAG: READ-ONLY context -- papunta sa REPLICA
            // database. Kinukuha ang "ReadOnlyConnection" mula sa
            // environment variables (na-set natin sa Terraform).
            // Kung walang replica connection string, gumamit ng default DB
            // para maiwasan ang runtime na mag-crash sa "ConnectionString property has not been initialized".
            services.AddDbContext<AppReadOnlyDbContext>(options =>
            options.UseNpgsql(readOnlyConnection),
            ServiceLifetime.Scoped
            );

            services.AddScoped<Iinventory,InventoryService>();

            return services;
        }
    }
}

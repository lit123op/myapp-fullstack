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
            options.UseSqlServer(
            config.GetConnectionString("Defaultconnection"),
            b => b.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName)),
            ServiceLifetime.Scoped
            );
            services.AddScoped<Iinventory,InventoryService>();

            return services;
        }
    }
}

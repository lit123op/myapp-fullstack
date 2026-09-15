using Domain.Entities;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Infrastructure.Data
{
    // Ito ay HALOS KOPYA lang ng AppDbContext -- pareho ang DbSet,
    // pareho ang structure. Ang tanging pagkakaiba: ibang klase ito,
    // kaya pwede natin itong i-register sa DI gamit ang IBANG
    // connection string (papunta sa replica, hindi sa primary).
    public class AppReadOnlyDbContext : DbContext
    {
        public AppReadOnlyDbContext(DbContextOptions<AppReadOnlyDbContext> options) : base(options)
        {
        }

        public DbSet<Inventory> Inventory { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
        }
    }
}

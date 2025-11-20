using DevBuddy.Server.Data;
using DevBuddy.Server.Data.Models;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;

namespace DevBuddy.Server.Jobs;

public class AutoFetchBackgroundService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<AutoFetchBackgroundService> _logger;
    private readonly IConfiguration _configuration;

    public AutoFetchBackgroundService(
        IServiceProvider serviceProvider,
        ILogger<AutoFetchBackgroundService> logger,
        IConfiguration configuration)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _configuration = configuration;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("AutoFetch background service started");

        // Wait a bit before starting the first fetch
        await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var autoFetchEnabled = _configuration.GetValue<bool>("GitRepos:AutoFetchEnabled", false);
                
                if (autoFetchEnabled)
                {
                    await ProcessAutoFetch(stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in AutoFetch background service");
            }

            // Wait before checking again (every 5 minutes by default)
            var intervalMinutes = _configuration.GetValue<int>("GitRepos:AutoFetchIntervalMinutes", 5);
            await Task.Delay(TimeSpan.FromMinutes(intervalMinutes), stoppingToken);
        }
    }

    private async Task ProcessAutoFetch(CancellationToken stoppingToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<DevBuddyDbContext>();
        var gitReposBasePath = _configuration["GitRepositoriesPath"] ?? "/git-repos";

        // Get repositories that are successfully cloned
        var repos = await dbContext.GitRepositories
            .Where(r => r.CloneStatus == CloneStatus.Cloned)
            .ToListAsync(stoppingToken);

        foreach (var repo in repos)
        {
            if (stoppingToken.IsCancellationRequested) break;

            try
            {
                _logger.LogInformation("Fetching updates for repository {RepoName}", repo.Name);
                
                var fullPath = Path.Combine(gitReposBasePath, repo.LocalPath);
                await ExecuteGitCommandAsync(fullPath, "fetch --all --prune", stoppingToken);
                
                repo.LastChecked = DateTime.UtcNow;
                
                _logger.LogInformation("Successfully fetched updates for repository {RepoName}", repo.Name);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch updates for repository {RepoName}", repo.Name);
            }

            await dbContext.SaveChangesAsync(stoppingToken);
        }
    }

    private async Task ExecuteGitCommandAsync(string workingDirectory, string arguments, CancellationToken token)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "git",
            Arguments = arguments,
            WorkingDirectory = workingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(startInfo);
        if (process == null)
        {
            throw new InvalidOperationException("Failed to start git process");
        }

        await process.WaitForExitAsync(token);

        if (process.ExitCode != 0)
        {
            var error = await process.StandardError.ReadToEndAsync();
            throw new InvalidOperationException($"Git command failed: {error}");
        }
    }
}

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Web;
using Wox.Plugin;
using Wox.Plugin.Logger;
using System.Runtime.Versioning;

namespace Community.PowerToys.Run.Plugin.PerplexitySearchShortcut;

[SupportedOSPlatform("windows10.0.19041.0")]
public class Main : IPlugin, IPluginI18n
{
    private PluginInitContext? _context;
    private string _iconPath = "Images\\perplexity.dark.png"; // Default path
    private const string PerplexitySearchUrl = "https://www.perplexity.ai/?q={0}";
    
    public string Name => "Perplexity Search";
    public string Description => "Search Perplexity AI directly from PowerToys Run";

    public static string PluginID => "5594ADCDFB534049A3060DCFAF3E9B01";

    
    public void Init(PluginInitContext context)
    {
        _context = context;
        
        // PowerToys recent versions use IcoPathDark/IcoPathLight properties
        var metadata = context.CurrentPluginMetadata;
        
        try 
        {
            // Try to access icon properties through reflection
            var props = metadata.GetType().GetProperties();
            foreach (var prop in props)
            {
                if (prop.Name.Contains("IcoPath") && prop.PropertyType == typeof(string))
                {
                    var value = prop.GetValue(metadata) as string;
                    if (!string.IsNullOrEmpty(value))
                    {
                        _iconPath = value;
                        break;
                    }
                }
            }
        }
        catch
        {
            // If reflection fails, just use the default icon path
            _iconPath = "Images\\perplexity.dark.png";
        }
    }

    public List<Result> Query(Query query)
    {
        var results = new List<Result>();
        
        if (!query.ActionKeyword.Equals(":p", StringComparison.OrdinalIgnoreCase))
        {
            // Remove the check for global plugins since it's not available
            return results;
        }

        if (string.IsNullOrWhiteSpace(query.Search))
        {
            results.Add(new Result
            {
                Title = "Search Perplexity AI",
                SubTitle = "Type your query to search on Perplexity AI",
                IcoPath = _iconPath,
                Action = _ => false
            });
        }
        else
        {
            string searchTerm = query.Search.Trim();
            
            results.Add(new Result
            {
                Title = $"Search Perplexity for: {searchTerm}",
                SubTitle = "Press Enter to search on Perplexity AI",
                IcoPath = _iconPath,
                Action = _ =>
                {
                    PerformPerplexitySearch(searchTerm);
                    return true;
                },
                // Remove the context menu for now as it's marked obsolete
                // We'll implement a proper context menu if needed later
            });
        }

        return results;
    }
    
    private void PerformPerplexitySearch(string searchTerm)
    {
        try
        {
            string encodedSearchTerm = HttpUtility.UrlEncode(searchTerm);
            string url = string.Format(PerplexitySearchUrl, encodedSearchTerm);
            
            // Open the URL in the default browser
            Process.Start(new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            string message = "Failed to perform Perplexity search: " + ex.Message;
            Log.Error(message, typeof(Main));
        }
    }

    public string GetTranslatedPluginTitle()
    {
        return "Perplexity Search";
    }

    public string GetTranslatedPluginDescription()
    {
        return "Search Perplexity AI directly from PowerToys Run";
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  // Plugin API provided by PluginService
  property var pluginApi: null

  // Provider metadata
  property string name: "LaTeX"
  property var launcher: null
  property bool handleSearch: false
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: true

  // Database: Array of { symbol: string, cmd: string }
  property var database: []
  property bool loaded: false
  property bool loading: false

  // Load database on init
  function init() {
    Logger.i("LatexProvider", "init called");
    if (pluginApi && pluginApi.pluginDir && !loading && !loaded) {
      loading = true;
      // Assuming database.txt is located in the same directory as this file
      databaseLoader.path = pluginApi.pluginDir + "/database.txt";
    }
  }

  // File loader for parsing the text-based database
  FileView {
    id: databaseLoader
    path: ""
    watchChanges: false

    onLoaded: {
      try {
        const rawText = text();
        const lines = rawText.split('\n');
        const parsedData = [];

        for (let i = 0; i < lines.length; i++) {
          let line = lines[i].trim();
          // Skip empty lines or comments
          if (line === "" || line.startsWith("#")) continue;

          // Split by whitespace: [Symbol] [Command]
          // Regex \s+ handles tabs or multiple spaces
          const parts = line.split(/\s+/);
          if (parts.length >= 2) {
            parsedData.push({
              symbol: parts[0],
              cmd: parts.slice(1).join(" ") // The LaTeX command
            });
          }
        }

        root.database = parsedData;
        root.loaded = true;
        root.loading = false;
        Logger.i("LatexProvider", "Database loaded,", root.database.length, "entries");
        
        if (root.launcher) {
          root.launcher.updateResults();
        }
      } catch (e) {
        Logger.e("LatexProvider", "Failed to parse database:", e);
        root.loading = false;
      }
    }
  }

  function onOpened() {
    // Reset state if necessary
  }

  // Check if this provider handles the command
  function handleCommand(searchText) {
    return searchText.startsWith(">latex");
  }

  // Return available commands when user types ">"
  function commands() {
    return [{
      "name": ">latex",
      "description": "Find LaTeX commands",
      "icon": "math-function",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function() {
        launcher.setSearchText(">latex ");
      }
    }];
  }

  // Get search results
  function getResults(searchText) {
    if (!searchText.startsWith(">latex")) {
      return [];
    }

    if (loading) {
      return [{
        "name": "Loading...",
        "description": "Processing LaTeX database...",
        "icon": "refresh",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function() {}
      }];
    }

    // Extract query after ">latex "
    var query = searchText.slice(7).trim().toLowerCase();
    var results = [];

    // If query is empty, show instructions
    if (query === "") {
        return [{
            "name": "Search LaTeX...",
            "description": "Type the name of a command (e.g. 'alpha' or 'sum')",
            "icon": "search",
            "isTablerIcon": true,
            "onActivate": function() {}
        }];
    }

    // Search Mode: Iterate through database
    // We only check if the query exists within the LaTeX command string
    for (var i = 0; i < database.length && results.length < 100; i++) {
      var entry = database[i];
      
      // Strict filter: only search within the command text
      if (entry.cmd.toLowerCase().indexOf(query) !== -1) {
        results.push(formatLatexEntry(entry));
      }
    }

    return results;
  }

  // Format a LaTeX entry for the results list
  function formatLatexEntry(entry) {
    return {
      "name": entry.cmd,           // Main text: The LaTeX code (e.g. \exclam)
      "description": entry.symbol, // Subtext: Visual representation (e.g. !)
      "icon": null,
      "isImage": false,
      "hideIcon": true, 
      "singleLine": true,
      "onActivate": function() {
        // Copy the LaTeX command to clipboard
        // Escape single quotes to prevent shell breakage
        var escaped = entry.cmd.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
        launcher.close();
      }
    };
  }
}

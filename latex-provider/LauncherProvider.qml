import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  // Plugin API provided by PluginService
  property var pluginApi: null

  // Provider metadata
  property string name: "LaTeX Symbols"
  property var launcher: null
  property bool handleSearch: false
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: true

  // Database: Array of { symbol: string, cmd: string }
  property var database: []
  property bool loaded: false
  property bool loading: false

  function init() {
    Logger.i("LatexProvider", "init called");
    if (pluginApi && pluginApi.pluginDir && !loading && !loaded) {
      loading = true;
      // Database file: database.txt in the plugin directory
      databaseLoader.path = pluginApi.pluginDir + "/database.txt";
    }
  }

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
          if (line === "" || line.startsWith("#")) continue;

          // Split by whitespace: [Symbol] [Command]
          const parts = line.split(/\s+/);
          if (parts.length >= 2) {
            parsedData.push({
              symbol: parts[0],
              cmd: parts.slice(1).join(" ") // The search keyword
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

  function onOpened() {}

  function handleCommand(searchText) {
    return searchText.startsWith(">latex");
  }

  function commands() {
    return [{
      "name": ">latex",
      "description": "Find symbols using LaTeX commands",
      "icon": "math-symbols",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function() {
        launcher.setSearchText(">latex ");
      }
    }];
  }

  function getResults(searchText) {
    if (!searchText.startsWith(">latex")) return [];

    if (loading) {
      return [{ "name": "Loading...", "icon": "refresh", "isTablerIcon": true }];
    }

    var query = searchText.slice(7).trim().toLowerCase();
    var results = [];

    if (query === "") {
        return [{
            "name": "Search Symbols...",
            "description": "Type a LaTeX command (e.g. 'alpha' to get α)",
            "icon": "search",
            "isTablerIcon": true
        }];
    }

    // Search logic: Filter database based on the command string
    for (var i = 0; i < database.length && results.length < 100; i++) {
      var entry = database[i];
      
      // We only search for the command
      if (entry.cmd.toLowerCase().indexOf(query) !== -1) {
        results.push(formatLatexEntry(entry));
      }
    }

    return results;
  }

  function formatLatexEntry(entry) {
    return {
      "name": entry.symbol,        // Display the Symbol prominently
      "description": entry.cmd,    // Show the command underneath to confirm match
      "icon": null,
      "hideIcon": true, 
      "singleLine": true,
      "onActivate": function() {
        // ACTION: Copy the SYMBOL to clipboard
        var escaped = entry.symbol.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
        launcher.close();
      }
    };
  }
}

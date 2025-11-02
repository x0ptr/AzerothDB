# AzerothDB

A lightweight, SQL-like database addon for World of Warcraft that provides persistent data storage with indexing support.

## Features

- **SQL-like API**: Familiar database operations (SELECT, INSERT, UPDATE, DELETE)
- **Primary Keys**: Automatic or manual primary key management
- **Indexes**: Create secondary indexes for fast lookups
- **Persistent Storage**: Data automatically saved between sessions
- **No Dependencies**: Pure Lua implementation

## Installation

### For Players
1. Download the latest release
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or reload UI (`/reload`)

### For Developers
Include AzerothDB as a dependency in your addon's `.toc` file:

```toc
## Dependencies: AzerothDB
```

Or as an optional dependency:

```toc
## OptionalDeps: AzerothDB
```

## Quick Start

```lua
-- Check if AzerothDB is loaded
if not AzerothDB then
    print("AzerothDB is required!")
    return
end

-- Create a table
AzerothDB:CreateTable("players", "name")

-- Insert data
AzerothDB:Insert("players", {
    name = "Thrall",
    class = "Shaman",
    level = 80
})

-- Query data
local shamans = AzerothDB:Select("players", function(row)
    return row.class == "Shaman"
end)

-- Update data
AzerothDB:Update("players", 
    function(row) return row.name == "Thrall" end,
    function(row) row.level = 85 end
)

-- Delete data
AzerothDB:Delete("players", function(row)
    return row.level < 60
end)
```

## API Reference

### Table Management

#### `CreateTable(tableName, primaryKey)`
Creates a new table with the specified primary key field.

```lua
AzerothDB:CreateTable("inventory", "itemID")
```

#### `DropTable(tableName)`
Removes a table and all its data.

```lua
AzerothDB:DropTable("inventory")
```

#### `Clear(tableName)`
Removes all rows from a table but keeps the table structure.

```lua
AzerothDB:Clear("inventory")
```

### Indexes

#### `CreateIndex(tableName, fieldName)`
Creates a secondary index on a field for faster lookups.

```lua
AzerothDB:CreateIndex("players", "class")
```

### Insert Operations

#### `Insert(tableName, row)`
Inserts a single row. Returns the primary key.

```lua
local pk = AzerothDB:Insert("players", {
    name = "Jaina",
    class = "Mage",
    level = 80
})
```

If the primary key is not provided, it will be auto-generated.

#### `InsertMany(tableName, rows)`
Inserts multiple rows at once. Returns array of primary keys.

```lua
local keys = AzerothDB:InsertMany("players", {
    {name = "Thrall", class = "Shaman", level = 80},
    {name = "Jaina", class = "Mage", level = 80}
})
```

### Select Operations

#### `Select(tableName, whereFunc)`
Returns all rows matching the condition. If `whereFunc` is nil, returns all rows.

```lua
-- Get all mages
local mages = AzerothDB:Select("players", function(row)
    return row.class == "Mage"
end)

-- Get all rows
local all = AzerothDB:Select("players")
```

#### `SelectOne(tableName, whereFunc)`
Returns the first row matching the condition, or nil.

```lua
local thrall = AzerothDB:SelectOne("players", function(row)
    return row.name == "Thrall"
end)
```

#### `SelectByPK(tableName, primaryKey)`
Fast lookup by primary key.

```lua
local player = AzerothDB:SelectByPK("players", "Thrall")
```

#### `SelectByIndex(tableName, fieldName, value)`
Fast lookup using a secondary index (must be created first).

```lua
-- Create index first
AzerothDB:CreateIndex("players", "class")

-- Fast lookup by class
local mages = AzerothDB:SelectByIndex("players", "class", "Mage")
```

### Update Operations

#### `Update(tableName, whereFunc, updateFunc)`
Updates all rows matching the condition. Returns count of updated rows.

```lua
local count = AzerothDB:Update("players",
    function(row) return row.class == "Warrior" end,
    function(row) row.level = row.level + 1 end
)
```

**Note**: Cannot modify primary keys. Use Delete + Insert instead.

#### `UpdateByPK(tableName, primaryKey, updateFunc)`
Updates a single row by primary key. Returns true if found and updated.

```lua
local success = AzerothDB:UpdateByPK("players", "Thrall", function(row)
    row.level = 85
end)
```

### Delete Operations

#### `Delete(tableName, whereFunc)`
Deletes all rows matching the condition. Returns count of deleted rows.

```lua
local count = AzerothDB:Delete("players", function(row)
    return row.level < 60
end)
```

#### `DeleteByPK(tableName, primaryKey)`
Deletes a single row by primary key. Returns count (0 or 1).

```lua
AzerothDB:DeleteByPK("players", "Thrall")
```

### Utility Functions

#### `Count(tableName, whereFunc)`
Counts rows matching the condition. If `whereFunc` is nil, counts all rows.

```lua
local mageCount = AzerothDB:Count("players", function(row)
    return row.class == "Mage"
end)

local totalPlayers = AzerothDB:Count("players")
```

## Complete Example

```lua
-- Create a quest tracking system
local function SetupQuestDB()
    -- Create table with questID as primary key
    AzerothDB:CreateTable("quests", "questID")
    
    -- Create indexes for fast lookups
    AzerothDB:CreateIndex("quests", "zone")
    AzerothDB:CreateIndex("quests", "completed")
    
    print("Quest database initialized")
end

-- Track a new quest
local function TrackQuest(questID, questName, zone)
    AzerothDB:Insert("quests", {
        questID = questID,
        name = questName,
        zone = zone,
        completed = false,
        timestamp = time()
    })
end

-- Mark quest as completed
local function CompleteQuest(questID)
    AzerothDB:UpdateByPK("quests", questID, function(row)
        row.completed = true
        row.completedTime = time()
    end)
end

-- Get all incomplete quests in a zone
local function GetIncompleteQuestsInZone(zone)
    return AzerothDB:Select("quests", function(row)
        return row.zone == zone and not row.completed
    end)
end

-- Get completed quest count
local function GetCompletedCount()
    return AzerothDB:Count("quests", function(row)
        return row.completed
    end)
end

-- Initialize on addon load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "YourAddonName" then
        if AzerothDB then
            SetupQuestDB()
        else
            print("AzerothDB required but not found!")
        end
    end
end)
```

## Performance Tips

1. **Use Indexes**: Create indexes on fields you frequently query
2. **Use Primary Key Lookups**: `SelectByPK()` is the fastest lookup method
3. **Use Index Lookups**: `SelectByIndex()` is faster than filtering with `Select()`
4. **Batch Operations**: Use `InsertMany()` for inserting multiple rows
5. **Avoid Large Scans**: Use specific `whereFunc` conditions to minimize row scanning

## Data Persistence

Data is automatically saved to `SavedVariables` when you log out. The saved data persists between:
- Game sessions
- UI reloads
- Addon updates

## Limitations

- Primary keys cannot be modified after insertion
- No built-in table joins (implement in your addon logic)
- No transaction support (changes are immediate)
- Data is character-specific (use `SavedVariablesPerCharacter` in your addon if needed)

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/x0ptr/AzerothDB).

## License

MIT License - see repository for details

## Credits

Created by [x0ptr](https://github.com/x0ptr)

## Version

Current version: 1.0.1

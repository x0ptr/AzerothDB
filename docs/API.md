# AzerothDB API

## Connections

### Create Connection
```lua
local db = AzerothDB:CreateConnection("MyAddonName")
```
Connection names must be unique. Returns `nil` on error.

---

## Connection Methods

### CreateTable(tableName, columns)
```lua
db:CreateTable("Players", {
    id = {type = "number", primary = true},
    name = {type = "string", required = true},
    level = {type = "number", default = 1}
})
```

**Column Options:**
- `type`: `"string"`, `"number"`, `"boolean"`, `"table"`
- `primary`: marks primary key (required, one per table)
- `required`: must be provided on insert
- `default`: used when value not provided

### AlterTable(tableName, columns)
```lua
db:AlterTable("Players", {
    id = {type = "number", primary = true},
    name = {type = "string", required = true},
    level = {type = "number", default = 1},
    guild = {type = "string"}
})
```
Replaces entire schema. Removes unlisted columns and their data.

### CreateIndex(tableName, fieldName)
```lua
db:CreateIndex("Players", "level")
```
Speeds up queries on the indexed field.

### Insert(tableName, row)
```lua
local id = db:Insert("Players", {name = "Arthas", level = 80})
```
Returns primary key or `nil` on error. Auto-increments if primary key not provided.

### InsertMany(tableName, rows)
```lua
local ids = db:InsertMany("Players", {
    {name = "Jaina", level = 80},
    {name = "Thrall", level = 80}
})
```
Returns array of inserted primary keys.

### Select(tableName, whereFunc)
```lua
local players = db:Select("Players", function(row)
    return row.level >= 80
end)
```
Returns array of matching rows. Omit `whereFunc` to get all rows.

### SelectByPK(tableName, primaryKey)
```lua
local player = db:SelectByPK("Players", 5)
```
Returns single row or `nil`.

### SelectByIndex(tableName, fieldName, value)
```lua
local players = db:SelectByIndex("Players", "level", 80)
```
Fast lookup using index. Returns array of rows.

### SelectOne(tableName, whereFunc)
```lua
local player = db:SelectOne("Players", function(row)
    return row.name == "Arthas"
end)
```
Returns first matching row or `nil`.

### Update(tableName, whereFunc, updateFunc)
```lua
local count = db:Update("Players", 
    function(row) return row.level < 80 end,
    function(row) row.level = 80 end
)
```
Returns number of updated rows.

### UpdateByPK(tableName, primaryKey, updateFunc)
```lua
db:UpdateByPK("Players", 5, function(row)
    row.level = row.level + 1
end)
```
Returns `true` if updated, `false` if not found.

### Delete(tableName, whereFunc)
```lua
local count = db:Delete("Players", function(row)
    return row.level < 10
end)
```
Returns number of deleted rows.

### DeleteByPK(tableName, primaryKey)
```lua
db:DeleteByPK("Players", 5)
```
Returns number of deleted rows (0 or 1).

### Count(tableName, whereFunc)
```lua
local total = db:Count("Players")
local maxLevel = db:Count("Players", function(row)
    return row.level == 80
end)
```
Returns count. Omit `whereFunc` to count all rows.

### Clear(tableName)
```lua
db:Clear("Players")
```
Deletes all rows but keeps table structure.

### DropTable(tableName)
```lua
db:DropTable("Players")
```
Completely removes table and all data.

---

## Shared Tables

Use `AzerothDB` directly instead of a connection:

```lua
AzerothDB:CreateTable("GlobalCache", {
    key = {type = "string", primary = true},
    data = {type = "table"}
})

AzerothDB:Insert("GlobalCache", {key = "itemDB", data = {...}})
local cache = AzerothDB:SelectByPK("GlobalCache", "itemDB")
```

All connection methods work on `AzerothDB` for shared tables accessible by all addons.

---

## Example

```lua
local MyAddon = {}
local db

function MyAddon:OnLoad()
    db = AzerothDB:CreateConnection("MyAddon")
    
    db:CreateTable("Settings", {
        key = {type = "string", primary = true},
        value = {type = "string", default = ""}
    })
    
    db:CreateTable("Inventory", {
        id = {type = "number", primary = true},
        itemName = {type = "string", required = true},
        count = {type = "number", default = 1}
    })
    
    db:CreateIndex("Inventory", "itemName")
end

function MyAddon:SaveSetting(key, value)
    local existing = db:SelectByPK("Settings", key)
    if existing then
        db:UpdateByPK("Settings", key, function(row)
            row.value = value
        end)
    else
        db:Insert("Settings", {key = key, value = value})
    end
end

function MyAddon:AddItem(name, count)
    db:Insert("Inventory", {itemName = name, count = count})
end

function MyAddon:GetItemsByName(name)
    return db:SelectByIndex("Inventory", "itemName", name)
end
```

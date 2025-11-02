# AzerothDB

**High-performance embedded database for World of Warcraft addons**

AzerothDB provides enterprise-grade data management with schema enforcement, connection isolation, and automatic persistence. Built for performance-critical applications requiring structured data storage and fast indexed queries.

---

## Why AzerothDB?

**Performance at Scale**  
Indexed lookups, optimized query execution, and efficient in-memory storage handle thousands of records with minimal overhead.

**Type-Safe Schema Enforcement**  
Define column types, constraints, and defaults. Prevent runtime errors with compile-time schema validation.

**Connection Isolation**  
Each addon operates in its own namespace. No conflicts, no overwrites, no data corruption.

**Battle-Tested Persistence**  
Atomic saves on logout. Automatic state restoration on load. Zero data loss.

---

## Key Features

- **Structured Schema**: Column definitions with type checking, constraints, and defaults
- **Connection Namespaces**: Isolated database contexts per addon with unique naming
- **Secondary Indexes**: O(1) lookups on indexed columns for high-frequency queries
- **Shared Tables**: Optional global tables for cross-addon data sharing
- **Schema Migrations**: `AlterTable` support for runtime schema updates
- **ACID-Like Operations**: Transactional insert/update/delete with index consistency
- **Auto-Increment Keys**: Automatic primary key generation with collision detection
- **Zero Configuration**: Automatic initialization and persistence layer

---

## Installation

### Players
1. Download the [latest release](https://github.com/x0ptr/AzerothDB/releases)
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Reload UI (`/reload`)

### Developers
Add to your `.toc` file:
```
## Dependencies: AzerothDB
```

---

## Quick Start

```lua
local db = AzerothDB:CreateConnection("MyAddon")

db:CreateTable("Players", {
    id = {type = "number", primary = true},
    name = {type = "string", required = true},
    level = {type = "number", default = 1}
})

db:CreateIndex("Players", "level")

db:Insert("Players", {name = "Arthas", level = 80})

local maxLevel = db:Select("Players", function(row)
    return row.level >= 80
end)
```

---

## Architecture

### Connection Isolation
Each addon receives a dedicated connection with isolated table storage:

```lua
local addon1 = AzerothDB:CreateConnection("Addon1")
local addon2 = AzerothDB:CreateConnection("Addon2")

addon1:CreateTable("Cache", {...})  -- Stored in Addon1 namespace
addon2:CreateTable("Cache", {...})  -- Stored in Addon2 namespace
```

Zero conflicts. Complete isolation.

### Shared Tables
For cross-addon communication, use the global namespace:

```lua
AzerothDB:CreateTable("GlobalItemDB", {
    itemId = {type = "number", primary = true},
    name = {type = "string"}
})

AzerothDB:Insert("GlobalItemDB", {itemId = 12345, name = "Thunderfury"})
```

Any addon can query shared tables without a connection.

### Performance Characteristics
- **Primary Key Lookup**: O(1) - Direct hash table access
- **Indexed Query**: O(1) + O(k) - Index lookup plus result set construction
- **Full Table Scan**: O(n) - Iterates all rows with predicate evaluation
- **Insert/Update/Delete**: O(1) + O(i) - Row operation plus index maintenance

---

## API Documentation

**[Complete API Reference →](docs/api.md)**

### Core Operations

```lua
-- Schema definition
db:CreateTable(name, columns)
db:AlterTable(name, newColumns)
db:CreateIndex(name, field)

-- Data manipulation
db:Insert(name, row)
db:InsertMany(name, rows)
db:Update(name, whereFunc, updateFunc)
db:UpdateByPK(name, pk, updateFunc)
db:Delete(name, whereFunc)
db:DeleteByPK(name, pk)

-- Queries
db:Select(name, whereFunc)
db:SelectByPK(name, pk)
db:SelectByIndex(name, field, value)
db:SelectOne(name, whereFunc)
db:Count(name, whereFunc)

-- Maintenance
db:Clear(name)
db:DropTable(name)
```

---

## Use Cases

**Configuration Management**  
Type-safe settings storage with schema validation and default values.

**Inventory Systems**  
Fast indexed lookups for items, quantities, and metadata across characters.

**Guild Databases**  
Shared tables for member rosters, DKP tracking, and event scheduling.

**Cache Layers**  
High-performance temporary storage for API responses and computed data.

**Analytics & Telemetry**  
Structured event logging with efficient time-series queries.

---

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting PRs.

### Development Setup
```bash
git clone https://github.com/x0ptr/AzerothDB.git
cd AzerothDB
# Symlink to your WoW addons folder
mklink /D "C:\World of Warcraft\_retail_\Interface\AddOns\AzerothDB" .
```

### Testing
```bash
# Run test suite
lua tests/run_tests.lua
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/x0ptr/AzerothDB/issues)
- **Documentation**: [API Reference](docs/API.md)
- **Discord**: [Join our community](https://discord.gg/zjRynUUWRT)

---

**Built with ⚡ by the AzerothDB team**
local mageCount = db:Count("players", function(row)
    return row.class == "Mage"
end)
```

## Table Namespacing

Tables are automatically prefixed with your connection namespace:

```lua
local db = AzerothDB:Connect("MyAddon")

-- Short names (auto-prefixed)
db:CreateTable("players", "id")     -- Creates "MyAddon_players"
db:Insert("players", {...})         -- Inserts into "MyAddon_players"

-- Full names (not prefixed)
db:CreateTable("MyAddon_data", "id")    -- Creates "MyAddon_data" as-is
db:Select("OtherAddon_players")         -- Access other addon's shared table
```

**Rule**: If table name contains `_`, it's used as-is. Otherwise, it's prefixed with `namespace_`.

## Access Control

| Table Type | Access |
|------------|--------|
| **Private** (`false`) | Only the creating addon can access |
| **Shared** (`true`) | Any addon can access using full name |

## Documentation

- **[API Reference](docs/API.md)** - Complete API documentation
- **[Connection Example](docs/ConnectionExample.lua)** - Example showing addon interaction
- **[Tools Documentation](tools/README.md)** - CSV conversion utilities

## Project Structure

```
AzerothDB/
├── AzerothDB.lua          # Core database with connection system
├── AzerothDB.toc          # Addon manifest
├── docs/                  # Documentation
│   ├── API.md            # API reference
│   ├── StaticData.md     # Static data guide
│   └── ConnectionExample.lua
├── tools/                 # Development tools
│   └── csv_to_static.py  # CSV converter
└── scripts/               # Build scripts
    └── build_release.bat # Package for release
```

## Performance Tips

1. **Use Indexes** - Create indexes on frequently queried fields
2. **Use Primary Key Lookups** - `SelectByPK()` is fastest
3. **Use Index Lookups** - `SelectByIndex()` is faster than filtering
4. **Batch Operations** - Use `InsertMany()` for multiple inserts

## Contributing

Issues and pull requests welcome on [GitHub](https://github.com/x0ptr/AzerothDB).

## License

MIT License

## Version

Current version: 1.0.1

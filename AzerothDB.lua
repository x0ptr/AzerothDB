AzerothDB = {
    _version = "1.0.1",
    _tables = {},
}

function AzerothDB:Initialize()
    if not AzerothDB_SavedData then
        AzerothDB_SavedData = {}
    end
    self._tables = AzerothDB_SavedData
    print("AzerothDB initialized. Version:", self._version)
end

--- TABLES AND INDEXES
function AzerothDB:CreateTable(tableName, primaryKey)
    if self._tables[tableName] then
        error("Table '" .. tableName .. "' already exists!")
        return false
    end
    
    self._tables[tableName] = {
        _pk = primaryKey,           -- Primary key field name
        _rows = {},                 -- Actual data storage
        _indexes = {},              -- Secondary indexes
        _autoIncrement = 0,         -- For auto-incrementing IDs
    }
    
    print("AzerothDB: Created table '" .. tableName .. "' with primary key '" .. primaryKey .. "'")
    return true
end

function AzerothDB:CreateIndex(tableName, fieldName)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return false
    end
    
    if tbl._indexes[fieldName] then
        print("AzerothDB: Index on '" .. fieldName .. "' already exists")
        return false
    end
    
    tbl._indexes[fieldName] = {}
    
    for pk, row in pairs(tbl._rows) do
        local value = row[fieldName]
        if value ~= nil then
            tbl._indexes[fieldName][value] = tbl._indexes[fieldName][value] or {}
            table.insert(tbl._indexes[fieldName][value], pk)
        end
    end
    
    print("AzerothDB: Created index on '" .. tableName .. "." .. fieldName .. "'")
    return true
end

--- INSERT
function AzerothDB:Insert(tableName, row)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return nil
    end
    
    local pk = row[tbl._pk]
    
    if not pk then
        tbl._autoIncrement = tbl._autoIncrement + 1
        pk = tbl._autoIncrement
        row[tbl._pk] = pk
    end
    
    if tbl._rows[pk] then
        error("Duplicate primary key '" .. tostring(pk) .. "' in table '" .. tableName .. "'")
        return nil
    end
    
    tbl._rows[pk] = row

    for fieldName, index in pairs(tbl._indexes) do
        local value = row[fieldName]
        if value ~= nil then
            index[value] = index[value] or {}
            table.insert(index[value], pk)
        end
    end
    
    return pk
end

function AzerothDB:InsertMany(tableName, rows)
    local insertedKeys = {}
    for _, row in ipairs(rows) do
        local pk = self:Insert(tableName, row)
        if pk then
            table.insert(insertedKeys, pk)
        end
    end
    return insertedKeys
end

--- SELECT
function AzerothDB:Select(tableName, whereFunc)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return {}
    end
    
    local results = {}
    
    if not whereFunc then
        for pk, row in pairs(tbl._rows) do
            table.insert(results, row)
        end
        return results
    end
    
    for pk, row in pairs(tbl._rows) do
        if whereFunc(row) then
            table.insert(results, row)
        end
    end
    
    return results
end

function AzerothDB:SelectByPK(tableName, primaryKey)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return nil
    end
    
    return tbl._rows[primaryKey]
end

function AzerothDB:SelectByIndex(tableName, fieldName, value)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return {}
    end
    
    local index = tbl._indexes[fieldName]
    if not index then
        error("No index on field '" .. fieldName .. "' in table '" .. tableName .. "'")
        return {}
    end
    
    local results = {}
    local pks = index[value] or {}
    
    for _, pk in ipairs(pks) do
        table.insert(results, tbl._rows[pk])
    end
    
    return results
end

function AzerothDB:SelectOne(tableName, whereFunc)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return nil
    end
    
    for pk, row in pairs(tbl._rows) do
        if not whereFunc or whereFunc(row) then
            return row
        end
    end
    
    return nil
end

--- UPDATE
function AzerothDB:Update(tableName, whereFunc, updateFunc)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return 0
    end
    
    local updatedCount = 0
    
    for pk, row in pairs(tbl._rows) do
        if whereFunc(row) then
            local oldValues = {}
            for fieldName, index in pairs(tbl._indexes) do
                oldValues[fieldName] = row[fieldName]
            end
            
            updateFunc(row)
            
            if row[tbl._pk] ~= pk then
                error("Cannot modify primary key! Use Delete + Insert instead.")
                return updatedCount
            end
            
            for fieldName, index in pairs(tbl._indexes) do
                local oldValue = oldValues[fieldName]
                local newValue = row[fieldName]
                
                if oldValue ~= newValue then
                    if oldValue ~= nil and index[oldValue] then
                        for i, indexPk in ipairs(index[oldValue]) do
                            if indexPk == pk then
                                table.remove(index[oldValue], i)
                                break
                            end
                        end
                    end
                    
                    if newValue ~= nil then
                        index[newValue] = index[newValue] or {}
                        table.insert(index[newValue], pk)
                    end
                end
            end
            
            updatedCount = updatedCount + 1
        end
    end
    
    return updatedCount
end

function AzerothDB:UpdateByPK(tableName, primaryKey, updateFunc)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return false
    end
    
    local row = tbl._rows[primaryKey]
    if not row then
        return false
    end
    
    local oldValues = {}
    for fieldName, index in pairs(tbl._indexes) do
        oldValues[fieldName] = row[fieldName]
    end
    
    updateFunc(row)
    
    for fieldName, index in pairs(tbl._indexes) do
        local oldValue = oldValues[fieldName]
        local newValue = row[fieldName]
        
        if oldValue ~= newValue then
            if oldValue ~= nil and index[oldValue] then
                for i, indexPk in ipairs(index[oldValue]) do
                    if indexPk == primaryKey then
                        table.remove(index[oldValue], i)
                        break
                    end
                end
            end
            
            if newValue ~= nil then
                index[newValue] = index[newValue] or {}
                table.insert(index[newValue], primaryKey)
            end
        end
    end
    
    return true
end

--- DELETE
function AzerothDB:Delete(tableName, whereFunc)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return 0
    end
    
    local deleteKeys = {}
    
    for pk, row in pairs(tbl._rows) do
        if whereFunc(row) then
            table.insert(deleteKeys, pk)
        end
    end
    
    for _, pk in ipairs(deleteKeys) do
        local row = tbl._rows[pk]
        
        for fieldName, index in pairs(tbl._indexes) do
            local value = row[fieldName]
            if value ~= nil and index[value] then
                for i, indexPk in ipairs(index[value]) do
                    if indexPk == pk then
                        table.remove(index[value], i)
                        break
                    end
                end
            end
        end
        
        tbl._rows[pk] = nil
    end
    
    return #deleteKeys
end

function AzerothDB:DeleteByPK(tableName, primaryKey)
    return self:Delete(tableName, function(row)
        return row[self._tables[tableName]._pk] == primaryKey
    end)
end


--- UTILITY
function AzerothDB:Count(tableName, whereFunc)
    local tbl = self._tables[tableName]
    if not tbl then
        return 0
    end
    
    if not whereFunc then
        local count = 0
        for _ in pairs(tbl._rows) do
            count = count + 1
        end
        return count
    end
    
    local count = 0
    for pk, row in pairs(tbl._rows) do
        if whereFunc(row) then
            count = count + 1
        end
    end
    return count
end

function AzerothDB:Clear(tableName)
    local tbl = self._tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return false
    end
    
    tbl._rows = {}
    for fieldName in pairs(tbl._indexes) do
        tbl._indexes[fieldName] = {}
    end
    tbl._autoIncrement = 0
    
    return true
end

function AzerothDB:DropTable(tableName)
    if not self._tables[tableName] then
        return false
    end
    
    self._tables[tableName] = nil
    return true
end


--- EVENT HANDLING
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "AzerothDB" then
        AzerothDB:Initialize()
    elseif event == "PLAYER_LOGOUT" then
        print("AzerothDB: Data saved")
    end
end)
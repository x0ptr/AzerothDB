AzerothDB = {
    _version = "1.2.0",
    _tables = {},
    _connections = {},
    _connectionsByName = {},
    _callbacks = {
        CREATE = {},
        INSERT = {},
        DELETE = {},
    },
    _nextCallbackId = 1,
}

function AzerothDB:Initialize()
    if not AzerothDB_SavedData then
        AzerothDB_SavedData = {
            _sharedTables = {},
            _connectionTables = {},
        }
    end
    
    if not AzerothDB_SavedData._sharedTables then
        AzerothDB_SavedData._sharedTables = {}
    end
    
    if not AzerothDB_SavedData._connectionTables then
        AzerothDB_SavedData._connectionTables = {}
    end
    
    self._tables = AzerothDB_SavedData._sharedTables
    self._callbackRegistry = {}
    
    for name, connData in pairs(AzerothDB_SavedData._connectionTables) do
        local conn = self:CreateConnection(name)
        if conn then
            conn._tables = connData
        end
    end
    
    print("AzerothDB initialized. Version:", self._version)
end

function AzerothDB:CreateConnection(name)
    if not name or type(name) ~= "string" or name == "" then
        error("Connection name must be a non-empty string!")
        return nil
    end
    
    if self._connectionsByName[name] then
        return self._connectionsByName[name]
    end
    
    local conn = {
        _name = name,
        _tables = {},
        _callbacks = {
            CREATE = {},
            INSERT = {},
            DELETE = {},
        },
        _callbackRegistry = {},
    }
    
    if not AzerothDB_SavedData then
        AzerothDB_SavedData = {
            _sharedTables = {},
            _connectionTables = {},
        }
    end
    
    if not AzerothDB_SavedData._connectionTables then
        AzerothDB_SavedData._connectionTables = {}
    end
    
    if not AzerothDB_SavedData._connectionTables[name] then
        AzerothDB_SavedData._connectionTables[name] = {}
    end
    conn._tables = AzerothDB_SavedData._connectionTables[name]
    
    self._connectionsByName[name] = conn
    table.insert(self._connections, conn)
    
    self:_bindConnectionMethods(conn)
    
    return conn
end


function AzerothDB:_bindConnectionMethods(conn)
    conn.CreateTable = function(self, tableName, columns)
        return AzerothDB:_CreateTable(conn._tables, tableName, columns)
    end
    
    conn.AlterTable = function(self, tableName, newColumns)
        return AzerothDB:_AlterTable(conn._tables, tableName, newColumns)
    end
    
    conn.CreateIndex = function(self, tableName, fieldName)
        return AzerothDB:_CreateIndex(conn._tables, tableName, fieldName)
    end
    
    conn.Insert = function(self, tableName, row)
        return AzerothDB:_Insert(conn._tables, tableName, row)
    end
    
    conn.InsertMany = function(self, tableName, rows)
        return AzerothDB:_InsertMany(conn._tables, tableName, rows)
    end
    
    conn.Select = function(self, tableName, whereFunc)
        return AzerothDB:_Select(conn._tables, tableName, whereFunc)
    end
    
    conn.SelectByPK = function(self, tableName, primaryKey)
        return AzerothDB:_SelectByPK(conn._tables, tableName, primaryKey)
    end
    
    conn.SelectByIndex = function(self, tableName, fieldName, value)
        return AzerothDB:_SelectByIndex(conn._tables, tableName, fieldName, value)
    end
    
    conn.SelectOne = function(self, tableName, whereFunc)
        return AzerothDB:_SelectOne(conn._tables, tableName, whereFunc)
    end
    
    conn.Update = function(self, tableName, whereFunc, updateFunc)
        return AzerothDB:_Update(conn._tables, tableName, whereFunc, updateFunc)
    end
    
    conn.UpdateByPK = function(self, tableName, primaryKey, updateFunc)
        return AzerothDB:_UpdateByPK(conn._tables, tableName, primaryKey, updateFunc)
    end
    
    conn.Delete = function(self, tableName, whereFunc)
        return AzerothDB:_Delete(conn._tables, tableName, whereFunc)
    end
    
    conn.DeleteByPK = function(self, tableName, primaryKey)
        return AzerothDB:_DeleteByPK(conn._tables, tableName, primaryKey)
    end
    
    conn.Count = function(self, tableName, whereFunc)
        return AzerothDB:_Count(conn._tables, tableName, whereFunc)
    end
    
    conn.Clear = function(self, tableName)
        return AzerothDB:_Clear(conn._tables, tableName)
    end
    
    conn.DropTable = function(self, tableName)
        return AzerothDB:_DropTable(conn._tables, tableName)
    end
    
    conn.Subscribe = function(self, event, callback)
        return AzerothDB:_Subscribe(conn._callbacks, conn._callbackRegistry, event, callback)
    end
    
    conn.Unsubscribe = function(self, id)
        return AzerothDB:_Unsubscribe(conn._callbacks, conn._callbackRegistry, id)
    end
end


function AzerothDB:_CreateTable(tables, tableName, columns)
    if tables[tableName] then
        return true
    end
    
    if not columns or type(columns) ~= "table" then
        error("Columns definition required!")
        return false
    end
    
    local primaryKey = nil
    for colName, colDef in pairs(columns) do
        if colDef.primary then
            if primaryKey then
                error("Only one primary key allowed!")
                return false
            end
            primaryKey = colName
        end
    end
    
    if not primaryKey then
        error("Table must have a primary key column!")
        return false
    end
    
    tables[tableName] = {
        _pk = primaryKey,
        _columns = columns,
        _rows = {},
        _indexes = {},
        _autoIncrement = 0,
    }
    
    self:_TriggerEvent(tables, "CREATE", {
        tableName = tableName,
        columns = columns,
        primaryKey = primaryKey,
    })
    
    print("AzerothDB: Created table '" .. tableName .. "' with primary key '" .. primaryKey .. "'")
    return true
end

function AzerothDB:CreateTable(tableName, columns)
    return self:_CreateTable(self._tables, tableName, columns)
end

function AzerothDB:_AlterTable(tables, tableName, newColumns)
    local tbl = tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return false
    end
    
    local newPrimaryKey = nil
    for colName, colDef in pairs(newColumns) do
        if colDef.primary then
            if newPrimaryKey then
                error("Only one primary key allowed!")
                return false
            end
            newPrimaryKey = colName
        end
    end
    
    if not newPrimaryKey then
        error("Table must have a primary key column!")
        return false
    end
    
    if newPrimaryKey ~= tbl._pk then
        error("Cannot change primary key column!")
        return false
    end
    
    local removedColumns = {}
    for colName, _ in pairs(tbl._columns) do
        if not newColumns[colName] then
            table.insert(removedColumns, colName)
        end
    end
    
    for _, colName in ipairs(removedColumns) do
        for pk, row in pairs(tbl._rows) do
            row[colName] = nil
        end
        
        if tbl._indexes[colName] then
            tbl._indexes[colName] = nil
        end
    end
    
    tbl._columns = newColumns
    
    print("AzerothDB: Altered table '" .. tableName .. "'")
    return true
end

function AzerothDB:AlterTable(tableName, newColumns)
    return self:_AlterTable(self._tables, tableName, newColumns)
end

function AzerothDB:_CreateIndex(tables, tableName, fieldName)
    local tbl = tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return false
    end
    
    if not tbl._columns[fieldName] then
        error("Field '" .. fieldName .. "' does not exist in table '" .. tableName .. "'")
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

function AzerothDB:CreateIndex(tableName, fieldName)
    return self:_CreateIndex(self._tables, tableName, fieldName)
end

function AzerothDB:_Insert(tables, tableName, row)
    local tbl = tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return nil
    end
    
    for colName, _ in pairs(row) do
        if not tbl._columns[colName] then
            error("Column '" .. colName .. "' does not exist in table '" .. tableName .. "'")
            return nil
        end
    end
    
    for colName, colDef in pairs(tbl._columns) do
        local value = row[colName]
        
        if value == nil then
            if colDef.required and not colDef.primary then
                error("Column '" .. colName .. "' is required!")
                return nil
            end
            if colDef.default ~= nil then
                row[colName] = colDef.default
            end
        elseif colDef.type then
            local valueType = type(value)
            if valueType ~= colDef.type then
                error("Column '" .. colName .. "' expects type '" .. colDef.type .. "' but got '" .. valueType .. "'")
                return nil
            end
        end
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
    
    self:_TriggerEvent(tables, "INSERT", {
        tableName = tableName,
        row = row,
        primaryKey = pk,
    })
    
    return pk
end

function AzerothDB:Insert(tableName, row)
    return self:_Insert(self._tables, tableName, row)
end

function AzerothDB:_InsertMany(tables, tableName, rows)
    local insertedKeys = {}
    for _, row in ipairs(rows) do
        local pk = self:_Insert(tables, tableName, row)
        if pk then
            table.insert(insertedKeys, pk)
        end
    end
    return insertedKeys
end

function AzerothDB:InsertMany(tableName, rows)
    return self:_InsertMany(self._tables, tableName, rows)
end

function AzerothDB:_Select(tables, tableName, whereFunc)
    local tbl = tables[tableName]
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

function AzerothDB:Select(tableName, whereFunc)
    return self:_Select(self._tables, tableName, whereFunc)
end

function AzerothDB:_SelectByPK(tables, tableName, primaryKey)
    local tbl = tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return nil
    end
    
    return tbl._rows[primaryKey]
end

function AzerothDB:SelectByPK(tableName, primaryKey)
    return self:_SelectByPK(self._tables, tableName, primaryKey)
end

function AzerothDB:_SelectByIndex(tables, tableName, fieldName, value)
    local tbl = tables[tableName]
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

function AzerothDB:SelectByIndex(tableName, fieldName, value)
    return self:_SelectByIndex(self._tables, tableName, fieldName, value)
end

function AzerothDB:_SelectOne(tables, tableName, whereFunc)
    local tbl = tables[tableName]
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

function AzerothDB:SelectOne(tableName, whereFunc)
    return self:_SelectOne(self._tables, tableName, whereFunc)
end

function AzerothDB:_Update(tables, tableName, whereFunc, updateFunc)
    local tbl = tables[tableName]
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
            
            for colName, value in pairs(row) do
                if not tbl._columns[colName] then
                    error("Column '" .. colName .. "' does not exist in table '" .. tableName .. "'")
                    return updatedCount
                end
                
                local colDef = tbl._columns[colName]
                if value ~= nil and colDef.type and type(value) ~= colDef.type then
                    error("Column '" .. colName .. "' expects type '" .. colDef.type .. "' but got '" .. type(value) .. "'")
                    return updatedCount
                end
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

function AzerothDB:Update(tableName, whereFunc, updateFunc)
    return self:_Update(self._tables, tableName, whereFunc, updateFunc)
end

function AzerothDB:_UpdateByPK(tables, tableName, primaryKey, updateFunc)
    local tbl = tables[tableName]
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
    
    if row[tbl._pk] ~= primaryKey then
        error("Cannot modify primary key! Use Delete + Insert instead.")
        return false
    end
    
    for colName, value in pairs(row) do
        if not tbl._columns[colName] then
            error("Column '" .. colName .. "' does not exist in table '" .. tableName .. "'")
            return false
        end
        
        local colDef = tbl._columns[colName]
        if value ~= nil and colDef.type and type(value) ~= colDef.type then
            error("Column '" .. colName .. "' expects type '" .. colDef.type .. "' but got '" .. type(value) .. "'")
            return false
        end
    end
    
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

function AzerothDB:UpdateByPK(tableName, primaryKey, updateFunc)
    return self:_UpdateByPK(self._tables, tableName, primaryKey, updateFunc)
end

function AzerothDB:_Delete(tables, tableName, whereFunc)
    local tbl = tables[tableName]
    if not tbl then
        error("Table '" .. tableName .. "' does not exist!")
        return 0
    end
    
    local deleteKeys = {}
    local deletedRows = {}
    
    for pk, row in pairs(tbl._rows) do
        if whereFunc(row) then
            table.insert(deleteKeys, pk)
            deletedRows[pk] = row
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
        
        self:_TriggerEvent(tables, "DELETE", {
            tableName = tableName,
            row = row,
            primaryKey = pk,
        })
    end
    
    return #deleteKeys
end

function AzerothDB:Delete(tableName, whereFunc)
    return self:_Delete(self._tables, tableName, whereFunc)
end

function AzerothDB:_DeleteByPK(tables, tableName, primaryKey)
    return self:_Delete(tables, tableName, function(row)
        return row[tables[tableName]._pk] == primaryKey
    end)
end

function AzerothDB:DeleteByPK(tableName, primaryKey)
    return self:_DeleteByPK(self._tables, tableName, primaryKey)
end


function AzerothDB:_Count(tables, tableName, whereFunc)
    local tbl = tables[tableName]
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

function AzerothDB:Count(tableName, whereFunc)
    return self:_Count(self._tables, tableName, whereFunc)
end

function AzerothDB:_Clear(tables, tableName)
    local tbl = tables[tableName]
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

function AzerothDB:Clear(tableName)
    return self:_Clear(self._tables, tableName)
end

function AzerothDB:_DropTable(tables, tableName)
    if not tables[tableName] then
        return false
    end
    
    tables[tableName] = nil
    return true
end

function AzerothDB:DropTable(tableName)
    return self:_DropTable(self._tables, tableName)
end


function AzerothDB:_Subscribe(callbacks, callbackRegistry, event, callback)
    if not callbacks[event] then
        error("Invalid event type. Must be CREATE, INSERT, or DELETE")
        return nil
    end
    
    if type(callback) ~= "function" then
        error("Callback must be a function")
        return nil
    end
    
    local id = self._nextCallbackId
    self._nextCallbackId = self._nextCallbackId + 1
    
    callbacks[event][id] = callback
    callbackRegistry[id] = event
    
    return id
end

function AzerothDB:Subscribe(event, callback)
    if not self._callbackRegistry then
        self._callbackRegistry = {}
    end
    return self:_Subscribe(self._callbacks, self._callbackRegistry, event, callback)
end

function AzerothDB:_Unsubscribe(callbacks, callbackRegistry, id)
    local event = callbackRegistry[id]
    if not event then
        return false
    end
    
    callbacks[event][id] = nil
    callbackRegistry[id] = nil
    return true
end

function AzerothDB:Unsubscribe(id)
    if not self._callbackRegistry then
        self._callbackRegistry = {}
    end
    return self:_Unsubscribe(self._callbacks, self._callbackRegistry, id)
end

function AzerothDB:_TriggerCallbacks(callbacks, event, data)
    if not callbacks[event] then
        return
    end
    
    for id, callback in pairs(callbacks[event]) do
        local success, err = pcall(callback, data)
        if not success then
            print("AzerothDB: Error in " .. event .. " callback:", err)
        end
    end
end

function AzerothDB:_TriggerEvent(tablesRef, event, data)
    local callbacksToUse = nil
    
    if tablesRef == self._tables then
        callbacksToUse = self._callbacks
    else
        for _, conn in ipairs(self._connections) do
            if conn._tables == tablesRef then
                callbacksToUse = conn._callbacks
                break
            end
        end
    end
    
    if callbacksToUse then
        self:_TriggerCallbacks(callbacksToUse, event, data)
    end
end


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
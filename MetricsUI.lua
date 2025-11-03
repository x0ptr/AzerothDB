local AzerothDB_MetricsUI = {}

function AzerothDB_MetricsUI:Initialize(db)
    self.db = db
    
    SLASH_AZEROTHDB1 = "/adb"
    SlashCmdList["AZEROTHDB"] = function(msg)
        if msg == "metrics" then
            self:ToggleMetricsFrame()
        else
            print("AzerothDB v" .. db._version)
            print("Commands:")
            print("  /adb metrics - Toggle metrics dashboard")
        end
    end
end

function AzerothDB_MetricsUI:ToggleMetricsFrame()
    if not self.metricsFrame then
        self:CreateMetricsFrame()
    end
    
    if self.metricsFrame:IsShown() then
        self.metricsFrame:Hide()
        self.db._metricsEnabled = false
        if self.metricsTimer then
            self.metricsTimer:Cancel()
            self.metricsTimer = nil
        end
    else
        self.metricsFrame:Show()
        self.db._metricsEnabled = true
        self:StartMetricsTracking()
    end
end

function AzerothDB_MetricsUI:StartMetricsTracking()
    if self.metricsTimer then
        self.metricsTimer:Cancel()
    end
    
    local db = self.db
    self.metricsTimer = C_Timer.NewTicker(1, function()
        local snapshot = {
            time = time(),
            CREATE = db._metrics.CREATE,
            INSERT = db._metrics.INSERT,
            DELETE = db._metrics.DELETE,
            UPDATE = db._metrics.UPDATE,
            SELECT = db._metrics.SELECT,
        }
        
        table.insert(db._metricsHistory, snapshot)
        
        if #db._metricsHistory > 60 then
            table.remove(db._metricsHistory, 1)
        end
        
        AzerothDB_MetricsUI:UpdateMetricsDisplay()
    end)
end

function AzerothDB_MetricsUI:CreateMetricsFrame()
    local frame = CreateFrame("Frame", "AzerothDBMetricsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -5)
    frame.title:SetText("AzerothDB Metrics")
    
    frame.stats = frame:CreateFontString(nil, "OVERLAY")
    frame.stats:SetFontObject("GameFontNormal")
    frame.stats:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -35)
    frame.stats:SetJustifyH("LEFT")
    
    local canvasFrame = CreateFrame("Frame", nil, frame)
    canvasFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -100)
    canvasFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
    frame.canvas = canvasFrame
    
    frame.bars = {}
    local operations = {"CREATE", "INSERT", "DELETE", "UPDATE", "SELECT"}
    local colors = {
        CREATE = {0.2, 0.8, 0.2},
        INSERT = {0.2, 0.6, 1.0},
        DELETE = {1.0, 0.2, 0.2},
        UPDATE = {1.0, 0.8, 0.2},
        SELECT = {0.8, 0.4, 1.0},
    }
    
    for i, op in ipairs(operations) do
        local barHeight = 60
        local spacing = 10
        local yOffset = -(i - 1) * (barHeight + spacing)
        
        local label = canvasFrame:CreateFontString(nil, "OVERLAY")
        label:SetFontObject("GameFontNormalLarge")
        label:SetPoint("TOPLEFT", canvasFrame, "TOPLEFT", 0, yOffset)
        label:SetText(op)
        
        local bar = CreateFrame("Frame", nil, canvasFrame)
        bar:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        bar:SetSize(500, 30)
        
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        local fill = bar:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
        fill:SetHeight(30)
        fill:SetWidth(0)
        fill:SetColorTexture(unpack(colors[op]))
        
        local count = bar:CreateFontString(nil, "OVERLAY")
        count:SetFontObject("GameFontHighlight")
        count:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
        
        frame.bars[op] = {
            bar = bar,
            fill = fill,
            count = count,
            label = label,
        }
    end
    
    self.metricsFrame = frame
    frame:Hide()
end

function AzerothDB_MetricsUI:UpdateMetricsDisplay()
    if not self.metricsFrame or not self.metricsFrame:IsShown() then
        return
    end
    
    local db = self.db
    local maxValue = 0
    for _, value in pairs(db._metrics) do
        if value > maxValue then
            maxValue = value
        end
    end
    
    if maxValue == 0 then
        maxValue = 1
    end
    
    local operations = {"CREATE", "INSERT", "DELETE", "UPDATE", "SELECT"}
    for _, op in ipairs(operations) do
        local count = db._metrics[op] or 0
        local bar = self.metricsFrame.bars[op]
        local percent = count / maxValue
        bar.fill:SetWidth(500 * percent)
        bar.count:SetText(tostring(count))
    end
    
    local totalOps = 0
    for _, value in pairs(db._metrics) do
        totalOps = totalOps + value
    end
    
    local statsText = string.format(
        "Total Operations: %d\nHistory: %d snapshots",
        totalOps,
        #db._metricsHistory
    )
    self.metricsFrame.stats:SetText(statsText)
end

AzerothDB.MetricsUI = AzerothDB_MetricsUI

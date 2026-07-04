local function getService(name)
    local svc = game:GetService(name)
    if cloneref then return cloneref(svc) end
    return svc
end

local Players = getService("Players")
local RunService = getService("RunService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local cache = {}

local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local ESP_SETTINGS = {
    BoxOutlineColor = Color3.new(0, 0, 0),
    BoxColor = Color3.new(1, 1, 1),
    NameColor = Color3.new(1, 1, 1),
    HealthOutlineColor = Color3.new(0, 0, 0),
    HealthHighColor = Color3.new(0, 1, 0),
    HealthLowColor = Color3.new(1, 0, 0),
    CharSize = Vector2.new(4, 6),
    Teamcheck = false,
    WallCheck = false,
    Enabled = false,
    ShowBox = false,
    BoxType = "2D",
    ShowName = false,
    ShowHealth = false,
    ShowDistance = false,
    ShowSkeletons = false,
    ShowTracer = false,
    TracerColor = Color3.new(1, 1, 1),
    TracerThickness = 2,
    SkeletonsColor = Color3.new(1, 1, 1),
    TracerPosition = "Bottom",
    IncludeBots = false
}

local function createDrawing(class, properties)
    local drawing = Drawing.new(class)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

local function createEsp(target)
    local esp = {
        tracer = createDrawing("Line", {
            Thickness = ESP_SETTINGS.TracerThickness,
            Color = ESP_SETTINGS.TracerColor,
            Transparency = 0.5
        }),
        boxOutline = createDrawing("Square", {
            Color = ESP_SETTINGS.BoxOutlineColor,
            Thickness = 3,
            Filled = false
        }),
        box = createDrawing("Square", {
            Color = ESP_SETTINGS.BoxColor,
            Thickness = 1,
            Filled = false
        }),
        name = createDrawing("Text", {
            Color = ESP_SETTINGS.NameColor,
            Outline = true,
            Center = true,
            Size = 13
        }),
        healthOutline = createDrawing("Line", {
            Thickness = 3,
            Color = ESP_SETTINGS.HealthOutlineColor
        }),
        health = createDrawing("Line", {
            Thickness = 1
        }),
        distance = createDrawing("Text", {
            Color = Color3.new(1, 1, 1),
            Size = 12,
            Outline = true,
            Center = true
        }),
        boxLines = {},
        skeletonlines = {}
    }
    cache[target] = esp
    return esp
end

local function isBehindWall(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local ray = Ray.new(camera.CFrame.Position, (rootPart.Position - camera.CFrame.Position).Unit * (rootPart.Position - camera.CFrame.Position).Magnitude)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {localPlayer.Character, character})
    return hit and hit:IsA("Part")
end

local function removeEsp(target)
    local esp = cache[target]
    if not esp then return end
    for _, drawing in pairs(esp) do
        if type(drawing) == "table" and drawing.Remove then
            drawing:Remove()
        end
    end
    for _, line in ipairs(esp.boxLines) do
        line:Remove()
    end
    for _, lineData in ipairs(esp.skeletonlines) do
        lineData[1]:Remove()
    end
    cache[target] = nil
end

local function getTargets()
    local targets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local character = player.Character
            if character and character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").Health > 0 then
                targets[character] = {type = "player", player = player}
            end
        end
    end
    if ESP_SETTINGS.IncludeBots then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                local humanoid = obj:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 and not cache[obj] then
                    targets[obj] = {type = "bot"}
                end
            end
        end
    end
    return targets
end

local function updateEsp()
    local targets = getTargets()
    for character, info in pairs(targets) do
        if not cache[character] then
            createEsp(character)
        end
    end
    for target, esp in pairs(cache) do
        if not targets[target] then
            removeEsp(target)
        end
    end

    for target, esp in pairs(cache) do
        local character = target
        local team = nil
        if targets[character] and targets[character].type == "player" then
            team = targets[character].player.Team
        end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local valid = rootPart and head and humanoid and humanoid.Health > 0
        if not valid then continue end

        local shouldShow = true
        if ESP_SETTINGS.Teamcheck and team and team == localPlayer.Team then
            shouldShow = false
        end
        if ESP_SETTINGS.WallCheck and isBehindWall(character) then
            shouldShow = false
        end
        if not ESP_SETTINGS.Enabled then
            shouldShow = false
        end

        for _, drawing in pairs(esp) do
            if type(drawing) == "table" and drawing.Remove then
                drawing.Visible = false
            end
        end
        for _, line in ipairs(esp.boxLines) do
            line.Visible = false
        end
        for _, lineData in ipairs(esp.skeletonlines) do
            lineData[1].Visible = false
        end

        if not shouldShow then continue end

        local hrp2D = camera:WorldToViewportPoint(rootPart.Position)
        local charSize = (camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0)).Y - camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2.6, 0)).Y) / 2
        local boxSize = Vector2.new(math.floor(charSize * 1.8), math.floor(charSize * 1.9))
        local boxPosition = Vector2.new(math.floor(hrp2D.X - charSize * 1.8 / 2), math.floor(hrp2D.Y - charSize * 1.6 / 2))

        if ESP_SETTINGS.ShowName then
            esp.name.Visible = true
            local displayName = targets[character] and targets[character].type == "player" and targets[character].player.Name or character.Name
            esp.name.Text = string.lower(displayName)
            esp.name.Position = Vector2.new(boxSize.X / 2 + boxPosition.X, boxPosition.Y - 16)
            esp.name.Color = ESP_SETTINGS.NameColor
        end

        if ESP_SETTINGS.ShowBox then
            if ESP_SETTINGS.BoxType == "2D" then
                esp.boxOutline.Size = boxSize
                esp.boxOutline.Position = boxPosition
                esp.box.Size = boxSize
                esp.box.Position = boxPosition
                esp.box.Color = ESP_SETTINGS.BoxColor
                esp.box.Visible = true
                esp.boxOutline.Visible = true
                for _, line in ipairs(esp.boxLines) do line:Remove() end
                esp.boxLines = {}
            elseif ESP_SETTINGS.BoxType == "Corner Box Esp" then
                local lineW = boxSize.X / 5
                local lineH = boxSize.Y / 6
                local lineT = 1

                if #esp.boxLines == 0 then
                    for i = 1, 16 do
                        local boxLine = createDrawing("Line", {
                            Thickness = 1,
                            Color = ESP_SETTINGS.BoxColor,
                            Transparency = 1
                        })
                        esp.boxLines[i] = boxLine
                    end
                end

                local boxLines = esp.boxLines
                boxLines[1].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                boxLines[1].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y - lineT)
                boxLines[2].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                boxLines[2].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + lineH)
                boxLines[3].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y - lineT)
                boxLines[3].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                boxLines[4].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                boxLines[4].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + lineH)
                boxLines[5].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y - lineH)
                boxLines[5].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                boxLines[6].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                boxLines[6].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y + lineT)
                boxLines[7].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y + lineT)
                boxLines[7].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
                boxLines[8].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y - lineH)
                boxLines[8].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
                for i = 9, 16 do
                    boxLines[i].Thickness = 2
                    boxLines[i].Color = ESP_SETTINGS.BoxOutlineColor
                    boxLines[i].Transparency = 1
                end
                boxLines[9].From = Vector2.new(boxPosition.X, boxPosition.Y)
                boxLines[9].To = Vector2.new(boxPosition.X, boxPosition.Y + lineH)
                boxLines[10].From = Vector2.new(boxPosition.X, boxPosition.Y)
                boxLines[10].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y)
                boxLines[11].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y)
                boxLines[11].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)
                boxLines[12].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)
                boxLines[12].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + lineH)
                boxLines[13].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y - lineH)
                boxLines[13].To = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)
                boxLines[14].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)
                boxLines[14].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y)
                boxLines[15].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y)
                boxLines[15].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)
                boxLines[16].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y - lineH)
                boxLines[16].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)
                for _, line in ipairs(boxLines) do line.Visible = true end
                esp.box.Visible = false
                esp.boxOutline.Visible = false
            end
        end

        if ESP_SETTINGS.ShowHealth then
            local health = humanoid.Health
            local maxHealth = humanoid.MaxHealth
            local healthPercentage = health / maxHealth
            esp.healthOutline.Visible = true
            esp.health.Visible = true
            esp.healthOutline.From = Vector2.new(boxPosition.X - 6, boxPosition.Y + boxSize.Y)
            esp.healthOutline.To = Vector2.new(esp.healthOutline.From.X, esp.healthOutline.From.Y - boxSize.Y)
            esp.health.From = Vector2.new(boxPosition.X - 5, boxPosition.Y + boxSize.Y)
            esp.health.To = Vector2.new(esp.health.From.X, esp.health.From.Y - healthPercentage * boxSize.Y)
            esp.health.Color = ESP_SETTINGS.HealthLowColor:Lerp(ESP_SETTINGS.HealthHighColor, healthPercentage)
        end

        if ESP_SETTINGS.ShowDistance then
            local distance = (camera.CFrame.Position - rootPart.Position).Magnitude
            esp.distance.Text = string.format("%.1f studs", distance)
            esp.distance.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 5)
            esp.distance.Visible = true
        end

        if ESP_SETTINGS.ShowSkeletons then
            if #esp.skeletonlines == 0 then
                for _, bonePair in ipairs(bones) do
                    if character:FindFirstChild(bonePair[1]) and character:FindFirstChild(bonePair[2]) then
                        local line = createDrawing("Line", {
                            Thickness = 1,
                            Color = ESP_SETTINGS.SkeletonsColor,
                            Transparency = 1
                        })
                        table.insert(esp.skeletonlines, {line, bonePair[1], bonePair[2]})
                    end
                end
            end
            for _, lineData in ipairs(esp.skeletonlines) do
                local skeletonLine, parentBone, childBone = lineData[1], lineData[2], lineData[3]
                if character:FindFirstChild(parentBone) and character:FindFirstChild(childBone) then
                    local parentPos = camera:WorldToViewportPoint(character[parentBone].Position)
                    local childPos = camera:WorldToViewportPoint(character[childBone].Position)
                    skeletonLine.From = Vector2.new(parentPos.X, parentPos.Y)
                    skeletonLine.To = Vector2.new(childPos.X, childPos.Y)
                    skeletonLine.Visible = true
                end
            end
        end

        if ESP_SETTINGS.ShowTracer then
            local tracerY = ESP_SETTINGS.TracerPosition == "Top" and 0
                or ESP_SETTINGS.TracerPosition == "Middle" and camera.ViewportSize.Y / 2
                or camera.ViewportSize.Y
            esp.tracer.Visible = true
            esp.tracer.From = Vector2.new(camera.ViewportSize.X / 2, tracerY)
            esp.tracer.To = Vector2.new(hrp2D.X, hrp2D.Y)
            esp.tracer.Color = ESP_SETTINGS.TracerColor
        end
    end
end

RunService.RenderStepped:Connect(updateEsp)

return ESP_SETTINGS

function love.load()
    love.window.setTitle("LOVE2D Lua Simple Calculator")
    love.window.setMode(380, 640, {resizable = false, minwidth = 320, minheight = 560, msaa = 4, vsync = 1, highdpi = true})
    love.graphics.setDefaultFilter('nearest', 'nearest', 1)

    fonts = {}
    fonts.display = love.graphics.newFont(40)
    fonts.button = love.graphics.newFont(22)
    fonts.small = love.graphics.newFont(14)

    colors = {
        bg = {0.10, 0.12, 0.14},
        panel = {0.13, 0.16, 0.19},
        text = {0.95, 0.96, 0.97},
        subtext = {0.75, 0.78, 0.80},
        btn = {0.20, 0.23, 0.27},
        btnHover = {0.25, 0.28, 0.32},
        btnActive = {0.18, 0.21, 0.25},
        accent = {0.98, 0.56, 0.19},
        accentHover = {0.99, 0.62, 0.28},
        danger = {0.86, 0.20, 0.28}
    }

    calc = {
        expression = "",
        display = "0",
        justEvaluated = false
    }

    grid = {
        pad = 16,
        gap = 10,
        cols = 4,
        rows = 5,
        top = 180,
        btnH = 80
    }

    rowsDef = {
        {
            {txt = "C", type = "ctrl"}, {txt = "+/-", type = "ctrl"}, {txt = "%", type = "ctrl"}, {txt = "÷", type = "op"}
        },
        {
            {txt = "7", type = "num"}, {txt = "8", type = "num"}, {txt = "9", type = "num"}, {txt = "×", type = "op"}
        },
        {
            {txt = "4", type = "num"}, {txt = "5", type = "num"}, {txt = "6", type = "num"}, {txt = "−", type = "op"}
        },
        {
            {txt = "1", type = "num"}, {txt = "2", type = "num"}, {txt = "3", type = "num"}, {txt = "+", type = "op"}
        },
        {
            {txt = "0", type = "num", span = 2}, {txt = ".", type = "num"}, {txt = "=", type = "eq"}
        }
    }

    buttons = {}
    gridCells = {}
    layoutButtons()
    selRow, selCol = 1, 1
end

function love.update(dt)
    local mx, my = love.mouse.getPosition()
    for k, btn in pairs(buttons) do
        btn.hover = pointInRect(mx, my, btn.x, btn.y, btn.w, btn.h)
    end
end

function roundRect(mode, x, y, w, h, rad)
    rad = math.min(rad or 10, math.min(w, h) / 2)
    love.graphics.rectangle(mode, x, y, w, h, rad, rad)
end

function pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function layoutButtons()
    local W, H = love.graphics.getDimensions()
    local pad, gap = grid.pad, grid.gap
    local cols = grid.cols
    local startY = grid.top
    local gapTotal = gap * (cols - 1)
    local contentW = W - pad * 2
    local unitW = (contentW - gapTotal) / cols
    local h = grid.btnH

    for rowIdx, row in ipairs(rowsDef) do
        gridCells[rowIdx] = {}
        local x = pad
        for colIdx, def in ipairs(row) do
            local span = def.span or 1
            local w = unitW * span + gap * (span - 1)
            local btn = {
                txt = def.txt,
                type = def.type,
                x = math.floor(x + 0.5),
                y = math.floor(startY + 0.5),
                w = math.floor(w + 0.5),
                h = math.floor(h + 0.5),
                hover = false,
                active = false,
                row = rowIdx,
                colStart = colIdx,
                colEnd = colIdx + span - 1
            }
            table.insert(buttons, btn)
            for c = btn.colStart, btn.colEnd do
                gridCells[rowIdx][c] = #buttons
            end
            x = x + w + gap
        end
        startY = startY + h + gap
    end
end

function safeEval(expr)
    expr = expr:gsub("÷", "/"):gsub("×", "*"):gsub("−", "-")
    if expr:match("[^0-9%+%-%*/%%%.%(%)%s]") then
        return nil, "Invalid character"
    end
    local func, err = load("return " .. expr)
    if not func then return nil, err end
    local ok, res = pcall(func)
    if not ok or res == nil or res ~= res or res == math.huge or res == -math.huge then
        return nil, "Error"
    end
    return res
end

function findLastNumberSpan(s)
    local start, finish
    local i = #s
    while i > 0 do
        local c = s:sub(i,i)
        if c:match("[0-9%.]") then
            finish = finish or i
            start = i
        elseif c == '-' then
            if i==1 or s:sub(i-1,i-1):match("[%+%-%*/%(%)]") then
                start = i
            end
            break
        elseif finish then
            break
        end
        i = i - 1
    end
    return start, finish
end

function applyPercent()
    local s = calc.expression
    if s == "" then s = calc.display end
    local a, b = findLastNumberSpan(s)
    if not a then return end
    local num = tonumber(s:sub(a,b))
    if not num then return end
    num = num / 100
    calc.expression = s:sub(1, a-1) .. tostring(num) .. s:sub(b+1)
    calc.display = calc.expression
end

function toggleSign()
    local s = calc.expression
    if s == "" then s = calc.display end
    local a, b = findLastNumberSpan(s)
    if not a then return end
    local num = tonumber(s:sub(a,b))
    if not num then return end
    num = -num
    calc.expression = s:sub(1, a-1) .. tostring(num) .. s:sub(b+1)
    calc.display = calc.expression
end

function pushToken(t)
    if t:match("[%+%-×÷−]") and calc.justEvaluated then
        calc.expression = calc.display
        calc.justEvaluated = false
    end

    if calc.justEvaluated and t:match("[0-9%.]") then
        calc.expression = ""
        calc.justEvaluated = false
    end

    if t:match("[%+%-×÷−]") then
        if calc.expression == "" and t ~= "-" and t ~= "−" then return end
        local lastChar = calc.expression:sub(-1,-1)
        if lastChar:match("[%+%-×÷−]") then
            calc.expression = calc.expression:sub(1,-2) .. t
        else
            calc.expression = calc.expression .. t
        end
    else
        calc.expression = calc.expression .. t
    end
    calc.display = calc.expression
end

function evaluate()
    local expr = calc.expression ~= "" and calc.expression or calc.display
    if expr == "" then return end
    local res, err = safeEval(expr)
    if not res then
        calc.display = "Error"
        calc.expression = ""
        calc.justEvaluated = false
        return
    end
    calc.display = tostring(res)
    calc.expression = calc.display
    calc.justEvaluated = true
end

function handleButton(txt, kind)
    if kind == "num" then
        if txt == "." then
            local s = calc.expression
            local a,b = findLastNumberSpan(s)
            local seg = s:sub(a or 1, b or -1)
            if seg:find("%.") then return end
        end
        pushToken(txt)
    elseif kind == "op" then
        pushToken(txt)
    elseif kind == "ctrl" then
        if txt == "C" then
            calc.expression = ""
            calc.display = "0"
            calc.justEvaluated = false
        elseif txt == "+/-" then
            toggleSign()
        elseif txt == "%" then
            applyPercent()
        end
    elseif kind == "eq" then
        evaluate()
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    for _, b in ipairs(buttons) do
        if pointInRect(x, y, b.x, b.y, b.w, b.h) then
            b.active = true
        end
    end
end

function love.mousereleased(x, y, button)
    if button ~= 1 then return end
    for k, b in ipairs(buttons) do
        if b.active and pointInRect(x, y, b.x, b.y, b.w, b.h) then
            handleButton(b.txt, b.type)
            b.active = false
            break
        end
        b.active = false
    end
end

function love.textinput(t)
    if t:match("%d") then
        handleButton(t, "num")
    elseif t == "," or t == "." then
        handleButton(".", "num")
    else
        local ops = {
            ['+'] = '+', 
            ['-'] = '−', 
            ['*'] = '×', 
            ['/'] = '÷', 
            ['x'] = '×'
        }
        if ops[t] then
            handleButton(ops[t], 'op')
        end
    end
end

function love.keypressed(key)
    local keyActions = {
        ['+'] = function() handleButton('+', 'op') end,
        ['-'] = function() handleButton('−', 'op') end,
        ['*'] = function() handleButton('×', 'op') end,
        ['/'] = function() handleButton('÷', 'op') end,
        ['return'] = function() handleButton('=', 'eq') end,
        ['kpenter'] = function() handleButton('=', 'eq') end,
        ['space'] = function()
            if gridCells[selRow] and gridCells[selRow][selCol] then
                local b = buttons[gridCells[selRow][selCol]]
                handleButton(b.txt, b.type)
            end
        end,
        ['backspace'] = function()
            if calc.expression ~= "" then
                calc.expression = calc.expression:sub(1,-2)
                calc.display = calc.expression == "" and "0" or calc.expression
            end
        end,
        ['escape'] = function()
            calc.expression = ""
            calc.display = "0"
            calc.justEvaluated = false
        end,
        ['%'] = function() applyPercent() end
    }
    
    if keyActions[key] then
        keyActions[key]()
        return
    end
    
    if key == 'left' or key == 'right' or key == 'up' or key == 'down' then
        local dr = (key == 'up' and -1) or (key == 'down' and 1) or 0
        local dc = (key == 'left' and -1) or (key == 'right' and 1) or 0
        
        local r, c = selRow, selCol
        local newR, newC = r + dr, c + dc
        
        while newR >= 1 and newR <= grid.rows and newC >=1 and newC <= grid.cols do
            if gridCells[newR] and gridCells[newR][newC] then
                selRow, selCol = newR, newC
                return
            end
            newR = newR + dr
            newC = newC + dc
        end
    end
end

function love.draw()
    love.graphics.clear(colors.bg)

    local W, H = love.graphics.getDimensions()

    love.graphics.setColor(colors.panel)
    roundRect('fill', 12, 12, W - 24, grid.top - 24, 16)

    love.graphics.setFont(fonts.display)
    love.graphics.setColor(colors.text)
    local disp = calc.display
    local maxW = W - 40
    local tw = fonts.display:getWidth(disp)
    
    local drawText = disp
    if tw > maxW then
        while #drawText > 1 and fonts.display:getWidth("…"..drawText:sub(2)) > maxW do
            drawText = drawText:sub(2)
        end
        drawText = "…"..drawText
        tw = fonts.display:getWidth(drawText)
    end
    
    love.graphics.print(drawText, W - 20 - tw, grid.top - 50)

    love.graphics.setFont(fonts.button)
    for _, b in ipairs(buttons) do
        local r = 16
        local base = colors.btn
        if b.type == 'op' then base = colors.btn end
        if b.type == 'eq' then base = colors.accent end
        if b.type == 'ctrl' and b.txt == 'C' then base = {0.30, 0.10, 0.12} end

        if b.active then
            if b.type == 'eq' then base = colors.accentHover else base = colors.btnActive end
        elseif b.hover then
            if b.type == 'eq' then base = colors.accentHover else base = colors.btnHover end
        end

        love.graphics.setColor(base)
        roundRect('fill', b.x, b.y, b.w, b.h, r)

        love.graphics.setColor(0,0,0,0.12)
        roundRect('line', b.x, b.y, b.w, b.h, r)

        love.graphics.setColor(colors.text)
        local txtW = fonts.button:getWidth(b.txt)
        local txtH = fonts.button:getHeight()
        love.graphics.print(b.txt, b.x + (b.w - txtW)/2, b.y + (b.h - txtH)/2 - 2)
    end
end

-- TODO: Add history

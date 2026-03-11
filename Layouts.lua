-- Layouts Version 1.0 --
-- (c)2026 YukiPixels --
-- A Visual Script made for Aseprite --

---------------------------
-- Embedded JSON Library --
---------------------------

local JSON = (function()
    local obj = {}
    local function skip_ws(s,i) while i<=#s and s:sub(i,i):match('%s') do i=i+1 end return i end
    local function parse_literal(s,i,lit,res) if s:sub(i,i+#lit-1)==lit then return res,i+#lit end error("Expected "..lit) end
    local function parse_number(s,i) local st=i if s:sub(i,i)=='-' then i=i+1 end while i<=#s and s:sub(i,i):match('[%d%.eE+-]') do i=i+1 end return tonumber(s:sub(st,i-1)),i end
    local function parse_string(s,i) local r={} i=i+1 while i<=#s do local c=s:sub(i,i) if c=='"' then return table.concat(r),i+1 elseif c=='\\' then i=i+1 c=s:sub(i,i) if c=='n' then c='\n' elseif c=='t' then c='\t' elseif c=='r' then c='\r' end end table.insert(r,c) i=i+1 end error("Unclosed string") end
    local function parse_array(s,i) local a={} i=skip_ws(s,i+1) while true do i=skip_ws(s,i) if s:sub(i,i)==']' then return a,i+1 end local v v,i=obj.parse_value(s,i) table.insert(a,v) i=skip_ws(s,i) if s:sub(i,i)==',' then i=skip_ws(s,i+1) end end end
    local function parse_object(s,i) local t={} i=skip_ws(s,i+1) while true do i=skip_ws(s,i) if s:sub(i,i)=='}' then return t,i+1 end local k,v k,i=obj.parse_value(s,i) i=skip_ws(s,i) if s:sub(i,i)~=':' then error("Expected colon") end v,i=obj.parse_value(s,i+1) t[k]=v i=skip_ws(s,i) if s:sub(i,i)==',' then i=skip_ws(s,i+1) end end end
    function obj.parse_value(s,i) i=skip_ws(s,i or 1) local c=s:sub(i,i) if c=='{' then return parse_object(s,i) elseif c=='[' then return parse_array(s,i) elseif c=='"' then return parse_string(s,i) elseif c=='-' or c:match('%d') then return parse_number(s,i) elseif c=='t' then return parse_literal(s,i,'true',true) elseif c=='f' then return parse_literal(s,i,'false',false) elseif c=='n' then return parse_literal(s,i,'null',nil) else error("Unexpected '"..c.."'") end end
    local function enc(v) if type(v)=='table' then if v.r~=nil and v.g~=nil then return string.format('{"r":%d,"g":%d,"b":%d,"a":%d}',v.r,v.g,v.b,v.a or 255) end local t={} for k,val in pairs(v) do table.insert(t,enc(k)..":"..enc(val)) end return "{"..table.concat(t,",").."}" elseif type(v)=='string' then return '"'..v:gsub('[\\"]','\\%0')..'"' elseif type(v)=='number' then return tostring(v) elseif type(v)=='boolean' then return v and 'true' or 'false' else return 'null' end end
    return { decode=function(s) return obj.parse_value(s) end, encode=enc }
end)()

-----------------
-- Constants --
-----------------

local PHI = (1 + math.sqrt(5)) / 2

local BASE = {
    crosshair = "L - Crosshair",
    shape     = "L - Frame",
    thirds    = "L - Rule of Thirds",
    diagonals = "L - Diagonals",
    ellipse   = "L - Ellipse",
    grid      = "L - Grid",
    golden    = "L - Golden Ratio",
}
local SETTINGS_FILE = "Layouts_settings.json"

-----------------
-- Utilities --
-----------------

local function tableToColor(t,fb)
    if type(t)=="table" and t.r~=nil then return Color{r=t.r,g=t.g,b=t.b,alpha=t.a or 255} end
    return fb
end
local function colorToTable(c) return {r=c.red,g=c.green,b=c.blue,a=c.alpha} end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end

local function findLayer(sprite,name)
    for _,l in ipairs(sprite.layers) do if l.name==name then return l end end
end

local function resolveLayerName(sprite,base,newLayer)
    if not newLayer then
        if findLayer(sprite,base) then return base,false end
        for i=1,99 do local n=string.format("%s %02d",base,i) if findLayer(sprite,n) then return n,false end end
        return base,true
    else
        if not findLayer(sprite,base) then return base,true end
        for i=1,99 do local n=string.format("%s %02d",base,i) if not findLayer(sprite,n) then return n,true end end
        return base.." 99",true
    end
end

local function getLayer(sprite,base,newLayer,opacity,color)
    local name,mustCreate=resolveLayerName(sprite,base,newLayer)
    local layer
    if mustCreate then layer=sprite:newLayer(); layer.name=name
    else layer=findLayer(sprite,name) end
    layer.opacity=opacity or 255
    if color then layer.color=color end
    return layer
end

---------------------
-- Drawing Helpers --
---------------------

local function shouldDraw(x,y,style,dl)
    dl=dl or 4
    if style=="Solid" then return true
    elseif style=="Dashed" then return ((x+y)%(dl*2))<dl
    elseif style=="Checkerboard" then return (x+y)%2==0 end
    return true
end

local function px(img,W,H,x,y,color,style)
    x=math.floor(x+0.5); y=math.floor(y+0.5)
    if x<0 or y<0 or x>=W or y>=H then return end
    if shouldDraw(x,y,style) then img:drawPixel(x,y,color) end
end

local function hline(img,W,H,x0,x1,y,color,style)
    y=math.floor(y+0.5)
    if y<0 or y>=H then return end
    for x=math.max(0,math.floor(x0)),math.min(W-1,math.floor(x1)) do
        if shouldDraw(x,y,style) then img:drawPixel(x,y,color) end
    end
end

local function vline(img,W,H,x,y0,y1,color,style)
    x=math.floor(x+0.5)
    if x<0 or x>=W then return end
    for y=math.max(0,math.floor(y0)),math.min(H-1,math.floor(y1)) do
        if shouldDraw(x,y,style) then img:drawPixel(x,y,color) end
    end
end

local function drawRect(img,W,H,x0,y0,x1,y1,thick,color,style)
    for t=0,thick-1 do
        local ax=clamp(x0+t,0,W-1); local ay=clamp(y0+t,0,H-1)
        local bx=clamp(x1-t,0,W-1); local by=clamp(y1-t,0,H-1)
        if ax>bx or ay>by then break end
        hline(img,W,H,ax,bx,ay,color,style)
        hline(img,W,H,ax,bx,by,color,style)
        vline(img,W,H,ax,ay,by,color,style)
        vline(img,W,H,bx,ay,by,color,style)
    end
end

-- Bresenham ellipse outline
local function drawEllipseShape(img,W,H,cx,cy,rx,ry,color,style,thick)
    thick = thick or 1
    -- Draw by marching along angle - gap-free by filling between adjacent pixels
    for dt=0,thick-1 do
        local arx=math.max(1,rx-dt)
        local ary=math.max(1,ry-dt)
        local steps=math.max(64, math.floor(2*math.pi*math.max(arx,ary))*2)
        local prevX,prevY=nil,nil
        for i=0,steps do
            local a=2*math.pi*i/steps
            local x=math.floor(cx+arx*math.cos(a)+0.5)
            local y=math.floor(cy+ary*math.sin(a)+0.5)
            px(img,W,H,x,y,color,style)
            if prevX then
                -- Fill any gap between prev and current
                local ddx=x-prevX; local ddy=y-prevY
                local sub=math.max(math.abs(ddx),math.abs(ddy))
                for s=1,sub-1 do
                    px(img,W,H,
                       prevX+math.floor(ddx*s/sub+0.5),
                       prevY+math.floor(ddy*s/sub+0.5),
                       color,style)
                end
            end
            prevX=x; prevY=y
        end
    end
end

---------------------
-- Feature Drawing --
---------------------

local function drawCrosshair(img,sprite,data)
    local W,H=sprite.width,sprite.height
    local thick=math.max(1,data.thickness)
    local vS=clamp(math.floor((W-thick)/2),0,W-1)
    local hS=clamp(math.floor((H-thick)/2),0,H-1)
    local st=data.style or "Solid"
    for x=vS,math.min(vS+thick-1,W-1) do
        for y=0,H-1 do if shouldDraw(x,y,st) then img:drawPixel(x,y,data.color) end end
    end
    for y=hS,math.min(hS+thick-1,H-1) do
        for x=0,W-1 do if shouldDraw(x,y,st) then img:drawPixel(x,y,data.color) end end
    end
end

local function drawShape(img,sprite,data)
    local W,H=sprite.width,sprite.height
    local sw=math.floor(W*data.shapeSize/100)
    local sh=math.floor(H*data.shapeSize/100)
    local x0=math.floor((W-sw)/2); local y0=math.floor((H-sh)/2)
    drawRect(img,W,H,x0,y0,x0+sw-1,y0+sh-1,math.max(1,data.shapeThickness),data.shapeColor,data.shapeStyle or "Solid")
end

local function drawThirds(img,sprite,data)
    local W,H=sprite.width,sprite.height
    local thick=math.max(1,data.thirdsThickness)
    local st=data.thirdsStyle or "Solid"; local color=data.thirdsColor
    for _,bx in ipairs({math.floor(W/3),math.floor(W*2/3)}) do
        for t=0,thick-1 do vline(img,W,H,clamp(bx+t,0,W-1),0,H-1,color,st) end
    end
    for _,by in ipairs({math.floor(H/3),math.floor(H*2/3)}) do
        for t=0,thick-1 do hline(img,W,H,0,W-1,clamp(by+t,0,H-1),color,st) end
    end
end

local function drawDiagonals(img,sprite,data)
    local W,H=sprite.width,sprite.height
    local thick=math.max(1,data.diagThickness)
    local st=data.diagStyle or "Solid"; local color=data.diagColor
    for x=0,W-1 do
        local y1=math.floor(x*(H-1)/(W-1))
        local y2=math.floor((W-1-x)*(H-1)/(W-1))
        for t=-math.floor(thick/2),math.ceil(thick/2)-1 do
            px(img,W,H,x,clamp(y1+t,0,H-1),color,st)
            px(img,W,H,x,clamp(y2+t,0,H-1),color,st)
        end
    end
end

local function drawEllipse(img,sprite,data)
    local W,H=sprite.width,sprite.height
    local thick=math.max(1,data.ellipseThickness)
    local st=data.ellipseStyle or "Solid"; local color=data.ellipseColor
    local cx=math.floor(W/2); local cy=math.floor(H/2)
    local baseRx=math.max(1,clamp(math.floor(W*data.ellipseSize/100/2),1,math.floor(W/2)-thick))
    local baseRy=math.max(1,clamp(math.floor(H*data.ellipseSize/100/2),1,math.floor(H/2)-thick))
    for dt=0,thick-1 do
        drawEllipseShape(img,W,H,cx,cy,baseRx+dt,baseRy+dt,color,st)
    end
end

local function drawGrid(img,sprite,data)
    local W,H=sprite.width,sprite.height
    local cellW=math.max(1,data.gridCellW)
    local thick=math.max(1,data.gridThick or 1)
    local color=data.gridColor; local st=data.gridStyle or "Solid"
    local x=cellW
    while x<W do
        for t=0,thick-1 do vline(img,W,H,clamp(x+t,0,W-1),0,H-1,color,st) end
        x=x+cellW
    end
    local y=cellW
    while y<H do
        for t=0,thick-1 do hline(img,W,H,0,W-1,clamp(y+t,0,H-1),color,st) end
        y=y+cellW
    end
end


-- Flip an image vertically (in-place)
local function flipVertical(img, W, H)
    for y=0, math.floor(H/2)-1 do
        for x=0, W-1 do
            local top = img:getPixel(x, y)
            local bot = img:getPixel(x, H-1-y)
            img:putPixel(x, y,       bot)
            img:putPixel(x, H-1-y,   top)
        end
    end
end

local function drawGolden(rectImg, spiralImg, circleImg, sprite, data)
    local W,H         = sprite.width, sprite.height
    local rectThick   = math.max(1, data.goldenRectThick)
    local spiralThick = math.max(1, data.FibonacciSpiralThick)
    local circleThick = math.max(1, data.goldenCircleThick)
    local st          = "Solid"
    local rColor      = data.goldenRectColor
    local sColor      = data.FibonacciSpiralColor
    local cColor      = data.goldenCircleColor
    local levels      = math.max(3, math.min(8, data.goldenLevels))

    -- Fit largest phi:1 rectangle centered on canvas
    local rx0,ry0,rx1,ry1
    if W/H >= PHI then
        local rw = math.floor(H * PHI)
        rx0 = math.floor((W-rw)/2); ry0 = 0
        rx1 = rx0+rw-1;             ry1 = H-1
    else
        local rh = math.floor(W/PHI)
        rx0 = 0;   ry0 = math.floor((H-rh)/2)
        rx1 = W-1; ry1 = ry0+rh-1
    end

    -- Outer border
    drawRect(rectImg,W,H, rx0,ry0,rx1,ry1, rectThick,rColor,st)

    -- Arc with thickness, guaranteed no gaps
    local function arc(cx,cy,r,a0,a1)
        for dt=0,spiralThick-1 do
            local rr = math.max(1, r-dt)
            -- steps = 2x circumference to ensure no pixel is skipped
            local steps = math.max(16, math.floor(math.abs(a1-a0) * rr * 2))
            local prevX,prevY = nil,nil
            for i=0,steps do
                local a = a0+(a1-a0)*i/steps
                local x = math.floor(cx + rr*math.cos(a) + 0.5)
                local y = math.floor(cy + rr*math.sin(a) + 0.5)
                px(spiralImg,W,H,x,y,sColor,st)
                if prevX then
                    local ddx = x-prevX; local ddy = y-prevY
                    local sub = math.max(math.abs(ddx),math.abs(ddy))
                    for s=1,sub-1 do
                        px(spiralImg,W,H,
                           prevX+math.floor(ddx*s/sub+0.5),
                           prevY+math.floor(ddy*s/sub+0.5), sColor,st)
                    end
                end
                prevX=x; prevY=y
            end
        end
    end

    -- Inscribed circle: reuse the gap-free drawEllipseShape function
    local function inscribedCircle(sqx0,sqy0,sq)
local cx = math.floor(sqx0 + sq/2)
        local cy = math.floor(sqy0 + sq/2)
        local r  = math.floor(sq/2)
        if r < 2 then return end
        drawEllipseShape(circleImg,W,H,cx,cy,r,r,cColor,st,circleThick)
    end

    -- Recursive subdivision.
    -- Cycle: LEFT(0) → BOTTOM(1) → RIGHT(2) → TOP(3) → LEFT(0) ...
    -- Arcs are CONNECTED: end of arc N = start of arc N+1
    -- Verified by pixel analysis of reference image.
    --
    -- cut=0 LEFT   (landscape, sq=h): divX=x0+sq  pivot=(divX,y0) arc π→π/2   recurse→cut=1
    -- cut=1 BOTTOM (portrait,  sq=w): divY=y1-sq  pivot=(x0,divY) arc π/2→0   recurse→cut=2
    -- cut=2 RIGHT  (landscape, sq=h): divX=x1-sq  pivot=(divX,y1) arc 0→-π/2  recurse→cut=3
    -- cut=3 TOP    (portrait,  sq=w): divY=y0+sq  pivot=(x1,divY) arc -π/2→-π recurse→cut=0
    local function subdivide(x0,y0,x1,y1,cut,depth)
        if depth<=0 then return end
        local w=x1-x0; local h=y1-y0
        if w<8 or h<8 then return end

        if cut==0 then
            local sq=h; local divX=x0+sq
            if divX>=x1 then return end
            for t=0,rectThick-1 do vline(rectImg,W,H,clamp(divX+t,0,W-1),y0,y1,rColor,st) end
            inscribedCircle(x0,y0,sq)
            arc(divX,y0, sq, math.pi, math.pi/2)
            subdivide(divX,y0, x1,y1, 1,depth-1)

        elseif cut==1 then
            local sq=w; local divY=y1-sq
            if divY<=y0 then return end
            for t=0,rectThick-1 do hline(rectImg,W,H,x0,x1,clamp(divY-t,0,H-1),rColor,st) end
            inscribedCircle(x0,divY,sq)
            arc(x0,divY, sq, math.pi/2, 0)
            subdivide(x0,y0, x1,divY, 2,depth-1)

        elseif cut==2 then
            local sq=h; local divX=x1-sq
            if divX<=x0 then return end
            for t=0,rectThick-1 do vline(rectImg,W,H,clamp(divX-t,0,W-1),y0,y1,rColor,st) end
            inscribedCircle(divX,y0,sq)
            arc(divX,y1, sq, 0, -math.pi/2)
            subdivide(x0,y0, divX,y1, 3,depth-1)

        elseif cut==3 then
            local sq=w; local divY=y0+sq
            if divY>=y1 then return end
            for t=0,rectThick-1 do hline(rectImg,W,H,x0,x1,clamp(divY+t,0,H-1),rColor,st) end
            inscribedCircle(x0,y0,sq)
            arc(x1,divY, sq, -math.pi/2, -math.pi)
            subdivide(x0,divY, x1,y1, 0,depth-1)
        end
    end

    if (rx1-rx0) >= (ry1-ry0) then
        subdivide(rx0,ry0,rx1,ry1, 0,levels)
    else
        subdivide(rx0,ry0,rx1,ry1, 3,levels)
    end
end


function togglefunctions()
    local sprite=app.activeSprite
    if not sprite then app.alert("No active sprite.") return end
    local layers,allVis={},true
    for _,l in ipairs(sprite.layers) do
        if l.name:sub(1,3)=="L -" then
            table.insert(layers,l)
            if not l.isVisible then allVis=false end
        end
    end
    if #layers==0 then app.alert("No Layouts layers found.") return end
    app.transaction("Toggle Layouts Functions",function()
        for _,l in ipairs(layers) do l.isVisible=not allVis end
    end)
    app.refresh()
end

-----------------
-- Core Logic --
-----------------

function createFunctionsLogic(data,sprite)
    app.transaction("Layouts - Create Functions",function()
        if data.enableCrosshair then
            local l=getLayer(sprite,BASE.crosshair,true,data.opacity,data.color)
            local cel=sprite:newCel(l,app.activeFrame)
            local img=Image(sprite.width,sprite.height); drawCrosshair(img,sprite,data); cel.image=img
        end
        if data.enableShape then
            local l=getLayer(sprite,BASE.shape,true,data.shapeOpacity,data.shapeColor)
            local cel=sprite:newCel(l,app.activeFrame)
            local img=Image(sprite.width,sprite.height); drawShape(img,sprite,data); cel.image=img
        end
        if data.enableEllipse then
            local l=getLayer(sprite,BASE.ellipse,true,data.ellipseOpacity,data.ellipseColor)
            local cel=sprite:newCel(l,app.activeFrame)
            local img=Image(sprite.width,sprite.height); drawEllipse(img,sprite,data); cel.image=img
        end
        if data.enableDiag then
            local l=getLayer(sprite,BASE.diagonals,true,data.diagOpacity,data.diagColor)
            local cel=sprite:newCel(l,app.activeFrame)
            local img=Image(sprite.width,sprite.height); drawDiagonals(img,sprite,data); cel.image=img
        end
        if data.enableGrid then
            local l=getLayer(sprite,BASE.grid,true,data.gridOpacity,data.gridColor)
            local cel=sprite:newCel(l,app.activeFrame)
            local img=Image(sprite.width,sprite.height); drawGrid(img,sprite,data); cel.image=img
        end
        if data.enableThirds then
            local l=getLayer(sprite,BASE.thirds,true,data.thirdsOpacity,data.thirdsColor)
            local cel=sprite:newCel(l,app.activeFrame)
            local img=Image(sprite.width,sprite.height); drawThirds(img,sprite,data); cel.image=img
        end
        if data.enableGolden then
            -- Rectangle layer
            local lRect=getLayer(sprite,"L - Golden Rectangle",true,data.goldenOpacity,data.goldenRectColor)
            local celRect=sprite:newCel(lRect,app.activeFrame)
            local imgRect=Image(sprite.width,sprite.height)
            -- Circle layer
            local imgCircle=Image(sprite.width,sprite.height)
            local lCircle=getLayer(sprite,"L - Golden Circles",true,data.goldenOpacity,data.goldenCircleColor)
            local celCircle=sprite:newCel(lCircle,app.activeFrame)
            -- Spiral layer
            local imgSpiral=Image(sprite.width,sprite.height)
            local lSpiral=getLayer(sprite,"L - Fibonacci Spiral",true,data.goldenOpacity,data.FibonacciSpiralColor)
            local celSpiral=sprite:newCel(lSpiral,app.activeFrame)
            drawGolden(imgRect,imgSpiral,imgCircle,sprite,data)
            local W,H=sprite.width,sprite.height
            flipVertical(imgRect,   W, H)
            flipVertical(imgSpiral, W, H)
            flipVertical(imgCircle, W, H)
            celRect.image=imgRect
            celSpiral.image=imgSpiral
            celCircle.image=imgCircle
        end
    end)

    local f=io.open(SETTINGS_FILE,"w")
    if f then
        f:write(JSON.encode({
            enableCrosshair=data.enableCrosshair,        color=colorToTable(data.color),
            opacity=data.opacity,                         style=data.style,
            thickness=data.thickness,
            enableShape=data.enableShape,                shapeSize=data.shapeSize,
            shapeColor=colorToTable(data.shapeColor),    shapeOpacity=data.shapeOpacity,
            shapeThickness=data.shapeThickness,          shapeStyle=data.shapeStyle,
            enableThirds=data.enableThirds,              thirdsColor=colorToTable(data.thirdsColor),
            thirdsOpacity=data.thirdsOpacity,            thirdsThickness=data.thirdsThickness,
            thirdsStyle=data.thirdsStyle,
            enableGolden=data.enableGolden,              goldenLevels=data.goldenLevels,
            goldenRectColor=colorToTable(data.goldenRectColor),
            goldenRectThick=data.goldenRectThick,
            FibonacciSpiralColor=colorToTable(data.FibonacciSpiralColor),
            FibonacciSpiralThick=data.FibonacciSpiralThick,
            goldenCircleColor=colorToTable(data.goldenCircleColor),
            goldenCircleThick=data.goldenCircleThick,
            goldenOpacity=data.goldenOpacity,
            enableDiag=data.enableDiag,                  diagColor=colorToTable(data.diagColor),
            diagOpacity=data.diagOpacity,                diagThickness=data.diagThickness,
            diagStyle=data.diagStyle,
            enableEllipse=data.enableEllipse,            ellipseSize=data.ellipseSize,
            ellipseColor=colorToTable(data.ellipseColor),ellipseOpacity=data.ellipseOpacity,
            ellipseThickness=data.ellipseThickness,      ellipseStyle=data.ellipseStyle,
            enableGrid=data.enableGrid,  gridCellW=data.gridCellW,  gridThick=data.gridThick,
            gridColor=colorToTable(data.gridColor),
            gridOpacity=data.gridOpacity,                gridStyle=data.gridStyle,
        }))
        f:close()
    end
    app.refresh()
end

-----------------
-- UI --
-----------------

function createFunctions()
    local sprite=app.activeSprite
    if not sprite then app.alert("No active sprite.") return end

    local DEF={
        enableCrosshair=true,  color=Color{r=0,g=255,b=255,alpha=255},
        opacity=255, style="Solid", thickness=2,
        enableShape=false,     shapeSize=80, shapeColor=Color{r=220,g=0,b=255,alpha=255},
        shapeOpacity=255, shapeThickness=2, shapeStyle="Solid",
        enableThirds=false,    thirdsColor=Color{r=255,g=210,b=0,alpha=255},
        thirdsOpacity=255, thirdsThickness=2, thirdsStyle="Solid",
        enableGolden=false,    goldenLevels=6,
        goldenRectColor=Color{r=0,g=0,b=0,alpha=255},          goldenRectThick=2,
        FibonacciSpiralColor=Color{r=255,g=60,b=100,alpha=255},  FibonacciSpiralThick=2,
        goldenCircleColor=Color{r=0,g=180,b=255,alpha=255},   goldenCircleThick=2,
        goldenOpacity=255,
        enableDiag=false,      diagColor=Color{r=255,g=80,b=30,alpha=255},
        diagOpacity=255, diagThickness=2, diagStyle="Solid",
        enableEllipse=false,   ellipseSize=80, ellipseColor=Color{r=50,g=100,b=250,alpha=255},
        ellipseOpacity=255, ellipseThickness=2, ellipseStyle="Solid",
        enableGrid=false,      gridCellW=16,             gridThick=2, gridColor=Color{r=255,g=255,b=255,alpha=255},
        gridOpacity=255, gridStyle="Solid",
    }

    local s={}
    local f=io.open(SETTINGS_FILE,"r")
    if f then local c=f:read("*a") f:close() local ok,r=pcall(JSON.decode,c) if ok and type(r)=="table" then s=r end end

    local function gs(k)
        local v = s[k]
        if v == nil then return DEF[k] end
        if v == "true"  then return true  end
        if v == "false" then return false end
        return v
    end
    local function gc(k,fb) return tableToColor(s[k],fb) end

    local cfg={
        enableCrosshair=gs("enableCrosshair"),   color=gc("color",DEF.color),
        opacity=gs("opacity"),                    style=gs("style"),
        thickness=gs("thickness"),
        enableShape=gs("enableShape"),            shapeSize=gs("shapeSize"),
        shapeColor=gc("shapeColor",DEF.shapeColor), shapeOpacity=gs("shapeOpacity"),
        shapeThickness=gs("shapeThickness"),      shapeStyle=gs("shapeStyle"),
        enableThirds=gs("enableThirds"),          thirdsColor=gc("thirdsColor",DEF.thirdsColor),
        thirdsOpacity=gs("thirdsOpacity"),        thirdsThickness=gs("thirdsThickness"),
        thirdsStyle=gs("thirdsStyle"),
        enableGolden=gs("enableGolden"),          goldenLevels=gs("goldenLevels"),
        goldenRectColor=gc("goldenRectColor",DEF.goldenRectColor),
        goldenRectThick=gs("goldenRectThick"),
        FibonacciSpiralColor=gc("FibonacciSpiralColor",DEF.FibonacciSpiralColor),
        FibonacciSpiralThick=gs("FibonacciSpiralThick"),
        goldenCircleColor=gc("goldenCircleColor",DEF.goldenCircleColor),
        goldenCircleThick=gs("goldenCircleThick"),
        goldenOpacity=gs("goldenOpacity"),
        enableDiag=gs("enableDiag"),              diagColor=gc("diagColor",DEF.diagColor),
        diagOpacity=gs("diagOpacity"),            diagThickness=gs("diagThickness"),
        diagStyle=gs("diagStyle"),
        enableEllipse=gs("enableEllipse"),        ellipseSize=gs("ellipseSize"),
        ellipseColor=gc("ellipseColor",DEF.ellipseColor), ellipseOpacity=gs("ellipseOpacity"),
        ellipseThickness=gs("ellipseThickness"),  ellipseStyle=gs("ellipseStyle"),
        enableGrid=gs("enableGrid"),              gridCellW=gs("gridCellW"),
        gridThick=gs("gridThick"),
        gridColor=gc("gridColor",DEF.gridColor),
        gridOpacity=gs("gridOpacity"),            gridStyle=gs("gridStyle"),
    }

    local ST={"Solid","Dashed","Checkerboard"}
    local dlg=Dialog{title="Layouts v1.0 - YukiPixels"}

    dlg:separator{text="✛  Crosshair"}
    dlg:check   {id="enableCrosshair",   label="Enable", selected=cfg.enableCrosshair}
    dlg:color   {id="color",             label="Color",     color=cfg.color}
    dlg:slider  {id="opacity",           label="Opacity",   min=0,max=255, value=cfg.opacity}
    dlg:slider  {id="thickness",         label="Thickness", min=1,max=12,  value=cfg.thickness}
    dlg:combobox{id="style",             label="Style",     options=ST,    option=cfg.style}

    dlg:separator{text="▭  Frame"}
    dlg:check   {id="enableShape",    label="Enable", selected=cfg.enableShape}
    dlg:slider  {id="shapeSize",      label="Size (%)",  min=1,max=100, value=cfg.shapeSize}
    dlg:color   {id="shapeColor",     label="Color",     color=cfg.shapeColor}
    dlg:slider  {id="shapeOpacity",   label="Opacity",   min=0,max=255, value=cfg.shapeOpacity}
    dlg:slider  {id="shapeThickness", label="Thickness", min=1,max=12,  value=cfg.shapeThickness}
    dlg:combobox{id="shapeStyle",     label="Style",     options=ST,    option=cfg.shapeStyle}

    dlg:separator{text="O  Ellipse"}
    dlg:check   {id="enableEllipse",    label="Enable", selected=cfg.enableEllipse}
    dlg:slider  {id="ellipseSize",      label="Size (%)",  min=1,max=100, value=cfg.ellipseSize}
    dlg:color   {id="ellipseColor",     label="Color",     color=cfg.ellipseColor}
    dlg:slider  {id="ellipseOpacity",   label="Opacity",   min=0,max=255, value=cfg.ellipseOpacity}
    dlg:slider  {id="ellipseThickness", label="Thickness", min=1,max=12,  value=cfg.ellipseThickness}
    dlg:combobox{id="ellipseStyle",     label="Style",     options=ST,    option=cfg.ellipseStyle}

    dlg:separator{text="X  Diagonals"}
    dlg:check   {id="enableDiag",    label="Enable", selected=cfg.enableDiag}
    dlg:color   {id="diagColor",     label="Color",     color=cfg.diagColor}
    dlg:slider  {id="diagOpacity",   label="Opacity",   min=0,max=255, value=cfg.diagOpacity}
    dlg:slider  {id="diagThickness", label="Thickness", min=1,max=12,  value=cfg.diagThickness}
    dlg:combobox{id="diagStyle",     label="Style",     options=ST,    option=cfg.diagStyle}

    dlg:separator{text="#  Grid"}
    dlg:check   {id="enableGrid",    label="Enable",      selected=cfg.enableGrid}
    dlg:slider  {id="gridCellW",   label="Cell size",  min=1,max=64, value=cfg.gridCellW}
    dlg:slider  {id="gridThick",   label="Thickness",  min=1,max=12, value=cfg.gridThick}
    dlg:color   {id="gridColor",   label="Color",       color=cfg.gridColor}
    dlg:slider  {id="gridOpacity", label="Opacity",     min=0,max=255, value=cfg.gridOpacity}
    dlg:combobox{id="gridStyle",   label="Style",       options=ST,    option=cfg.gridStyle}

    dlg:separator{text="⅓  Rule of Thirds"}
    dlg:check   {id="enableThirds",    label="Enable", selected=cfg.enableThirds}
    dlg:color   {id="thirdsColor",     label="Color",     color=cfg.thirdsColor}
    dlg:slider  {id="thirdsOpacity",   label="Opacity",   min=0,max=255, value=cfg.thirdsOpacity}
    dlg:slider  {id="thirdsThickness", label="Thickness", min=1,max=12,  value=cfg.thirdsThickness}
    dlg:combobox{id="thirdsStyle",     label="Style",     options=ST,    option=cfg.thirdsStyle}

    dlg:separator{text="φ  Golden Ratio"}
    dlg:check   {id="enableGolden",      label="Enable",             selected=cfg.enableGolden}
    dlg:slider  {id="goldenLevels",      label="Count",              min=3,max=8,  value=cfg.goldenLevels}
    dlg:slider  {id="goldenOpacity",     label="Opacity",            min=0,max=255,value=cfg.goldenOpacity}
    dlg:separator{text="  Golden Rectangle"}
    dlg:color   {id="goldenRectColor",   label="Color",              color=cfg.goldenRectColor}
    dlg:slider  {id="goldenRectThick",   label="Thickness",          min=1,max=12, value=cfg.goldenRectThick}
    dlg:separator{text="  Golden Circles"}
    dlg:color   {id="goldenCircleColor", label="Color",              color=cfg.goldenCircleColor}
    dlg:slider  {id="goldenCircleThick", label="Thickness",          min=1,max=12, value=cfg.goldenCircleThick}

    dlg:separator{text="  Fibonacci Spiral"}
    dlg:color   {id="FibonacciSpiralColor", label="Color",              color=cfg.FibonacciSpiralColor}
    dlg:slider  {id="FibonacciSpiralThick", label="Thickness",          min=1,max=12, value=cfg.FibonacciSpiralThick}
    dlg:separator{}
    dlg:newrow()
    dlg:button{id="reset",text="  Reset Defaults  ",onclick=function()
        dlg:modify{id="enableCrosshair",   selected=DEF.enableCrosshair}
        dlg:modify{id="color",             color=DEF.color}
        dlg:modify{id="opacity",           value=DEF.opacity}
        dlg:modify{id="thickness",         value=DEF.thickness}
        dlg:modify{id="style",             option=DEF.style}
        dlg:modify{id="enableShape",       selected=DEF.enableShape}
        dlg:modify{id="shapeSize",         value=DEF.shapeSize}
        dlg:modify{id="shapeColor",        color=DEF.shapeColor}
        dlg:modify{id="shapeOpacity",      value=DEF.shapeOpacity}
        dlg:modify{id="shapeThickness",    value=DEF.shapeThickness}
        dlg:modify{id="shapeStyle",        option=DEF.shapeStyle}
        dlg:modify{id="enableThirds",      selected=DEF.enableThirds}
        dlg:modify{id="thirdsColor",       color=DEF.thirdsColor}
        dlg:modify{id="thirdsOpacity",     value=DEF.thirdsOpacity}
        dlg:modify{id="thirdsThickness",   value=DEF.thirdsThickness}
        dlg:modify{id="thirdsStyle",       option=DEF.thirdsStyle}
        dlg:modify{id="enableGolden",      selected=DEF.enableGolden}
        dlg:modify{id="goldenLevels",      value=DEF.goldenLevels}
        dlg:modify{id="goldenRectColor",   color=DEF.goldenRectColor}
        dlg:modify{id="goldenRectThick",   value=DEF.goldenRectThick}
        dlg:modify{id="FibonacciSpiralColor", color=DEF.FibonacciSpiralColor}
        dlg:modify{id="FibonacciSpiralThick", value=DEF.FibonacciSpiralThick}
        dlg:modify{id="goldenCircleColor", color=DEF.goldenCircleColor}
        dlg:modify{id="goldenCircleThick", value=DEF.goldenCircleThick}
        dlg:modify{id="goldenOpacity",     value=DEF.goldenOpacity}
        dlg:modify{id="enableEllipse",     selected=DEF.enableEllipse}
        dlg:modify{id="ellipseSize",       value=DEF.ellipseSize}
        dlg:modify{id="ellipseColor",      color=DEF.ellipseColor}
        dlg:modify{id="ellipseOpacity",    value=DEF.ellipseOpacity}
        dlg:modify{id="ellipseThickness",  value=DEF.ellipseThickness}
        dlg:modify{id="ellipseStyle",      option=DEF.ellipseStyle}
        dlg:modify{id="enableDiag",        selected=DEF.enableDiag}
        dlg:modify{id="diagColor",         color=DEF.diagColor}
        dlg:modify{id="diagOpacity",       value=DEF.diagOpacity}
        dlg:modify{id="diagThickness",     value=DEF.diagThickness}
        dlg:modify{id="diagStyle",         option=DEF.diagStyle}
        dlg:modify{id="enableGrid",        selected=DEF.enableGrid}
        dlg:modify{id="gridCellW",         value=DEF.gridCellW}
        dlg:modify{id="gridThick",          value=DEF.gridThick}
        dlg:modify{id="gridColor",         color=DEF.gridColor}
        dlg:modify{id="gridOpacity",       value=DEF.gridOpacity}
        dlg:modify{id="gridStyle",         option=DEF.gridStyle}
    end}
        dlg:button{id="toggle",text="  Toggle Functions  ",onclick=function()
        dlg:close(); togglefunctions()
    end}
    dlg:newrow()
    dlg:button{id="cancel",text="  Cancel  ",onclick=function() dlg:close() end}
    dlg:button{id="ok",text="  Create  ",onclick=function()
        local d=dlg.data; dlg:close()
        createFunctionsLogic({
            enableCrosshair=d.enableCrosshair,        color=d.color,
            opacity=d.opacity,                         style=d.style,
            thickness=d.thickness,
            enableShape=d.enableShape,                shapeSize=d.shapeSize,
            shapeColor=d.shapeColor,                  shapeOpacity=d.shapeOpacity,
            shapeThickness=d.shapeThickness,          shapeStyle=d.shapeStyle,
            enableThirds=d.enableThirds,              thirdsColor=d.thirdsColor,
            thirdsOpacity=d.thirdsOpacity,            thirdsThickness=d.thirdsThickness,
            thirdsStyle=d.thirdsStyle,
            enableGolden=d.enableGolden,              goldenLevels=d.goldenLevels,
            goldenRectColor=d.goldenRectColor,        goldenRectThick=d.goldenRectThick,
            FibonacciSpiralColor=d.FibonacciSpiralColor,    FibonacciSpiralThick=d.FibonacciSpiralThick,
            goldenCircleColor=d.goldenCircleColor,    goldenCircleThick=d.goldenCircleThick,
            goldenOpacity=d.goldenOpacity,
            enableDiag=d.enableDiag,                 diagColor=d.diagColor,
            diagOpacity=d.diagOpacity,                diagThickness=d.diagThickness,
            diagStyle=d.diagStyle,
            enableEllipse=d.enableEllipse,            ellipseSize=d.ellipseSize,
            ellipseColor=d.ellipseColor,              ellipseOpacity=d.ellipseOpacity,
            ellipseThickness=d.ellipseThickness,      ellipseStyle=d.ellipseStyle,
            enableGrid=d.enableGrid,
            gridCellW=d.gridCellW,
            gridThick=d.gridThick,
            gridColor=d.gridColor,                    gridOpacity=d.gridOpacity,
            gridStyle=d.gridStyle,
        },sprite)
    end}

    dlg:show{wait=true, autoscrollbars=true}
end

createFunctions()
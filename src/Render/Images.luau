-- Render/Images: turns ImageLabel.Image values into data for Drawing Image.Data.
--   "rbxassetid://123" / roblox.com asset links -> downloaded from assetdelivery.roblox.com
--   "https://..."                              -> downloaded
--   anything else                              -> passed to Image.Data as-is (raw image bytes / file data)
-- Downloads run in the background and are cached per source; the image appears once it has loaded.
-- UI.Images.Mode = "url" passes the URL to Image.Data instead of downloading (for executors that accept URLs).
-- UI.Images.Loader(url) -> bytes can be replaced (default: game:HttpGet).
return function(UI, ctx)
    local Images = { Mode = "bytes" }
    UI.Images = Images
    local cache = {}

    function Images.Loader(url)
        return game:HttpGet(url)
    end

    local function assetUrl(id) return "https://assetdelivery.roblox.com/v1/asset/?id=" .. id end
    local function toUrl(source)
        local id = source:match("^rbxassetid://(%d+)$")
        if not id and source:find("^https?://[%w%.]*roblox%.com/") then id = source:match("[?&]id=(%d+)") end
        if id then return assetUrl(id) end
        if source:find("^https?://") then return source end
        return nil
    end
    local function isImage(bytes)
        local head = bytes:sub(1, 4)
        return head == "\137PNG" or head:sub(1, 2) == "\255\216" or head == "GIF8" or head == "RIFF" or head:sub(1, 2) == "BM"
    end
    local function fetch(url, depth)
        local ok, body = pcall(Images.Loader, url)
        if not ok then return nil, tostring(body) end
        if type(body) ~= "string" or body == "" then return nil, "empty response" end
        if isImage(body) then return body end
        -- A Decal id returns XML that points at the real image asset.
        local inner = body:match("<url>[^<]-[?&]id=(%d+)</url>")
        if inner and depth < 2 then return fetch(assetUrl(inner), depth + 1) end
        return nil, "response is not an image (" .. #body .. " bytes)"
    end

    -- Embedded images ---------------------------------------------------------------------------
    -- The Studio exporter embeds image pixels in the script (Roblox image assets can't be downloaded
    -- anonymously). Format: base64 of RGBA pixels compressed with PackBits on whole pixels
    -- (control byte 0..127 = that many + 1 literal pixels follow, 128..255 = next pixel repeated n - 126 times).
    -- At runtime they are turned into an uncompressed PNG for Drawing Image.Data.
    local registry = {}

    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local decodeMap = {}
    for i = 1, 64 do decodeMap[string.byte(B64, i)] = i - 1 end
    local function base64Decode(text)
        text = text:gsub("[^%w%+/]", "")
        local out = buffer.create(math.floor(#text * 3 / 4))
        local n, acc, bits = 0, 0, 0
        for i = 1, #text do
            acc = bit32.bor(bit32.lshift(acc, 6), decodeMap[string.byte(text, i)])
            bits += 6
            if bits >= 8 then
                bits -= 8
                buffer.writeu8(out, n, bit32.band(bit32.rshift(acc, bits), 255))
                n += 1
                acc = bit32.band(acc, bit32.lshift(1, bits) - 1)
            end
        end
        return out, n
    end

    local crcTable = {}
    for i = 0, 255 do
        local c = i
        for _ = 1, 8 do
            if bit32.band(c, 1) == 1 then c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1)) else c = bit32.rshift(c, 1) end
        end
        crcTable[i] = c
    end
    local function crc32(buf, from, to)
        local c = 0xFFFFFFFF
        for i = from, to - 1 do
            c = bit32.bxor(crcTable[bit32.band(bit32.bxor(c, buffer.readu8(buf, i)), 255)], bit32.rshift(c, 8))
        end
        return bit32.bxor(c, 0xFFFFFFFF)
    end

    -- RGBA pixels -> PNG bytes (filter 0, zlib "stored" blocks: no compression needed in memory).
    local function encodePng(width, height, pixels)
        local rowBytes = width * 4 + 1
        local rawSize = rowBytes * height
        local blocks = math.max(1, math.ceil(rawSize / 65535))
        local idatSize = 2 + rawSize + blocks * 5 + 4
        local png = buffer.create(8 + 25 + 12 + idatSize + 12)
        local o = 0
        local function u8(v) buffer.writeu8(png, o, v); o += 1 end
        local function u32(v) buffer.writeu8(png, o, bit32.rshift(v, 24)); buffer.writeu8(png, o + 1, bit32.band(bit32.rshift(v, 16), 255))
            buffer.writeu8(png, o + 2, bit32.band(bit32.rshift(v, 8), 255)); buffer.writeu8(png, o + 3, bit32.band(v, 255)); o += 4 end
        local function chunk(kind, length, write)
            u32(length)
            local start = o
            buffer.writestring(png, o, kind); o += 4
            write()
            u32(crc32(png, start, o))
        end
        buffer.writestring(png, 0, "\137PNG\r\n\26\n"); o = 8
        chunk("IHDR", 13, function() u32(width); u32(height); u8(8); u8(6); u8(0); u8(0); u8(0) end)
        chunk("IDAT", idatSize, function()
            u8(0x78); u8(0x01)
            local a, b = 1, 0
            local written, row, col = 0, 0, -1 -- col -1 = the row's filter byte
            for block = 1, blocks do
                local len = math.min(65535, rawSize - written)
                u8(block == blocks and 1 or 0)
                u8(bit32.band(len, 255)); u8(bit32.rshift(len, 8))
                u8(bit32.band(bit32.bnot(len), 255)); u8(bit32.band(bit32.rshift(bit32.bnot(len), 8), 255))
                for _ = 1, len do
                    local v = 0
                    if col >= 0 then v = buffer.readu8(pixels, row * width * 4 + col) end
                    buffer.writeu8(png, o, v); o += 1
                    a = (a + v) % 65521; b = (b + a) % 65521
                    col += 1
                    if col == width * 4 then col = -1; row += 1 end
                end
                written += len
            end
            u32(bit32.bor(bit32.lshift(b, 16), a))
        end)
        chunk("IEND", 0, function() end)
        return buffer.tostring(png)
    end

    -- Decode an embedded image (see format above) into PNG bytes.
    function Images.FromPixels(width, height, data)
        local packed, packedLen = base64Decode(data)
        local pixels = buffer.create(width * height * 4)
        local i, o, total = 0, 0, width * height * 4
        while i < packedLen and o < total do
            local control = buffer.readu8(packed, i); i += 1
            if control < 128 then
                local count = (control + 1) * 4
                buffer.copy(pixels, o, packed, i, count)
                i += count; o += count
            else
                local value = buffer.readu32(packed, i); i += 4
                for _ = 1, control - 126 do buffer.writeu32(pixels, o, value); o += 4 end
            end
        end
        return encodePng(width, height, pixels)
    end
    -- { [source] = PNG bytes or { width, height, data } } -> used instead of downloading.
    function Images.Register(map)
        for source, value in map do
            if type(value) == "table" then value = Images.FromPixels(value[1], value[2], value[3]) end
            registry[source] = value
        end
        ctx.dirty = true
    end

    -- Data for Image.Data, or nil while it is still loading (or failed).
    function ctx.imageData(source)
        if source == nil or source == "" then return nil end
        if registry[source] then return registry[source] end
        local url = toUrl(source)
        if not url then return source end
        if Images.Mode == "url" then return url end
        local entry = cache[source]
        if entry then return entry.data end
        entry = {}
        cache[source] = entry
        task.spawn(function()
            local data, err = fetch(url, 0)
            entry.data = data
            if not data then warn("[Drawui] image " .. source .. " failed to load: " .. tostring(err)) end
            ctx.dirty = true
        end)
        return nil
    end

    -- Start downloading images before they are shown.
    function Images.Preload(sources)
        for _, source in sources do ctx.imageData(source) end
    end
    -- Forget downloaded images (they are fetched again when drawn).
    function Images.Clear()
        table.clear(cache)
    end
end

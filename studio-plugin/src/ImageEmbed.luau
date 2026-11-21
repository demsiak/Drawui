-- ImageEmbed: reads an image asset's pixels in Studio (EditableImage) and encodes them for
-- Drawui's UI.Images.Register / Images.FromPixels:
--   base64( PackBits over whole RGBA pixels )
--   control byte 0..127 -> (n + 1) literal pixels follow; 128..255 -> next pixel repeated (n - 126) times
-- Roblox image assets can't be downloaded anonymously, so embedding is what makes them show up in executors.
local AssetService = game:GetService("AssetService")

local ImageEmbed = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local chars = {}
for i = 1, 64 do chars[i - 1] = string.sub(B64, i, i) end

local function base64(buf, len, lineLength)
	local lines, line = {}, {}
	local lineChars = 0
	for i = 0, len - 1, 3 do
		local a = buffer.readu8(buf, i)
		local b = i + 1 < len and buffer.readu8(buf, i + 1) or 0
		local c = i + 2 < len and buffer.readu8(buf, i + 2) or 0
		local n = a * 65536 + b * 256 + c
		local group = chars[bit32.rshift(n, 18)] .. chars[bit32.band(bit32.rshift(n, 12), 63)]
		if i + 1 < len then group ..= chars[bit32.band(bit32.rshift(n, 6), 63)] end
		if i + 2 < len then group ..= chars[bit32.band(n, 63)] end
		table.insert(line, group)
		lineChars += 4
		if lineChars >= lineLength then
			table.insert(lines, table.concat(line))
			line, lineChars = {}, 0
		end
	end
	if #line > 0 then table.insert(lines, table.concat(line)) end
	return lines
end

-- Area-average downscale; colours are weighted by alpha so edges don't get dark fringes.
local function downscale(src, sw, sh, dw, dh)
	local dst = buffer.create(dw * dh * 4)
	for y = 0, dh - 1 do
		local y0 = math.floor(y * sh / dh)
		local y1 = math.max(y0 + 1, math.floor((y + 1) * sh / dh))
		for x = 0, dw - 1 do
			local x0 = math.floor(x * sw / dw)
			local x1 = math.max(x0 + 1, math.floor((x + 1) * sw / dw))
			local r, g, b, a, n = 0, 0, 0, 0, 0
			for yy = y0, y1 - 1 do
				local row = yy * sw
				for xx = x0, x1 - 1 do
					local i = (row + xx) * 4
					local alpha = buffer.readu8(src, i + 3)
					r += buffer.readu8(src, i) * alpha
					g += buffer.readu8(src, i + 1) * alpha
					b += buffer.readu8(src, i + 2) * alpha
					a += alpha
					n += 1
				end
			end
			local o = (y * dw + x) * 4
			if a > 0 then
				buffer.writeu8(dst, o, math.round(r / a))
				buffer.writeu8(dst, o + 1, math.round(g / a))
				buffer.writeu8(dst, o + 2, math.round(b / a))
				buffer.writeu8(dst, o + 3, math.round(a / n))
			end
		end
	end
	return dst
end

-- Fully transparent pixels get RGB 0 so they compress into long runs.
local function clearTransparent(buf, count)
	for i = 0, count - 1 do
		if buffer.readu8(buf, i * 4 + 3) == 0 then buffer.writeu32(buf, i * 4, 0) end
	end
end

local function packbits(buf, count)
	local out = buffer.create(count * 4 + math.ceil(count / 128) + 16)
	local o, i = 0, 0
	while i < count do
		local v = buffer.readu32(buf, i * 4)
		local run = 1
		while i + run < count and run < 128 and buffer.readu32(buf, (i + run) * 4) == v do run += 1 end
		if run >= 2 then
			buffer.writeu8(out, o, 126 + run)
			buffer.writeu32(out, o + 1, v)
			o += 5
			i += run
		else
			local j, n = i, 0
			while j < count and n < 128 do
				if j + 1 < count and buffer.readu32(buf, j * 4) == buffer.readu32(buf, (j + 1) * 4) then break end
				n += 1
				j += 1
			end
			buffer.writeu8(out, o, n - 1)
			buffer.copy(out, o + 1, buf, i * 4, n * 4)
			o += 1 + n * 4
			i += n
		end
	end
	return out, o
end

-- "rbxassetid://123" / "http://www.roblox.com/asset/?id=123" -> "rbxassetid://123"
function ImageEmbed.Normalize(source)
	local id = source:match("^rbxassetid://(%d+)") or source:match("[?&]id=(%d+)")
	return id and ("rbxassetid://" .. id) or source
end

-- Returns width, height, base64 lines. maxSide limits the embedded resolution.
function ImageEmbed.Encode(source, maxSide)
	local image = AssetService:CreateEditableImageAsync(Content.fromUri(ImageEmbed.Normalize(source)))
	local size = image.Size
	local pixels = image:ReadPixelsBuffer(Vector2.zero, size)
	image:Destroy()
	local scale = math.min(1, maxSide / math.max(size.X, size.Y))
	local w, h = math.max(1, math.round(size.X * scale)), math.max(1, math.round(size.Y * scale))
	if w ~= size.X or h ~= size.Y then
		pixels = downscale(pixels, size.X, size.Y, w, h)
	else
		clearTransparent(pixels, w * h)
	end
	local packed, len = packbits(pixels, w * h)
	return w, h, base64(packed, len, 120)
end

return ImageEmbed

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trim(n: number, decimals: number): string
	local s = string.format("%." .. decimals .. "f", n)
	if decimals > 0 then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return s
end

-- Money display: 0, 999, 1.2K, 1.53M, 2.5B ... Never errors.
function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end
	if n == -math.huge then
		return "-∞"
	end
	if n < 0 then
		return "-" .. Format.number(-n)
	end
	if n < 1000 then
		return string.format("%d", math.floor(n))
	end

	local value, index = n, 1
	while value >= 1000 do
		value /= 1000
		index += 1
	end
	if index > #SUFFIXES then
		return string.format("%.0e", n)
	end

	local decimals = value >= 100 and 0 or value >= 10 and 1 or 2
	local rounded = tonumber(string.format("%." .. decimals .. "f", value)) :: number
	if rounded >= 1000 and index < #SUFFIXES then
		value = rounded / 1000
		index += 1
		decimals = 2
	end
	return trim(value, decimals) .. SUFFIXES[index]
end

return Format

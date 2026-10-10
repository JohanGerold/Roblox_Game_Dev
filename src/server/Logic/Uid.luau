local Uid = {}

-- prefix .. "_" .. 8 lowercase hex chars, regenerated until it isn't a key of `taken`.
function Uid.new(prefix: string, taken: { [string]: any }, rng: Random): string
	local uid
	repeat
		uid = string.format("%s_%08x", prefix, rng:NextInteger(0, 0xFFFFFFFF))
	until taken[uid] == nil
	return uid
end

return Uid

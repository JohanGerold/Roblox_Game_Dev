-- Pure base picking: owners maps base index -> owner (anything truthy).
local BaseAssign = {}

function BaseAssign.lowestFree(owners: { [number]: any }, count: number): number?
	for i = 1, count do
		if not owners[i] then
			return i
		end
	end
	return nil
end

return BaseAssign

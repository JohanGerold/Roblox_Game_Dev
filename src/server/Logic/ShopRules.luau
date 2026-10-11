-- Weapon shop and equip checks (spec section 7). Pure.
local ShopRules = {}

-- Returns true, or false plus the first failing reason.
function ShopRules.canBuy(weaponId: string, owned: { string }, money: number, distance: number, Weapons, Combat): (boolean, string?)
	local weapon = Weapons[weaponId]
	if not weapon then
		return false, "unknown weapon"
	end
	if table.find(owned, weaponId) then
		return false, "owned"
	end
	if distance > Combat.shopRange then
		return false, "too far"
	end
	if money < weapon.price then
		return false, "poor"
	end
	return true
end

function ShopRules.canEquip(kind: string, id: string, data, Weapons, Armor): (boolean, string?)
	if kind ~= "weapon" and kind ~= "armor" then
		return false, "bad kind"
	end
	local config = kind == "weapon" and Weapons or Armor
	if not config[id] then
		return false, "unknown"
	end
	local owned = kind == "weapon" and data.weapons.owned or data.armor.owned
	if not table.find(owned, id) then
		return false, "not owned"
	end
	return true
end

return ShopRules

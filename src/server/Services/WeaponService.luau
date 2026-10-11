-- Weapon shop purchases and equipping weapons and armor (spec section 7). The server checks
-- ownership, money and distance to the shop; money only moves through EconomyService:TrySpend.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.Shared.Config.Armor)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local ShopRules = require(script.Parent.Parent.Logic.ShopRules)
local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local BUY_REFUSAL = {
	["unknown weapon"] = "You can't buy that.",
	["owned"] = "You can't buy that.",
	["too far"] = "Walk up to the weapon shop.",
	["poor"] = "Not enough money.",
}

local WeaponService = {}

local function distanceToShop(player: Player): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local shop = CollectionService:GetTagged("WeaponShop")[1]
	if not root or not shop or not shop:IsA("BasePart") then
		return math.huge
	end
	return (root.Position - shop.Position).Magnitude
end

-- Returns true when the weapon was bought.
function WeaponService:Buy(player: Player, weaponId: string): boolean
	local data = DataService:Get(player)
	if not data then
		return false
	end
	local ok, reason = ShopRules.canBuy(weaponId, data.weapons.owned, data.money, distanceToShop(player), Weapons, Combat)
	if not ok then
		AnnounceService:Notice(player, BUY_REFUSAL[reason] or "You can't buy that.")
		return false
	end
	if not EconomyService:TrySpend(player, Weapons[weaponId].price) then
		AnnounceService:Notice(player, "Not enough money.")
		return false
	end
	DataService:Update(player, "weapons", function(weapons)
		table.insert(weapons.owned, weaponId)
		return weapons
	end)
	AnnounceService:Notice(player, "Bought " .. Weapons[weaponId].displayName .. "!")
	return true
end

-- Returns true when the item was equipped. kind = "weapon" | "armor".
function WeaponService:Equip(player: Player, kind: string, id: string): boolean
	local data = DataService:Get(player)
	if not data then
		return false
	end
	local ok = ShopRules.canEquip(kind, id, data, Weapons, Armor)
	if not ok then
		AnnounceService:Notice(player, "You can't equip that.")
		return false
	end
	if kind == "weapon" then
		DataService:Update(player, "weapons", function(weapons)
			weapons.equipped = id
			return weapons
		end)
	else
		DataService:Update(player, "armor", function(armor)
			armor.equipped[Armor[id].slot] = id
			return armor
		end)
	end
	return true
end

function WeaponService:Init()
	Net.Server("BuyWeapon"):On(function(player, weaponId)
		self:Buy(player, weaponId)
	end)
	Net.Server("Equip"):On(function(player, kind, id)
		self:Equip(player, kind, id)
	end)
end

return WeaponService

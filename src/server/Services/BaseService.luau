-- Gives each player one of the map's bases (found by tag), spawns them there, frees it on leave.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Server = script.Parent.Parent
local BaseAssign = require(Server.Logic.BaseAssign)
local MapContract = require(Server.Logic.MapContract)

local FULL_MESSAGE = "This server is full, please join another one."
local FREE_TEXT = "Free base"

local BaseService = {}
BaseService.Assigned = Signal.new() -- Fire(player, base: Model)

local bases: { [number]: Model } = {}
local owners: { [number]: Player } = {}
local baseOf: { [Player]: number } = {}
local hubSpawn: SpawnLocation?

local function setSign(base: Model, text: string)
	for _, d in base:GetDescendants() do
		if d:HasTag("BaseSign") then
			for _, label in d:GetDescendants() do
				if label:IsA("TextLabel") then
					label.Text = text
				end
			end
		end
	end
end

local function findTagged(base: Model, tag: string): BasePart?
	for _, d in base:GetDescendants() do
		if d:HasTag(tag) and d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

function BaseService:GetBase(player: Player): Model?
	local index = baseOf[player]
	return index and bases[index] or nil
end

function BaseService:GetOwner(baseIndex: number): Player?
	return owners[baseIndex]
end

-- Where the player's character should stand: their BaseSpawn, else the hub spawn, else above the origin.
function BaseService:GetSpawnCFrame(player: Player): CFrame
	local base = self:GetBase(player)
	local spawnPart = base and findTagged(base, "BaseSpawn")
	if spawnPart then
		return spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	if hubSpawn then
		return hubSpawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 10, 0)
end

local function placeCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or player.Parent ~= Players or character.Parent == nil or not baseOf[player] then
		return
	end
	character:PivotTo(BaseService:GetSpawnCFrame(player))
end

local function assign(player: Player)
	local index = BaseAssign.lowestFree(owners, Map.baseCount)
	local base = index and bases[index]
	if not index or not base then
		player:Kick(FULL_MESSAGE)
		return
	end
	owners[index] = player
	baseOf[player] = index
	base:SetAttribute("OwnerUserId", player.UserId)
	setSign(base, player.DisplayName .. "'s base")
	print(string.format("[BaseService] %s -> base %d", player.Name, index))
	BaseService.Assigned:Fire(player, base)

	player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
end

local function release(player: Player)
	local index = baseOf[player]
	if not index then
		return
	end
	baseOf[player] = nil
	owners[index] = nil
	local base = bases[index]
	if base then
		base:SetAttribute("OwnerUserId", nil)
		setSign(base, FREE_TEXT)
	end
end

function BaseService:Init()
	for _, base in CollectionService:GetTagged("Base") do
		local index = base:GetAttribute("BaseIndex")
		if base:IsA("Model") and type(index) == "number" then
			bases[index] = base
		end
	end
	local mapFolder = workspace:FindFirstChild("Map")
	if mapFolder then
		for _, problem in MapContract.check(mapFolder, Map) do
			warn("[BaseService] map: " .. problem)
		end
		hubSpawn = mapFolder:FindFirstChildWhichIsA("SpawnLocation", true)
	else
		warn("[BaseService] map: Workspace.Map not found")
	end
end

function BaseService:Start()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

return BaseService

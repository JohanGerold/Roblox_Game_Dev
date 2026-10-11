-- Day/night phase order and lengths. Pure.
local RoundRules = {}

function RoundRules.nextPhase(phase: string): string
	if phase == "Day" then
		return "Night"
	elseif phase == "Night" then
		return "Day"
	end
	error("unknown round phase " .. tostring(phase))
end

function RoundRules.duration(phase: string, cfg): number
	if phase == "Day" then
		return cfg.daySeconds
	elseif phase == "Night" then
		return cfg.nightSeconds
	end
	error("unknown round phase " .. tostring(phase))
end

return RoundRules

--!strict
-- İstemci giriş noktası. Arayüz ve girdi kodu buradan başlayacak.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[{Config.GameName}] Hoş geldin, {Players.LocalPlayer.Name}!`)

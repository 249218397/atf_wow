---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by hydra.
--- DateTime: 2020-01-29 02:58
---


local addonName, L = ...

local dance_macro = L.F.create_macro_button("InviterDance", "/dance")

local frame = CreateFrame("FRAME")
frame:RegisterEvent("CHAT_MSG_ADDON")

local frontend = nil

local function eventHandler(self, event, arg1, arg2, arg3, arg4)
    if L.F.is_inviter() then
        if event == "CHAT_MSG_ADDON" and arg1 == "ATF" then
            local message, author = arg2, arg4
            author = string.match(author, "([^-]+)")
            local cmd, msg = string.match(message, "(.-):(.+)")
            if cmd and msg then
                if cmd == "invite" then
                    L.F.invite_player(msg)
                    if msg == author then
                        frontend = author
                    end
                elseif cmd == "promote" then
                    PromoteToAssistant(msg)
                elseif cmd == "inviter_vip" then
                    local vip, param, value = string.match(msg, "(.-):(.-)=(.+)")
                    if vip and param and value then
                        if value == "nil" then value = nil end
                        if ATFInviterVip[vip] == nil then
                            ATFInviterVip[vip] = {}
                        end
                        ATFInviterVip[vip][param] = value
                    end
                elseif cmd == "remove_vip" then
                    ATFInviterVip[msg] = nil
                elseif cmd == "/s" then
                    L.F.whisper_or_say(msg)
                elseif cmd == "/w" then
                    local to_player, m = string.match(msg, "(.-):(.+)")
                    L.F.whisper_or_say(m, to_player)
                end
            end
        end
    end
end


local last_in_range, last_out_range = {}, {}


local function detect_member_range_change()
    local n = GetNumGroupMembers()
    local in_range, out_range = {}, {}
    local in_range_diff, out_range_diff = {}, {}
    for i = 2, n do
        local unit = "raid"..i
        local name = UnitName(unit)
        if CheckInteractDistance(unit, 2) then
            in_range[name] = true
            if last_out_range[name] then
                table.insert(in_range_diff, name)
            end
        else
            out_range[name] = true
            if last_in_range[name] then
                table.insert(out_range_diff, name)
            end
        end
    end
    last_in_range = in_range
    last_out_range = out_range
    return in_range_diff, out_range_diff
end


local function vip_emote(player, direction)
    local msg_interval = 300
    local emote, say
    if direction == "join" then
        emote = "salute"
        say = "欢迎{t}大驾光临！"
    elseif direction == "leave" then
        emote = "bye"
        say = "恭送{t}!"
    else
        emote = "question"
        say = ""
    end

    if ATFInviterVip[player] then
        if ATFInviterVip[player]["emote_"..direction] then
            emote = ATFInviterVip[player]["emote_"..direction]
        end
        if ATFInviterVip[player]["say_"..direction] then
            say = ATFInviterVip[player]["say_"..direction]
        end
        DoEmote(emote, player)
        local nick_name = ATFInviterVip[player].nick_name
        if not nick_name then nick_name = player end
        if not ATFInviterVip[player]["last_"..direction] or time() - ATFInviterVip[player]["last_"..direction] > msg_interval then
            ATFInviterVip[player]["last_"..direction] = time()
            say = string.gsub(say, "{t}", nick_name)
            say = string.gsub(say, "{n}", player)
            L.F.queue_message(say, true)
        end
        return true
    else
        return false
    end
end


local function may_emote()
    local in_range_diff, out_range_diff = detect_member_range_change()
    for _, ird in ipairs(in_range_diff) do
        if L.F.is_facing(ird) then
            if not vip_emote(ird, "join") then
                DoEmote("hello", ird)
            end
            return
        end
    end

    for _, ord in ipairs(out_range_diff) do
        if L.F.is_facing(ord) then
            if not vip_emote(ord, "leave") then
                DoEmote("bye", ord)
            end
            return
        end
    end
end


function L.F.drive_inviter()
    if UnitInParty("player") and not UnitIsGroupLeader("player") then
        LeaveParty()
        return
    end
    if frontend and GetRaidTargetIndex(frontend) == nil and UnitInParty(frontend) then
        SetRaidTarget(frontend, 6)
        PromoteToAssistant(frontend)
        frontend = nil
    end

    may_emote()

end


local last_bind_time = 0
local last_bind_cnt = 0
local bind_interval = 300


function L.F.auto_bind_inviter()
    if GetTime() - last_bind_time > bind_interval then
        if last_bind_cnt % 2 == 1 then
            SetBindingClick(L.hotkeys.interact_key, "InviterDance")
            last_bind_time = GetTime()
        else
            SetBinding(L.hotkeys.interact_key, "JUMP")
            last_bind_time = GetTime() - bind_interval + 10
        end
        last_bind_cnt = last_bind_cnt + 1
    else
        SetBinding(L.hotkeys.interact_key, "")
    end
end


frame:SetScript("OnEvent", eventHandler)

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


local function may_emote()
    local in_range_diff, out_range_diff = detect_member_range_change()
    for _, ird in ipairs(in_range_diff) do
        if L.F.is_facing(ird) then
            if ATFInviterVip[ird] then
                local emote = "salute"
                if ATFInviterVip[ird].emote_join then
                    emote = ATFInviterVip[ird].emote_join
                end
                DoEmote(emote, ird)
                L.F.queue_message("恭送"..ATFInviterVip[ird].nick_name.."大驾光临！", true)
            else
                DoEmote("hello", ird)
            end
            return
        end
    end

    for _, ord in ipairs(out_range_diff) do
        if L.F.is_facing(ord) then
            if ATFInviterVip[ord] then
                local emote = "bye"
                if ATFInviterVip[ord].emote_leave then
                    emote = ATFInviterVip[ord].emote_leave
                end
                DoEmote(emote, ord)
                L.F.queue_message("欢送"..ATFInviterVip[ord].nick_name.."！", true)
            else
                DoEmote("bye", ord)
            end
            return
        end
    end
end


function L.F.drive_inviter()
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

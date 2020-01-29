---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by hydra.
--- DateTime: 2020-01-17 23:01
---

local addonName, L = ...

local frame = CreateFrame("FRAME", "ATFFrame")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("CHAT_MSG_ADDON")


local timeout = L.reset_instance_timeout
local last_pind_ts = 0
local reseters_available = {}
local ping_interval = 20


local reseter_context = {
    player=nil,
    request_ts=nil,
    invite_ts=nil,
    reset=nil,
    frontend=nil,
}


local function can_reset(player)
    return UnitInParty(player) and not UnitIsConnected(player) and reseter_context.invite_ts and GetTime() - reseter_context.invite_ts > 2
end


function L.F.drive_reset_instance()
    local player = reseter_context.player
    if player then
        if GetTime() - reseter_context.request_ts > timeout then
            L.F.whisper("未能重置，您未在规定时间内下线。", player)
            LeaveParty()
            reseter_context = {}
        elseif reseter_context.reset then
            reseter_context = {}
            UninviteUnit(player)
        elseif can_reset(player) then
            print("reseting")
            ResetInstances()
            print("reseted")
            reseter_context.reset = true
            SendChatMessage("米豪已帮【"..player.."】重置副本。请M "..reseter_context.frontend.." 【"..L.cmds.reset_instance_help.."】查看使用方法。", "say")
        end
    end
end


local function should_ping()
    return GetTime() - last_pind_ts > ping_interval
end


function L.F.ping_reseters()
    if should_ping() then
        last_pind_ts = GetTime()
        for reseter, _ in pairs(InstanceResetBackends) do
            print("pinging "..reseter)
            C_ChatInfo.SendAddonMessage("ATF", "ping_reseter", "WHISPER", reseter)
        end
    end
    for reseter, ts in pairs(reseters_available) do
        if GetTime() - ts > ping_interval * 2 then
            reseters_available[reseter] = nil
        end
    end
end


function L.F.reset_instance_request_frontend(player)
    local backends = {}
    for backend, _ in pairs(reseters_available) do
        table.insert(backends, backend)
    end

    if #backends > 0 then
        local backend = backends[math.random(1, #backends)]
        C_ChatInfo.SendAddonMessage("ATF", "reset:"..player, "WHISPER", backend)
        L.F.whisper("重置请求已转发至重置后端【"..backend.."】，请等待其回应。", player)
    else
        L.F.whisper("重置服务离线，待重置后端账号上线后可用。", player)
    end
end


function L.F.reset_instance_request(player, frontend)
    if not (L.F.watch_dog_ok()) then
        L.F.whisper(
                "米豪的驱动程序出现故障，重置副本功能暂时失效，请等待米豪的维修师进行修复。十分抱歉！", player)
        return
    end
    assert(not L.F.is_frontend())

    if UnitInParty(player) then
        if reseter_context.player == player then
            L.F.whisper("【重置流程变更】当前版本只需在【未进组】的情况下M我一次请求即可。无需再次请求。", player)
        else
            L.F.whisper("【重置流程变更】为避免高峰期重置冲突，重置流程发生变化，您务必在【未进组】的前提下想我发起请求。本次请求失败。", player)
        end
        return
    end

    if reseter_context.player == nil then
        reseter_context.player = player
        reseter_context.request_ts = GetTime()
        reseter_context.frontend = frontend
        LeaveParty()
        InviteUnit(player)
        L.F.whisper("请接受组队邀请，然后立即下线。请求有效期"..timeout.."秒。", player)
    elseif reseter_context.player == player then
        L.F.whisper("请接受组队邀请，然后立即下线。", player)
    else
        L.F.whisper("正在有玩家请求重置，请稍后再试。", player)
    end
end


function L.F.say_reset_instance_help(to_player)
    L.F.whisper("重置副本功能可以帮您迅速传送至副本门口，并对副本内怪物进行重置。请按如下步骤操作", to_player)
    L.F.whisper("1. 请确保您不在队伍中，然后M我【"..L.cmds.reset_instance_cmd.."】", to_player)
    L.F.whisper("2. 如果请求成功，我的【重置工具人】会向您发起组队邀请。请您进入队伍后在"..timeout.."秒内下线。", to_player)
    L.F.whisper("3. 一旦您下线，我会立即重置副本。", to_player)
    L.F.whisper("4. 如果您未爆本，下次上线您将会出现在副本门口，且副本内怪物已重置。", to_player)
end


function L.F.bind_reseter_backend()
    SetBinding(L.hotkeys.interact_key, "JUMP")
end


local function eventHandler(self, event, arg1, arg2, arg3, arg4)
    if not(L.atfr_run) then
        return
    end

    if event == 'CHAT_MSG_SYSTEM' then
        local message = arg1
        if reseter_context.player then
            if string.format(ERR_DECLINE_GROUP_S, reseter_context.player) == message
                    or string.format(ERR_ALREADY_IN_GROUP_S, reseter_context.player) == message then
                L.F.whisper("您拒绝了组队邀请，重置请求已取消。", reseter_context.player)
                reseter_context = {}
            elseif string.format(ERR_JOINED_GROUP_S, reseter_context.player) == message
                    or string.format(ERR_RAID_MEMBER_ADDED_S, reseter_context.player) == message then
                L.F.whisper("请抓紧时间下线，我将在您下线后立即重置副本。", reseter_context.player)
                reseter_context.invite_ts = GetTime()
            elseif string.format(ERR_LEFT_GROUP_S, reseter_context.player) == message
                    or string.format(ERR_RAID_MEMBER_REMOVED_S, reseter_context.player) == message
                    or ERR_GROUP_DISBANDED == message then
                L.F.whisper("您离开了队伍，重置请求已取消。", reseter_context.player)
                reseter_context = {}
            end
        end
    elseif event == "CHAT_MSG_ADDON" and arg1 == "ATF" then
        local message, author = arg2, arg4
        author = string.match(author, "([^-]+)")
        print(author, message)
        if L.F.is_frontend() then
            if message == "pong_reseter" and InstanceResetBackends[author] then
                print("received pong from "..author)
                reseters_available[author] = GetTime()
            end
        else
            if message == "ping_reseter" then
                C_ChatInfo.SendAddonMessage("ATF", "pong_reseter", "WHISPER", author)
            else
                local cmd, target = string.match(message, "(.-):(.+)")
                if cmd and target then
                    if cmd == "reset" then
                        author = string.match(author, "([^-]+)") or author
                        L.F.reset_instance_request(target, author)
                    end
                end
            end
        end
    end
end

frame:SetScript("OnEvent", eventHandler)

--[[
 * @license LT Bridge
 * server.lua
 *
 * Copyright (c) LT Scripts.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]

--- @diagnostic disable
LT = LT or {}
LT.Version = LT.Version or {}

local format = string.format
local PerformHttpRequest = PerformHttpRequest
local function resolvePrintFormats(messages)
    return {
        upToDate = (messages and messages.upToDate) or '^2[%s]^7 Up-to-date (v%s)',
        updateAvailable = (messages and messages.updateAvailable) or '^3[%s]^7 Update available: ^1v%s^7 → ^2v%s^7',
        download = (messages and messages.download) or '  Download: ^4%s^7',
    }
end
local function extractSemver(s)
    if not s then return nil end
    return s:match('%d+%.%d+%.%d+')
end
local function printVersionStatus(resourceName, msgs, currentShown, remoteShown, needsUpdate, downloadLink, sendUpToDate)
    if not needsUpdate then
        if sendUpToDate then
            print(format(msgs.upToDate, resourceName, currentShown))
        end
        return
    end
    print(format(msgs.updateAvailable, resourceName, currentShown, remoteShown))
    print(format(msgs.download, downloadLink))
end
local function parseRemoteFromUrlBody(fileType, body, resourceName)
    if fileType == 'JSON' then
        local decoded = json.decode(body)
        if not decoded or not decoded[resourceName] then
            LT.printf('warning',
                'Version check for %s resource failed. No matching version was found on the source, or the source URL could not be reached.',
                resourceName)
            return nil
        end
        return decoded[resourceName]
    end
    if fileType == 'PLAIN' then
        return tostring(body):gsub('%s+', '')
    end
    LT.printf('warning', 'Invalid version file type: %s', fileType)
    return nil
end
function LT.Version.Check(data, messages)
    local resourceName <const> = (data and data.resourceName) or __LT_RESOURCE_NAME
    local currentVersion <const> = GetResourceMetadata(resourceName, 'version', 0)
        if not LT.ltassert(currentVersion, 'no version found for resource %s.', resourceName) then return false end
    local msgs <const> = resolvePrintFormats(messages)
    local sendUpToDate <const> = data and data.sendUpToDate == true
    local repo <const> = data and (data.repository or data.repo) or nil
    if repo ~= nil then
        local currentSemver <const> = extractSemver(currentVersion)
        if not currentSemver then
            LT.printf('warning', 'Unable to determine semantic version (x.y.z) for %s. Found: %s', resourceName,
                currentVersion)
            return
        end
        PerformHttpRequest(format('https://api.github.com/repos/%s/releases/latest', repo),
            function(statusCode, body)
                if statusCode ~= 200 then return end
                local payload = json.decode(body)
                if not payload or payload.prerelease or not payload.tag_name then return end
                local latestSemver = extractSemver(payload.tag_name)
                local needsUpdate = latestSemver ~= nil and latestSemver ~= currentSemver
                printVersionStatus(resourceName, msgs, currentSemver, latestSemver or '', needsUpdate,
                    needsUpdate and (payload.html_url or '') or '', sendUpToDate)
            end, 'GET')
        return
    end
    local fileType = (data and data.fileType) or 'JSON'
    local url = data and data.url
        if not LT.ltassert(url, 'no URL provided for resource version check %s.', resourceName) then return false end
    local downloadURL <const> = (data and data.downloadUrl) or ''
    PerformHttpRequest(url, function(statusCode, body, _)
        if statusCode ~= 200 or not body then return end
        local remoteVersion = parseRemoteFromUrlBody(fileType, body, resourceName)
        if not remoteVersion or remoteVersion == '' then return end
        local needsUpdate = currentVersion ~= remoteVersion
        printVersionStatus(resourceName, msgs, currentVersion, remoteVersion, needsUpdate, downloadURL,
            sendUpToDate)
    end, 'GET')
end

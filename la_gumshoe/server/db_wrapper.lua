local M = {}

local function defaultLogger(level, message)
    print(("[gumshoe][%s] %s"):format(level, message))
end

local activeDriver = nil
local logger = defaultLogger

local function log(level, message)
    if logger then
        logger(level, message)
    else
        defaultLogger(level, message)
    end
end

local function getResourceState(name)
    if type(GetResourceState) == "function" then
        local ok, state = pcall(GetResourceState, name)
        if ok then
            return state
        end
    end
    return "missing"
end

local function awaitAsync(executor)
    if promise and promise.new and Citizen and Citizen.Await then
        local p = promise.new()
        executor(function(result)
            p:resolve(result)
        end)
        local ok, res = pcall(Citizen.Await, p)
        if ok then
            return res
        end
        return { ok = false, err = tostring(res or "await_failed") }
    end

    local resolved
    local function resolver(result)
        resolved = result
    end
    executor(resolver)
    return resolved
end

local function ensureDriver()
    if not activeDriver then
        return nil, { ok = false, err = "no_active_database_driver" }
    end
    return activeDriver
end

local function buildOxmysqlDriver(opts)
    local ox = opts.exports and opts.exports.oxmysql or (exports and exports.oxmysql)
    if not ox then
        return nil
    end

    local state = getResourceState("oxmysql")
    if state ~= "started" and state ~= "starting" then
        return nil
    end

    local driver = {}
    driver.label = "oxmysql"

    driver.execute = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            ox:execute(query, params or {}, function(affected)
                resolve({ ok = true, data = { affected_rows = affected } })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "oxmysql_execute_failed" }
    end

    driver.insert = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            ox:insert(query, params or {}, function(id)
                resolve({ ok = true, data = { insert_id = id } })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "oxmysql_insert_failed" }
    end

    driver.fetch_all = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            ox:fetch(query, params or {}, function(rows)
                resolve({ ok = true, data = rows or {} })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "oxmysql_fetch_failed" }
    end

    driver.fetch = function(query, params)
        local response = driver.fetch_all(query, params)
        if not response or not response.ok then
            return response
        end
        return { ok = true, data = (response.data and response.data[1]) or nil }
    end

    driver.scalar = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            ox:scalar(query, params or {}, function(value)
                resolve({ ok = true, data = value })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "oxmysql_scalar_failed" }
    end

    return driver
end

local function buildMysqlAsyncDriver()
    if not MySQL or not MySQL.Async then
        return nil
    end

    local driver = {}
    driver.label = "mysql-async"

    driver.execute = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            MySQL.Async.execute(query, params or {}, function(affected)
                resolve({ ok = true, data = { affected_rows = affected } })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "mysql_async_execute_failed" }
    end

    driver.insert = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            MySQL.Async.insert(query, params or {}, function(id)
                resolve({ ok = true, data = { insert_id = id } })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "mysql_async_insert_failed" }
    end

    driver.fetch_all = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            MySQL.Async.fetchAll(query, params or {}, function(rows)
                resolve({ ok = true, data = rows or {} })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "mysql_async_fetch_failed" }
    end

    driver.fetch = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            MySQL.Async.fetchAll(query, params or {}, function(rows)
                resolve({ ok = true, data = (rows and rows[1]) or nil })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "mysql_async_fetch_failed" }
    end

    driver.scalar = function(query, params)
        if type(query) ~= "string" then
            return { ok = false, err = "invalid_query" }
        end
        local result = awaitAsync(function(resolve)
            MySQL.Async.fetchScalar(query, params or {}, function(value)
                resolve({ ok = true, data = value })
            end)
        end)
        if result and result.ok then
            return result
        end
        return result or { ok = false, err = "mysql_async_scalar_failed" }
    end

    return driver
end

function M.init(opts)
    opts = opts or {}
    logger = opts.logger or defaultLogger

    local prefer = opts.preferDriver or opts.prefer_driver
    local driver

    if prefer == "oxmysql" then
        driver = buildOxmysqlDriver(opts)
        if not driver then
            log("warn", "preferred oxmysql unavailable; attempting mysql-async")
        end
    elseif prefer == "mysql-async" then
        driver = buildMysqlAsyncDriver()
        if not driver then
            log("warn", "preferred mysql-async unavailable; attempting oxmysql")
        end
    end

    if not driver then
        driver = buildOxmysqlDriver(opts)
    end
    if not driver then
        driver = buildMysqlAsyncDriver()
    end

    if not driver then
        activeDriver = nil
        log("error", "no database driver detected (oxmysql or mysql-async)")
        return { ok = false, err = "no_database_driver" }
    end

    activeDriver = driver
    log("info", ("database driver active: %s"):format(driver.label))
    return { ok = true, data = { driver = driver.label } }
end

function M.ready()
    return activeDriver ~= nil
end

function M.execute(query, params)
    local driver, err = ensureDriver()
    if not driver then
        return err
    end
    return driver.execute(query, params)
end

function M.insert(query, params)
    local driver, err = ensureDriver()
    if not driver then
        return err
    end
    return driver.insert(query, params)
end

function M.fetch(query, params)
    local driver, err = ensureDriver()
    if not driver then
        return err
    end
    if driver.fetch then
        return driver.fetch(query, params)
    end
    local response = driver.fetch_all(query, params)
    if not response or not response.ok then
        return response
    end
    return { ok = true, data = response.data and response.data[1] or nil }
end

function M.fetch_all(query, params)
    local driver, err = ensureDriver()
    if not driver then
        return err
    end
    if driver.fetch_all then
        return driver.fetch_all(query, params)
    end
    return { ok = false, err = "fetch_all_not_supported" }
end

function M.scalar(query, params)
    local driver, err = ensureDriver()
    if not driver then
        return err
    end
    if driver.scalar then
        return driver.scalar(query, params)
    end
    return { ok = false, err = "scalar_not_supported" }
end

return M

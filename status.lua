local redis = require "redtool"
local utils = require "utils"
local config = require "config"

if not ngx.var.arg_host then
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

if not utils.check_if_analysis(ngx.var.arg_host) then
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local function calc_status(host)
    local rds = redis:new()
    local status_key = config.REDIS_PREFIX.."erulb:"..host..":status"
    local cost_key = config.REDIS_PREFIX.."erulb:"..host..":cost"
    local total_key = config.REDIS_PREFIX.."erulb:"..host..":count"
    local miss_key = config.REDIS_PREFIX.."erulb:"..host..":miss"
    local hit_key = config.REDIS_PREFIX.."erulb:"..host..":hit"
    local wrong_key = config.REDIS_PREFIX.."erulb:"..host..":wrong"
    local right_key = config.REDIS_PREFIX.."erulb:"..host..":right"
    local result = {}

    local total, err = rds:get(total_key)
    if err or not total then
        return nil, err
    end
    local miss, err = rds:get(miss_key)
    if err or not miss then
        miss = 0
    end
    local cost, err = rds:get(cost_key)
    if err or not cost then
        cost = 0
    end
    local status, err = rds:hgetall(status_key)
    if err or not status then
        status = {}
    end
    local hit, err = rds:get(hit_key)
    if err or not hit then
        hit = 0
    end
    local right, err = rds:get(right_key)
    if err or not right then
        right = 0
    end
    local wrong, err = rds:get(wrong_key)
    if err or not wrong then
        wrong = 0
    end
    result["status"] = {}
    for i=1,#status,2 do
        result["status"][status[i]] = status[i + 1]
    end
    result["total"] = tonumber(total)
    result["cost"] = tonumber(cost)
    result["miss"] = tonumber(miss)
    result["hit"] = tonumber(hit)
    result["wrong"] = tonumber(wrong)
    result["right"] = tonumber(right)

    result["per_resp_time"] = 0
    result["error_percent"] = 0
    result["ok_percent"] = 0
    if result["hit"] ~= 0 then
        result["per_resp_time"] = result["cost"] / result["hit"]
        result["error_percent"] = result["wrong"] / result["hit"]
        result["ok_percent"] = result["right"] / result["hit"]
    end
    return result, nil
end

local host = ngx.var.arg_host
utils.get_from_route_table(host)

local result, err = calc_status(host)
if err then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

ngx.say(cjson.encode(result))

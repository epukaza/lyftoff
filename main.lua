print("starting main.lua")

local pin = 6

function debounce (func)
    local last = 0
    local delay = 200000

    return function (...)
        local now = tmr.now()
        if now - last < delay then return end

        last = now
        return func(...)
    end
end

function onChange ()
    print('The pin value has changed to '..gpio.read(pin))
end

gpio.mode(pin, gpio.INT)
gpio.trig(pin, 'both', debounce(onChange))
print("starting main.lua")

local srv = nil
local button_pin = 6
local pwm_pin = 1
local pwm_timer = 1
local pwm_freq = 500
local pwm_max_bright = 1023

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
    print('LYFT OFF!')
end

function startServer()
  debug_message('server start')
  debug_message(srv)

  if srv then
    srv = nil
  end
  srv = net.createServer(net.TCP, 30)
  srv:listen(80, connect)
  debug_message(srv)
end

function stopServer()
  debug_message('server stop')
  debug_message(srv)
  if srv then
    srv:close()
    srv = nil
  end
  debug_message(srv)
end

function connect(sock)
  sock:on('receive', function(sck, payload)
    conn:send('HTTP/1.1 200 OK\r\n\r\n' .. 'Hello world')
  end)

  sock:on('send', function(sck)
    sck:close()
  end)
end

function onStart()
  debug_message('onStart')

  -- register PWM and set low
  -- tmr.unregister(pwm_timer)
  pwm.setup(pwm_pin, pwm_freq, 0)
  pwm.start(pwm_pin)
  -- pwm.stop(pwm_pin)
end

function pwm_fadein()
  local brightness = pwm.getduty(pwm_pin)

  if brightness >= pwm_max_bright then
    tmr.unregister(pwm_timer)
  else
    pwm.setduty(pwm_pin, brightness + 1)
    tmr.alarm(pwm_timer, 2, tmr.ALARM_SINGLE, pwm_fadein)
  end
end

function pwm_fadeout()
  local brightness = pwm.getduty(pwm_pin)

  if brightness <= 0 then
    tmr.unregister(pwm_timer)
  else
    pwm.setduty(pwm_pin, brightness - 3)
    tmr.alarm(pwm_timer, 2, tmr.ALARM_SINGLE, pwm_fadeout)
  end
end

onStart()
startServer()
gpio.mode(button_pin, gpio.INT)
gpio.trig(button_pin, 'both', debounce(onChange))
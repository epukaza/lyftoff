print("starting main.lua")

local srv = nil
local button_pin = 6
local pwm_pin = 1
local pwm_timer = 1
local pwm_freq = 500
local pwm_max_bright = 1023
local config = nil -- sensitive data loaded at runtime

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
  http.post(
    'https://api.lyft.com/oauth/token',
    'Content-Type: application/json',
    '{"grant_type": "refresh_token", "refresh_token": "' .. config.refresh_token .. '"}',
    function(code, data)
      debug_message('refresh status code: ' .. (code or 'nil'))
      debug_message('refresh resp data: ' .. (data or 'nil'))

      openBrace, closeBrace = string.find(data, '^{.*}')
      json_data = cjson.decode(string.sub(data, openBrace, closeBrace))
      for k,v in pairs(json_data) do print(k, v) end

      http.get(
        'https://maker.ifttt.com/trigger/lyftoff/with/key/' .. config.ifttt_event_key,
        nil,
        function(code, data)
          debug_message('status code: ' .. (code or 'nil'))
          debug_message('resp data: ' .. (data or 'nil'))
        end
      )
    end
  )
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

  debug_message('onStart: reading config')
  file.open('config.json')
  config = cjson.decode(file.read())
  file.close()

  debug_message('onStart: enable pwm')
  pwm.setup(pwm_pin, pwm_freq, 0)
  pwm.start(pwm_pin)

  debug_message('onStart: connecting')
  wifi.sta.config(config.ssid, config.pwd)
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
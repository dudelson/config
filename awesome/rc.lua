-- note that we have restarted awesome in the log file
print("-=-=- RESTART " .. os.date("%a %b %d %X") .. " -=-=-")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
awful.autofocus = require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
-- alt+tab functionality
local alttab = require("alttab")
-- homegrown system information widget
local sysmonitor = require("sysmonitor")
-- homegrown update notifications widget
local update_notifications = require("update_notifications")
-- calendar widget from wiki
local cal = require("cal")
-- homegrown caffeine widget
local caffeine = require("caffeine")
-- yaml library for parsing my config
local yaml = require("yaml")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init("/usr/share/awesome/themes/default/theme.lua")

-- This is used later as the default terminal and editor to run.
terminal = "urxvt"
editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts =
{
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    --awful.layout.suit.spiral,
    --awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    --awful.layout.suit.max.fullscreen,
    --awful.layout.suit.magnifier
}

-- read custom configuration yaml
local dudelson_config = yaml.loadpath("/home/david/.config/dotfiles.yml")
-- }}}

-- {{{ Wallpaper
if beautiful.wallpaper then
    for s = 1, screen.count() do
        gears.wallpaper.maximized(beautiful.wallpaper, s, true)
    end
end
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}

-- Layout and name tags based on custom configuration
local screens = {}
local default_tags = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local default_layout = { layouts[1], layouts[1], layouts[1], layouts[1], layouts[1],
                         layouts[1], layouts[1], layouts[1], layouts[1] }

-- initialize screens with default configuration
for i, name in ipairs(dudelson_config.monitors) do
  -- append new table to the end of `screens'
  screens[#screens+1] = {
    name = name,
    index = screen[name].index,
    layout = default_layout,
    tags = default_tags
  }
end

-- apply specialized configuration to screens that contain pinned applications
-- we also build the apps table in this loop, which is used in subsequent sections
apps = {}
for app, screentag in pairs(dudelson_config.application_layout) do
  local screen = screentag[1]
  local tag = screentag[2]
  if     app == "terminal"  then tl = { tag = "term",    layout = layouts[2] }
  elseif app == "browser"   then tl = { tag = "browser", layout = layouts[8] }
  elseif app == "emacs"     then tl = { tag = "emacs",   layout = layouts[8] }
  elseif app == "telegram"  then tl = { tag = "tg",      layout = layouts[8] }
  else                           tl = { tag = "unknown", layout = layouts[1] }
  end
  screens[screen].tags[tag] = tl.tag
  screens[screen].layout[tag] = tl.layout
  -- add this app to the apps table
  apps[app] = { screen = screens[screen].index, tag = tag }
end

-- apply the above
for i, s in ipairs(screens) do
  tags[s.index] = awful.tag(s.tags, s.index, s.layout)
end
-- }}}

-- {{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })


-- {{{ Wibox
-- Create a textclock widget
mytextclock = awful.widget.textclock()
mytextclock:set_font("source code pro 9")
-- add calendar widget to clock
cal.register(mytextclock)

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  -- Without this, the following
                                                  -- :isvisible() makes no sense
                                                  c.minimized = false
                                                  if not c:isvisible() then
                                                      awful.tag.viewonly(c:tags()[1])
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({
                                                      theme = { width = 250 }
                                                  })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })

    -- Widgets that are aligned to the left
    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(mylauncher)
    left_layout:add(mytaglist[s])
    left_layout:add(mypromptbox[s])

    -- Widgets that are aligned to the right
    local right_layout = wibox.layout.fixed.horizontal()
    -- add my homegrown sysmonitor widget
    if s == 1 then right_layout:add(sysmonitor.widget) end
    -- add my caffeine widget
    if s == 1 then right_layout:add(caffeine.widget) end
    -- add my homegrown update_notifications widget

    -- I have here for your browsing pleasure a wonderfully stupid hack.
    -- update_notifications.init() takes about a second and a half to complete
    -- because it opens a network connection. This makes awesome slow to start
    -- up. To get around this and reclaim my glorious fraction-of-a-second
    -- loading times, I start a timer that calls update_notifications.init()
    -- after a small amount of time, then turns itself off. This effectively
    -- makes the update_notifications widget load asynchronously.
    --local update_notifications_timer = timer({ timeout = 5 })
    --update_notifications_timer:connect_signal("timeout", function()
	--update_notifications.init()
	--update_notifications_timer:stop()
    --end)
    --if s == 1 then update_notifications_timer:start() end
    if s == 1 then right_layout:add(update_notifications.widget) end
    if s == 1 then right_layout:add(wibox.widget.systray()) end
    right_layout:add(mytextclock)
    right_layout:add(mylayoutbox[s])

    -- Now bring it all together (with the tasklist in the middle)
    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    layout:set_middle(mytasklist[s])
    layout:set_right(right_layout)

    mywibox[s]:set_widget(layout)
end
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings

-------------------- keybindings that depend on configuration ------------------
-- Movement between windows
local movement_keys = {}
if #dudelson_config.monitors > 1 then
  -- with multiple monitors
  movement_keys = awful.util.table.join(
    awful.key({ modkey,           }, "j",
      function ()
        awful.client.focus.global_bydirection("left");
        if client.focus then client.focus:raise() end
    end),
    awful.key({ modkey,           }, "k",
      function ()
        awful.client.focus.global_bydirection("right");
        if client.focus then client.focus:raise() end
    end)
  )
else
  -- with just one monitor
  movement_keys = awful.util.table.join(
    awful.key({ modkey }, "j", function () awful.client.focus.bydirection("down")
        if client.focus then client.focus:raise() end
    end),
    awful.key({ modkey }, "k", function () awful.client.focus.bydirection("up")
        if client.focus then client.focus:raise() end
    end),
    awful.key({ modkey }, "h", function () awful.client.focus.bydirection("left")
        if client.focus then client.focus:raise() end
    end),
    awful.key({ modkey }, "l", function () awful.client.focus.bydirection("right")
        if client.focus then client.focus:raise() end
    end)
  )
end

----------------- keybindings that don't depend on configuration ---------------
globalkeys = awful.util.table.join(
    -- Movement between tags
    awful.key({ modkey,           }, "c",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "v",   awful.tag.viewnext       ),
    awful.key({ modkey,           }, "z", awful.tag.history.restore),

    awful.key({ modkey,           }, "w", function () mymainmenu:show() end),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "y", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.util.spawn(terminal) end),
    awful.key({ modkey,           }, "b", function () awful.util.spawn("firefox") end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),
    -- Change "h" and "l" to "u" and "i" because mod4+l locks the screen when running linux as
    -- virtual guest on windows
    awful.key({ modkey,           }, "i",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "u",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "u",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "i",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "u",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "i",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey, "Control" }, "n", awful.client.restore),

    -- Prompt
    awful.key({ modkey },            "x",     function () mypromptbox[mouse.screen]:run() end),

    awful.key({ modkey }, "r",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end),
    -- pause sysmonitor stats updates
    awful.key({ modkey },            "s",     sysmonitor.toggle_freeze ),
    -- Alt+tab
    awful.key({"Mod1",          }, "Tab",
	function ()
	    alttab.switch(1, "Alt_L", "Tab", "ISO_Left_Tab")
	end
    ),

    awful.key({"Mod1", "Shift"  }, "Tab",
	function()
	    alttab.switch(-1, "Alt_L", "Tab", "ISO_Left_Tab")
	end
    ),
    -- Printscreen
    awful.key({                 }, "Print",
	function()
	    awful.util.spawn(os.date('maim /tmp/screenshot_%Y-%m-%d_%X.png'), false)
	end
    ),

    -- Keybindings to focus specific tags
    -- "Mod1" is left alt
    -- jump to terminal tag
    awful.key({ modkey, "Mod1"   }, "j", function ()
        awful.tag.viewonly(tags[apps.terminal.screen][apps.terminal.tag])
        awful.screen.focus(apps.terminal.screen)
    end),
    -- jump to browser tag
    awful.key({ modkey, "Mod1"   }, "k", function ()
        awful.tag.viewonly(tags[apps.browser.screen][apps.browser.tag])
        awful.screen.focus(apps.browser.screen)
    end),
    -- jump to spacemacs tag
    awful.key({ modkey, "Mod1"   }, "l", function ()
        local tag = dudelson_config.application_layout.emacs[2]
        awful.tag.viewonly(tags[apps.emacs.screen][apps.emacs.tag])
        awful.screen.focus(apps.emacs.screen)
    end),
    -- jump to telegram tag
    awful.key({ modkey, "Mod1"   }, "i", function ()
        local tag = dudelson_config.application_layout.telegram[2]
        awful.tag.viewonly(tags[apps.telegram.screen][apps.telegram.tag])
        awful.screen.focus(apps.telegram.screen)
    end)
)

-- Add the configuration-dependent keybingings to the global keybinding table
globalkeys = awful.util.table.join(globalkeys, movement_keys)

-- only add keybinding for lock screen if lock screen is enabled
if dudelson_config.autostart.lock_screen then
  globalkeys = awful.util.table.join(globalkeys, awful.key(
    { modkey, "Shift" }, "l",
    function()
      awful.util.spawn('lock')
    end
  ))
end

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey,           }, ",",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = awful.util.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        local tag = awful.tag.gettags(screen)[i]
                        if tag then
                           awful.tag.viewonly(tag)
                        end
                  end),
        -- Toggle tag.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      local tag = awful.tag.gettags(screen)[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = awful.tag.gettags(client.focus.screen)[i]
                          if tag then
                              awful.client.movetotag(tag)
                          end
                     end
                  end),
        -- Toggle tag.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = awful.tag.gettags(client.focus.screen)[i]
                          if tag then
                              awful.client.toggletag(tag)
                          end
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule_any = { class = {"MPlayer", "pinentry", "Gimp", "feh"} },
      properties = { floating = true } },
    { rule = { class = "Firefox" },
      properties = { tag = tags[apps.browser.screen][apps.browser.tag] } },
    { rule = { class = "Emacs" },
      properties = { tag = tags[apps.emacs.screen][apps.emacs.tag] } },
    { rule = { class = "Telegram" },
      properties = { tag = tags[apps.telegram.screen][apps.telegram.tag] } },
    -- this rule fixes a problem with urxvt and emacs where the desktop
    -- was visible along the bottom and right edges of the screen
    { rule_any = { class = { "Emacs", "URxvt" } },
      properties = { size_hints_honor = false } },

}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end

    local titlebars_enabled = false
    if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
        -- buttons for the titlebar
        local buttons = awful.util.table.join(
                awful.button({ }, 1, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.move(c)
                end),
                awful.button({ }, 3, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.resize(c)
                end)
                )

        -- Widgets that are aligned to the left
        local left_layout = wibox.layout.fixed.horizontal()
        left_layout:add(awful.titlebar.widget.iconwidget(c))
        left_layout:buttons(buttons)

        -- Widgets that are aligned to the right
        local right_layout = wibox.layout.fixed.horizontal()
        right_layout:add(awful.titlebar.widget.floatingbutton(c))
        right_layout:add(awful.titlebar.widget.maximizedbutton(c))
        right_layout:add(awful.titlebar.widget.stickybutton(c))
        right_layout:add(awful.titlebar.widget.ontopbutton(c))
        right_layout:add(awful.titlebar.widget.closebutton(c))

        -- The title goes in the middle
        local middle_layout = wibox.layout.flex.horizontal()
        local title = awful.titlebar.widget.titlewidget(c)
        title:set_align("center")
        middle_layout:add(title)
        middle_layout:buttons(buttons)

        -- Now bring it all together
        local layout = wibox.layout.align.horizontal()
        layout:set_left(left_layout)
        layout:set_right(right_layout)
        layout:set_middle(middle_layout)

        awful.titlebar(c):set_widget(layout)
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- auto-jump to urgent windows
client.connect_signal("property::urgent", function(c) awful.client.urgent.jumpto() end)
-- }}}



-- autostart applications

-- this function ensures that two instances of each icon do not appear in the
-- event that awesome wm is restarted
function run_once(cmd)
  -- really clumsy way of getting 0th whitespace-delimited token from cmd
  firstspace = cmd:find(" ")
  if firstspace then findme = cmd:sub(0, firstspace-1) else findme = cmd end
  awful.util.spawn_with_shell("pgrep -u $USER \"" .. findme .. "\" > /dev/null || (" .. cmd .. ")")
end

-- set wallpaper
if dudelson_config.autostart.wallpaper then run_once("sh ~/.fehbg") end
-- networkmanager
if dudelson_config.autostart.network_manager then run_once("nm-applet") end
-- volumeicon
if dudelson_config.autostart.volumeicon then run_once("volumeicon") end
-- dropbox
if dudelson_config.autostart.dropbox then run_once("dropbox") end
-- automounting of usbs
if dudelson_config.autostart.udiskie then run_once("udiskie") end
-- so my screen doesn't kill my eyes at night
if dudelson_config.autostart.flux then run_once("xflux -z 14850") end
-- this user instance of anacron is responsible for running daily backups
if dudelson_config.autostart.backups then
  run_once("anacron -t /home/david/.anacron/etc/anacrontab -S /home/david/.anacron/spool &> /home/david/.anacron/anacron.log")
end
-- lock the screen automatically after 5 minutes
if dudelson_config.autostart.lock_screen then
  run_once("/usr/bin/xautolock -time 5 -locker /bin/lock -detectsleep")
end
-- autostart user-facing applications
-- start them in the order of least process-intensive to most process-intensive
run_once("urxvt")
run_once("emacs")
run_once("firefox")

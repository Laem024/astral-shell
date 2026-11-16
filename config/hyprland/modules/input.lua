hl.config({
  input = {
    kb_layout  = "us",
    -- AltGr internacional: ' y " se escriben directamente y las tildes o
    -- diéresis quedan en AltGr + tecla (por ejemplo, AltGr + ').
    kb_variant = "altgr-intl",
    kb_model   = "",
    kb_options = "",
    kb_rules   = "",

    follow_mouse = 1,

    sensitivity = 0,

    numlock_by_default = true,
    repeat_delay       = 250,
    repeat_rate        = 35,

    touchpad = {
      natural_scroll       = false,
      clickfinger_behavior = true,
    },
  },
})

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace"
})

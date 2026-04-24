Panels = Panels or {
    ScrollType      = { AUTO = "AUTO", RAIL = "RAIL" },
    ScrollDirection = { NONE = "NONE", LEFT_RIGHT = "LEFT_RIGHT", TOP_BOTTOM = "TOP_BOTTOM" },
    Input           = { A = "AButton", B = "BButton", UP = "up", DOWN = "down", LEFT = "left", RIGHT = "right" },
    vars            = { lang = "en" },
}
Graphics  = Graphics  or { kColorWhite = "white", kColorBlack = "black" }
Utilities = Utilities or { renderLangPanel = function() end }

require "assets/comics/intro"
require "assets/comics/pick-the-device"

comics = {
    ["intro"] = intro,
    ["pick-the-device"] = pickDevice
}

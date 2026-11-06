.pragma library

var bg = "#0e0f13";
var panel = "#181a21";
var panelHi = "#232631";
var text = "#f4f5f8";
var dim = "#9aa0ad";
var accent = "#ff4f6d";

// a colour per platform for its card when no wallpaper is installed
var platform = {
    "recent": ["#3b4252", "#1c2029"],
    "favorites": ["#ff4f6d", "#7a1c33"],
    "gb": ["#8bac0f", "#2f4a10"],
    "gbc": ["#7b3fe4", "#2c1460"],
    "gba": ["#5a3fd0", "#1e1559"],
    "nes": ["#c8102e", "#4a0b14"],
    "snes": ["#6c5ba8", "#2a2148"],
    "n64": ["#1f8f3a", "#0d3b1a"],
    "nds": ["#9aa4b1", "#363c45"],
    "gc": ["#5d4ca8", "#221a4d"],
    "wii": ["#38a8e0", "#0f3b55"],
    "genesis": ["#1d1d1d", "#000000"],
    "megadrive": ["#1d1d1d", "#000000"],
    "master": ["#1d4fa8", "#0b1e45"],
    "gamegear": ["#2b2b2b", "#0b0b0b"],
    "segacd": ["#33373d", "#101215"],
    "saturn": ["#3d4f8a", "#141c38"],
    "dreamcast": ["#f2662b", "#5a1f08"],
    "ngpc": ["#c9a227", "#4a3b0b"],
    "psx": ["#7d8590", "#2a2e33"],
    "ps2": ["#173a8f", "#081536"],
    "psp": ["#2b2b33", "#0c0c10"],
    "psvita": ["#1f5fbf", "#0a224a"],
    "xbox": ["#2e8b2e", "#0d330d"],
    "ports": ["#d98e2b", "#4a2c08"]
};

// carousel order, the way Daijishou groups them; anything else comes after, by name
var order = ["gb", "gbc", "gba", "nes", "snes", "n64", "nds", "gc", "wii",
             "master", "genesis", "megadrive", "gamegear", "segacd", "saturn", "dreamcast",
             "ngpc", "psx", "ps2", "psp", "psvita", "xbox", "ports"];

function rank(shortName) {
    var i = order.indexOf(shortName);
    return i < 0 ? order.length : i;
}

function colours(shortName) {
    return platform[shortName] || ["#3a3f4b", "#16181e"];
}

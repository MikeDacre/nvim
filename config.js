// For more information on customizing Oni,
// check out our wiki page:
// https://github.com/onivim/oni/wiki/Configuration


const activate = oni => {
    console.log("config activated")

    // Input
    //
    // Add input bindings here:
    //
    oni.input.bind("<c-enter>", () => console.log("Control+Enter was pressed"))

    //
    // Or remove the default bindings here by uncommenting the below line:
    //
    // oni.input.unbind("<c-p>")
}

const deactivate = () => {
    console.log("config deactivated")
}

module.exports = {
    activate,
    deactivate,
    //add custom config here, such as

    "ui.colorscheme": "wombatmikemod",
    "autoClosingPairs.enabled": false,
    "editor.quickInfo.delay": 150,

    "oni.useDefaultConfig": false,
    //"oni.bookmarks": ["~/Documents"],
    "oni.loadInitVim": true,
    "editor.fontSize": "16px",
    "editor.fontFamily": "Inconsolata,Menlo",
    "editor.bashgroundOpacity": 0.8,

    // UI customizations
    "ui.animations.enabled": true,
    "ui.fontSmoothing": "auto",
    "statusbar.enabled": false,
    "tabs.mode": 'tabs',

    "experimental.markdownPreview.enabled": true,
}

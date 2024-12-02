module.exports = {
    js2svg: { indent: 2, pretty: true },
    plugins: [
        "removeComments",
        "removeDoctype",
        "removeMetadata",
        "removeEmptyText",
        "mergePaths",
        "removeStyleElement",
        "collapseGroups",
        "removeEmptyContainers",
        "removeEmptyAttrs",
        "removeUnknownsAndDefaults",
        "cleanupIds",
        "cleanupEnableBackground",
        "removeEditorsNSData",
        "removeXMLNS",
        "removeXMLProcInst",
        "removeXlink",
        "removeViewBox"
    ]
}
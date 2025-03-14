module.exports = {
    js2svg: { indent: 2, pretty: true },
    plugins: [
        "removeComments",
        "removeDoctype",
        "removeMetadata",
        "removeEmptyText",
        "removeEditorsNSData",
        //"removeXMLNS",
        "removeXMLProcInst",
        "removeXlink",
        "removeViewBox",
        "removeTitle",
        "removeUselessDefs",
        {
            name: "removeDesc",
            "params": {
                removeAny: true
            }
        },
        "removeStyleElement",
        "removeEmptyContainers",
        "removeEmptyAttrs",
        {
            name: "removeUnknownsAndDefaults",
            params: {
              unknownContent: true,
              unknownAttrs: true,
              defaultAttrs: true,
              defaultMarkupDeclarations: true,
              uselessOverrides: true,
              keepDataAttrs: false,
              keepAriaAttrs: false,
              keepRoleAttr: false
            }
        },
        {
            name: "removeUselessStrokeAndFill",
            params: {
              stroke: true,
              fill: true,
              removeNone: false
            }
        },
        "mergePaths",
        "collapseGroups",
        "cleanupIds",
        "cleanupEnableBackground",
        "convertTransform",
        "moveGroupAttrsToElems",
        "removeOffCanvasPaths",
        "sortDefsChildren",
        {
            name: "removeHiddenElems",
            params: {
              isHidden: true,
              displayNone: true,
              opacity0: true,
              circleR0: true,
              ellipseRX0: true,
              ellipseRY0: true,
              rectWidth0: true,
              rectHeight0: true,
              patternWidth0: true,
              patternHeight0: true,
              imageWidth0: true,
              imageHeight0: true,
              pathEmptyD: true,
              polylineEmptyPoints: true,
              polygonEmptyPoints: true
            }
        }
    ]
}
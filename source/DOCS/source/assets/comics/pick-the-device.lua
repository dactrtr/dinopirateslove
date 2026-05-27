local marginX = -8
local marginY = -8



pickDevice = {
    -- First sequence
    {
        -- Sequence properties
        scrollType = Panels.ScrollType.AUTO,
        direction = Panels.ScrollDirection.NONE,
        backgroundColor = Graphics.kColorWhite,
        advanceControl = Panels.Input.A,
        panels = {
            {
                -- 1st panel
                layers = {
                    {
                        image = "comics/pick-the-device/001",
                        x = marginX,
                        y = marginY
                    }
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 2nd panel
                renderFunction = Utilities.renderLangPanel,
                layers = {
                    {
                        name = "base",
                        image = "comics/pick-the-device/001",
                        x = marginX,
                        y = marginY
                    },
                    {
                        name = "en",
                        image = "comics/pick-the-device/002",
                        x = marginX,
                        y = marginY
                    },
                    {
                        name = "jp",
                        image = "comics/pick-the-device/002jp",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showAdvanceControl = true
            },
            {
                -- 3rd panel
                layers = {
                    {
                        image = "comics/pick-the-device/003",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 4th panel
                layers = {
                    {
                        image = "comics/pick-the-device/003",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/004",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 5th panel
                layers = {
                    {
                        image = "comics/pick-the-device/003",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/004",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/005",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 6th panel
                layers = {
                    {
                        image = "comics/pick-the-device/006",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 7th panel
                layers = {
                    {
                        image = "comics/pick-the-device/007",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 8th panel
                layers = {
                    {
                        image = "comics/pick-the-device/007",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/008",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 9h panel
                layers = {
                    {
                        image = "comics/pick-the-device/007",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/008",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/009",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 10th panel
                layers = {
                    {
                        image = "comics/pick-the-device/007",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/008",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/009",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/010",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 11th panel
                layers = {
                    {
                        image = "comics/pick-the-device/007",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/008",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/009",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/010",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/011",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 12th panel
                layers = {
                    {
                        image = "comics/pick-the-device/012",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 13th panel
                layers = {
                    {
                        image = "comics/pick-the-device/012",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/013",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 14th panel
                layers = {
                    {
                        image = "comics/pick-the-device/012",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/013",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/014",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 15th panel
                layers = {
                    {
                        image = "comics/pick-the-device/012",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/013",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/015",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 16th panel
                layers = {
                    {
                        image = "comics/pick-the-device/016",
                        x = marginX,
                        y = marginY
                    },
                    
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 17th panel
                layers = {
                    {
                        image = "comics/pick-the-device/016",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/017",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 18th panel
                layers = {
                    {
                        image = "comics/pick-the-device/018",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/017",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 19th panel
                layers = {
                    {
                        image = "comics/pick-the-device/018",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/017",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/019",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 20th panel
                layers = {
                    {
                        image = "comics/pick-the-device/018",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/017",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/019",
                        x = marginX,
                        y = marginY
                    },
                    {
                        image = "comics/pick-the-device/020",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
            {
                -- 21th panel
                layers = {
                    {
                        image = "comics/pick-the-device/021",
                        x = marginX,
                        y = marginY
                    },
                },
                advanceControl = Panels.Input.A,
                showControl = true
            },
        }
    }
} 
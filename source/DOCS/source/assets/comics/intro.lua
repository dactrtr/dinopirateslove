intro = {
    -- First sequence
    {
        -- Sequence properties
        scrollType = Panels.ScrollType.AUTO,
        direction = Panels.ScrollDirection.NONE,
        backgroundColor = Graphics.kColorWhite,
        advanceControl = Panels.Input.A,
        frame = {
            margin = 0
        },
       -- borderless = true,
        title = "Intro",
        
        panels = {
            {
                -- First panel
                layers = {
                    {
                        image = "comics/intro/001",
                        x = -8,
                        y = -8
                    }
                },
            },
            {
                -- Second panel
                layers = {
                    {
                        image = "comics/intro/001",
                        x = -8,
                        y = -8
                    },
                    {
                        image = "comics/intro/002",
                        x = -8,
                        y = -8
                    },
                },
               
            },
            {
                -- Third panel
               layers = {
                   {
                       image = "comics/intro/001",
                       x = -8,
                       y = -8
                   },
                   {
                       image = "comics/intro/002",
                       x = -8,
                       y = -8
                   },
                   {
                          image = "comics/intro/003",
                          x = -8,
                          y = -8
                      },
               },
                
            },
            {
                -- Fourth panel
               layers = {
                   {
                       image = "comics/intro/001",
                       x = -8,
                       y = -8
                   },
                   {
                       image = "comics/intro/002",
                       x = -8,
                       y = -8
                   },
                   {
                        image = "comics/intro/003",
                        x = -8,
                        y = -8
                    },
                    {
                        image = "comics/intro/004",
                        x = -8,
                        y = -8
                    },
               },
                
            },
        }
    }
} 
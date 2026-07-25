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
                        x = 0,
                        y = 0
                    }
                },
            },
            {
                -- Second panel
                layers = {
                    {
                        image = "comics/intro/001",
                        x = 0,
                        y = 0
                    },
                    {
                        image = "comics/intro/002",
                        x = 0,
                        y = 0
                    },
                },
               
            },
            {
                -- Third panel
               layers = {
                   {
                       image = "comics/intro/001",
                       x = 0,
                       y = 0
                   },
                   {
                       image = "comics/intro/002",
                       x = 0,
                       y = 0
                   },
                   {
                          image = "comics/intro/003",
                          x = 0,
                          y = 0
                      },
               },
                
            },
            {
                -- Fourth panel
               layers = {
                   {
                       image = "comics/intro/001",
                       x = 0,
                       y = 0
                   },
                   {
                       image = "comics/intro/002",
                       x = 0,
                       y = 0
                   },
                   {
                        image = "comics/intro/003",
                        x = 0,
                        y = 0
                    },
                    {
                        image = "comics/intro/004",
                        x = 0,
                        y = 0
                    },
               },
                
            },
        }
    }
} 
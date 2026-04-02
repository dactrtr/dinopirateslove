	--2
table.insert(levelsLDTK, {
  identifier = "Room_2",
  uniqueIdentifer = "bab17c70-ac70-11f0-997a-85b3d3c5d229",
  neighbourLevels = {
    {
      levelIid = "abdd36b0-ac70-11f0-998c-673887a050e6",
      dir = "<"
    },
    {
      levelIid = "69eb2d80-ac70-11f0-989f-95306126bd74",
      dir = "w"
    },
    {
      levelIid = "bf654080-ac70-11f0-997a-e578ba2da2ac",
      dir = "e"
    },
    {
      levelIid = "cb0db7f0-ac70-11f0-997a-b9923cff9cbf",
      dir = "sw"
    },
    {
      levelIid = "cf8f2160-ac70-11f0-997a-c71a3a3308ed",
      dir = "s"
    },
    {
      levelIid = "d8b90440-ac70-11f0-997a-77d867841568",
      dir = "se"
    }
  },
  customFields = {
    shadow = false,
    light = 0,
    visited = false,
    comic_name = nil,
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 2,
    tile = 2,
    DoorsConnection = {
      "Down",
      "Right"
    },
    play = nil,
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "b3283eb0-ac70-11f0-8539-f3c8ed5b1669",
        x = 200,
        y = 236,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Down",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "b620e540-ac70-11f0-8539-71a575f15bb9",
        x = 396,
        y = 120,
        width = 8,
        height = 48,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Right",
          KeyNumber = nil
        }
      }
    },
    Triggers = {
      {
        id = "Triggers",
        iid = "04803a80-ac70-11f0-ae64-7fad2120052d",
        x = 172,
        y = 100,
        width = 40,
        height = 40,
        customFields = {
          script = "giftFor100",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "0f48b230-ac70-11f0-ae64-49bfdc9ab6ce",
        x = 220,
        y = 92,
        width = 40,
        height = 40,
        customFields = {
          script = "giftFor233",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "7d672b30-ac70-11f0-ae64-79d729daa857",
        x = 308,
        y = 180,
        width = 88,
        height = 88,
        customFields = {
          script = "entranceMess",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "54d22370-d380-11f0-88fd-914d0158f881",
        x = 196,
        y = 140,
        width = 32,
        height = 32,
        customFields = {
          script = "myGift",
          usedTrigger = false,
          type = "Story",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "d86c3bd0-fa90-11f0-88fd-7de014001b21",
        x = 180,
        y = 60,
        width = 96,
        height = 24,
        customFields = {
          script = "whyXmas",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {
            "isTiny:hugeXmas"
          }
        }
      }
    },
    ItemGift = {
      {
        id = "ItemGift",
        iid = "ab0e6080-d380-11f0-88fd-23cdcf2dde52",
        x = 196,
        y = 140,
        width = 32,
        height = 32,
        customFields = {
          type = "itemGift",
          grants = "hasDWatch:true",
          isItem = true
        }
      }
    },
    Xtree1 = {
      {
        id = "Xtree1",
        iid = "0b24fca0-ac70-11f0-985a-61d94463d05b",
        x = 164,
        y = 44,
        width = 32,
        height = 32,
        customFields = {
          type = "xtree-1",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Xtree2 = {
      {
        id = "Xtree2",
        iid = "0cc60270-ac70-11f0-985a-1d1e859d73df",
        x = 196,
        y = 44,
        width = 32,
        height = 32,
        customFields = {
          type = "xtree-2",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Xtree3 = {
      {
        id = "Xtree3",
        iid = "0ec1f980-ac70-11f0-985a-a3051c196f4b",
        x = 164,
        y = 76,
        width = 32,
        height = 32,
        customFields = {
          type = "xtree-3",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Xtree4 = {
      {
        id = "Xtree4",
        iid = "1072ddd0-ac70-11f0-985a-077e223da91c",
        x = 196,
        y = 76,
        width = 32,
        height = 32,
        customFields = {
          type = "xtree-4",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Gifts = {
      {
        id = "Gifts",
        iid = "13ad2140-ac70-11f0-985a-d1b75f9e1484",
        x = 140,
        y = 84,
        width = 32,
        height = 32,
        customFields = {
          type = "gifts",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "Gifts",
        iid = "1693c670-ac70-11f0-985a-51430b780b06",
        x = 220,
        y = 92,
        width = 32,
        height = 32,
        customFields = {
          type = "gifts",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Gift = {
      {
        id = "Gift",
        iid = "1afcecf0-ac70-11f0-985a-01e2a66cb28c",
        x = 172,
        y = 100,
        width = 32,
        height = 32,
        customFields = {
          type = "gift",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Blood2 = {
      {
        id = "Blood2",
        iid = "2652d790-ac70-11f0-985a-25b699999ba6",
        x = 108,
        y = 100,
        width = 32,
        height = 32,
        customFields = {
          type = "blood2",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood2",
        iid = "2929ec60-ac70-11f0-985a-4126f85ddd1f",
        x = 252,
        y = 84,
        width = 32,
        height = 32,
        customFields = {
          type = "blood2",
          nocollider = true,
          destroyed = false
        }
      }
    },
    Blood = {
      {
        id = "Blood",
        iid = "2dcb39e0-ac70-11f0-985a-45f325c18dbd",
        x = 84,
        y = 52,
        width = 32,
        height = 32,
        customFields = {
          type = "blood",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood",
        iid = "2f6c18a0-ac70-11f0-985a-a1f4b58b53d7",
        x = 300,
        y = 60,
        width = 32,
        height = 32,
        customFields = {
          type = "blood",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood",
        iid = "31637bd0-ac70-11f0-985a-7b97c4a1ea96",
        x = 140,
        y = 132,
        width = 32,
        height = 32,
        customFields = {
          type = "blood",
          nocollider = true,
          destroyed = false
        }
      }
    },
    Table = {
      {
        id = "Table",
        iid = "46dec050-ac70-11f0-985a-132726764f8b",
        x = 36,
        y = 100,
        width = 32,
        height = 32,
        customFields = {
          type = "table",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "Table",
        iid = "487d5520-ac70-11f0-985a-cd8cc298fdae",
        x = 356,
        y = 68,
        width = 32,
        height = 32,
        customFields = {
          type = "table",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "Table",
        iid = "6d93cec0-ac70-11f0-ae64-1be5800770cc",
        x = 300,
        y = 172,
        width = 32,
        height = 32,
        customFields = {
          type = "table",
          nocollider = false,
          destroyed = false
        }
      }
    },
    FellTable = {
      {
        id = "FellTable",
        iid = "4abbfa80-ac70-11f0-985a-7319d2beaa22",
        x = 324,
        y = 92,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "FellTable",
        iid = "4c9c0520-ac70-11f0-985a-e99f3d0bf46f",
        x = 36,
        y = 180,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "FellTable",
        iid = "4db452f0-ac70-11f0-985a-cfe8262e92fe",
        x = 364,
        y = 204,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "FellTable",
        iid = "4fdbc6d0-ac70-11f0-985a-a5601f3ccd47",
        x = 92,
        y = 204,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "FellTable",
        iid = "6ed6af00-ac70-11f0-ae64-f7bb28f9916d",
        x = 340,
        y = 196,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Fellchair = {
      {
        id = "Fellchair",
        iid = "518e7fe0-ac70-11f0-985a-93391a2015c0",
        x = 316,
        y = 204,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "fellchair"
        }
      },
      {
        id = "Fellchair",
        iid = "53f63110-ac70-11f0-985a-d350bb30470b",
        x = 348,
        y = 164,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "fellchair"
        }
      },
      {
        id = "Fellchair",
        iid = "54ba1d50-ac70-11f0-985a-27fb7aa5ea82",
        x = 252,
        y = 188,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "fellchair"
        }
      },
      {
        id = "Fellchair",
        iid = "722d2d00-ac70-11f0-ae64-d9f2ef5111fe",
        x = 324,
        y = 164,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "fellchair"
        }
      }
    },
    Chair = {
      {
        id = "Chair",
        iid = "7626a1c0-ac70-11f0-ae64-a5338e4e288e",
        x = 364,
        y = 164,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "chair"
        }
      }
    }
  }
})
	--3
table.insert(levelsLDTK, {
  identifier = "Room_3",
  uniqueIdentifer = "bf654080-ac70-11f0-997a-e578ba2da2ac",
  neighbourLevels = {
    {
      levelIid = "2dc4bd30-ac70-11f0-998c-2ba6c3750080",
      dir = "<"
    },
    {
      levelIid = "bab17c70-ac70-11f0-997a-85b3d3c5d229",
      dir = "w"
    },
    {
      levelIid = "c118e3f0-ac70-11f0-997a-a35ec59b96eb",
      dir = "e"
    },
    {
      levelIid = "cf8f2160-ac70-11f0-997a-c71a3a3308ed",
      dir = "sw"
    },
    {
      levelIid = "d8b90440-ac70-11f0-997a-77d867841568",
      dir = "s"
    },
    {
      levelIid = "dab87dc0-ac70-11f0-997a-63497867517d",
      dir = "se"
    }
  },
  customFields = {
    shadow = false,
    light = 0,
    visited = false,
    comic_name = nil,
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 3,
    tile = 3,
    DoorsConnection = {
      "Left",
      "Down"
    },
    play = nil,
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "bb73a870-ac70-11f0-8539-03f7dfb4cdc8",
        x = 4,
        y = 120,
        width = 8,
        height = 48,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Left",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "bf724d50-ac70-11f0-8539-137cb38eca29",
        x = 200,
        y = 236,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Down",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "e1699320-d380-11f0-a276-052d46aa38e7",
        x = 344,
        y = 236,
        width = 16,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Down",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "49e32660-fa90-11f0-9f0d-3381c910a0b4",
        x = 88,
        y = 236,
        width = 16,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Down",
          KeyNumber = nil
        }
      }
    },
    Triggers = {
      {
        id = "Triggers",
        iid = "c9660040-ac70-11f0-ae64-094e17987f94",
        x = 100,
        y = 60,
        width = 56,
        height = 32,
        customFields = {
          script = "microwaveBurn",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "f2317670-ac70-11f0-ae64-133829c2c353",
        x = 244,
        y = 108,
        width = 32,
        height = 32,
        customFields = {
          script = "kitchenWeapons",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {
            "isTiny:tinyKnife"
          }
        }
      },
      {
        id = "Triggers",
        iid = "3a47bf50-ac70-11f0-ae64-474c236a6fd7",
        x = 332,
        y = 100,
        width = 56,
        height = 48,
        customFields = {
          script = "inneficientCutting",
          usedTrigger = false,
          type = "Story",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "a059dac0-ac70-11f0-ae64-f1ee9dff56d1",
        x = 44,
        y = 196,
        width = 48,
        height = 40,
        customFields = {
          script = "justBoxes",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "26163fe0-ac70-11f0-8398-53067febe16c",
        x = 196,
        y = 204,
        width = 96,
        height = 40,
        customFields = {
          script = "notnormalBrocoli",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      }
    },
    FellTable = {
      {
        id = "FellTable",
        iid = "bf46c0e0-ac70-11f0-ae64-597ec6fe672b",
        x = 36,
        y = 60,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "FellTable",
        iid = "ffc9fb50-d380-11f0-a276-0f85237af89c",
        x = 276,
        y = 164,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Blood = {
      {
        id = "Blood",
        iid = "c2442260-ac70-11f0-ae64-a5f7b1f853f5",
        x = 68,
        y = 60,
        width = 32,
        height = 32,
        customFields = {
          type = "blood",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood",
        iid = "01ef6b90-ac70-11f0-ae64-292bbea86898",
        x = 324,
        y = 132,
        width = 32,
        height = 32,
        customFields = {
          type = "blood",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood",
        iid = "0601e690-ac70-11f0-ae64-8778a1292c62",
        x = 348,
        y = 60,
        width = 32,
        height = 32,
        customFields = {
          type = "blood",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood",
        iid = "0e256780-ac70-11f0-8398-fb5fdad9133f",
        x = 196,
        y = 212,
        width = 32,
        height = 32,
        customFields = {
          type = "blood",
          nocollider = true,
          destroyed = false
        }
      }
    },
    Microwave = {
      {
        id = "Microwave",
        iid = "c7345330-ac70-11f0-ae64-3f2b938fe6d4",
        x = 100,
        y = 60,
        width = 32,
        height = 32,
        customFields = {
          type = "microwave",
          nocollider = false,
          destroyed = false
        }
      }
    },
    DeadRat = {
      {
        id = "DeadRat",
        iid = "f4bef490-ac70-11f0-ae64-d96e07439f33",
        x = 332,
        y = 100,
        width = 32,
        height = 32,
        customFields = {
          type = "deadrat",
          nocollider = false,
          destroyed = false
        }
      }
    },
    KnifeKettle = {
      {
        id = "KnifeKettle",
        iid = "ed4c9040-ac70-11f0-ae64-57af9b96ac8a",
        x = 244,
        y = 108,
        width = 32,
        height = 32,
        customFields = {
          type = "knifeKettle",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Box = {
      {
        id = "Box",
        iid = "9d998240-ac70-11f0-ae64-fffc401f9f95",
        x = 44,
        y = 196,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "box"
        }
      }
    },
    Fridge2 = {
      {
        id = "Fridge2",
        iid = "35301230-ac70-11f0-8398-8fcdc90b8969",
        x = 188,
        y = 68,
        width = 32,
        height = 32,
        customFields = {
          type = "fridge2",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Fridge1 = {
      {
        id = "Fridge1",
        iid = "368c94f0-ac70-11f0-8398-27c802cf0097",
        x = 188,
        y = 36,
        width = 32,
        height = 32,
        customFields = {
          type = "fridge1",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Smalltable = {
      {
        id = "Smalltable",
        iid = "39a100e0-ac70-11f0-8398-058ecccabc84",
        x = 156,
        y = 60,
        width = 32,
        height = 32,
        customFields = {
          type = "smallTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "Smalltable",
        iid = "d0f28ea0-d380-11f0-a276-170abcc70553",
        x = 276,
        y = 188,
        width = 32,
        height = 32,
        customFields = {
          type = "smallTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "Smalltable",
        iid = "d4288c50-d380-11f0-a276-9bdf43235b7f",
        x = 276,
        y = 124,
        width = 32,
        height = 32,
        customFields = {
          type = "smallTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "Smalltable",
        iid = "d53679e0-d380-11f0-a276-8f2b37a9f3ee",
        x = 284,
        y = 212,
        width = 32,
        height = 32,
        customFields = {
          type = "smallTable",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "Smalltable",
        iid = "d78991a0-d380-11f0-a276-f7b032b235ae",
        x = 268,
        y = 52,
        width = 32,
        height = 32,
        customFields = {
          type = "smallTable",
          nocollider = false,
          destroyed = false
        }
      }
    },
    KitchenStorage = {
      {
        id = "KitchenStorage",
        iid = "3d5fb690-ac70-11f0-8398-89d1822135c2",
        x = 220,
        y = 60,
        width = 32,
        height = 32,
        customFields = {
          type = "kitchenStorage",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "KitchenStorage",
        iid = "421f6180-ac70-11f0-8398-3187f4a538f2",
        x = 308,
        y = 52,
        width = 32,
        height = 32,
        customFields = {
          type = "kitchenStorage",
          nocollider = false,
          destroyed = false
        }
      },
      {
        id = "KitchenStorage",
        iid = "f90bc140-d380-11f0-a276-d3e851faf0a1",
        x = 276,
        y = 100,
        width = 32,
        height = 32,
        customFields = {
          type = "kitchenStorage",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Blood2 = {
      {
        id = "Blood2",
        iid = "12214d40-ac70-11f0-8398-31a430f47a22",
        x = 228,
        y = 196,
        width = 32,
        height = 32,
        customFields = {
          type = "blood2",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood2",
        iid = "1975acd0-ac70-11f0-8398-9b842ef570b6",
        x = 164,
        y = 196,
        width = 32,
        height = 32,
        customFields = {
          type = "blood2",
          nocollider = true,
          destroyed = false
        }
      },
      {
        id = "Blood2",
        iid = "1f4d3060-ac70-11f0-8398-2ff5d145c0a9",
        x = 204,
        y = 196,
        width = 32,
        height = 32,
        customFields = {
          type = "blood2",
          nocollider = true,
          destroyed = false
        }
      }
    }
  }
})
	--7
table.insert(levelsLDTK, {
  identifier = "Room_7",
  uniqueIdentifer = "cf8f2160-ac70-11f0-997a-c71a3a3308ed",
  neighbourLevels = {
    {
      levelIid = "3b081ff0-ac70-11f0-998c-67e6b510262c",
      dir = "<"
    },
    {
      levelIid = "69eb2d80-ac70-11f0-989f-95306126bd74",
      dir = "nw"
    },
    {
      levelIid = "bab17c70-ac70-11f0-997a-85b3d3c5d229",
      dir = "n"
    },
    {
      levelIid = "bf654080-ac70-11f0-997a-e578ba2da2ac",
      dir = "ne"
    },
    {
      levelIid = "cb0db7f0-ac70-11f0-997a-b9923cff9cbf",
      dir = "w"
    },
    {
      levelIid = "d8b90440-ac70-11f0-997a-77d867841568",
      dir = "e"
    },
    {
      levelIid = "68b425c0-ac70-11f0-997a-7732cd72a5cc",
      dir = "sw"
    },
    {
      levelIid = "6cc9d510-ac70-11f0-997a-191299f9209c",
      dir = "s"
    },
    {
      levelIid = "715b4410-ac70-11f0-997a-156adb22b715",
      dir = "se"
    }
  },
  customFields = {
    shadow = false,
    light = 0,
    visited = false,
    comic_name = "intro",
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 7,
    tile = 7,
    DoorsConnection = {
      "Top"
    },
    play = "Enter",
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "ad890930-ac70-11f0-8539-b927b406cff9",
        x = 200,
        y = 4,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Top",
          KeyNumber = nil
        }
      }
    },
    Triggers = {
      {
        id = "Triggers",
        iid = "c7870a30-ac70-11f0-998c-2944db77c3b4",
        x = 204,
        y = 132,
        width = 88,
        height = 40,
        customFields = {
          script = "wakeup",
          usedTrigger = false,
          type = "Story",
          mapPercent = 0,
          conditionalScripts = {
            nil
          }
        }
      },
      {
        id = "Triggers",
        iid = "cc4b57d0-ac70-11f0-ae64-f1a43cc2526b",
        x = 292,
        y = 140,
        width = 40,
        height = 40,
        customFields = {
          script = "someTrash",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "04397810-ac70-11f0-ae64-891aa0cc0d18",
        x = 92,
        y = 108,
        width = 48,
        height = 40,
        customFields = {
          script = "justBoxes",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      }
    }
  }
})
	--8
table.insert(levelsLDTK, {
  identifier = "Room_8",
  uniqueIdentifer = "d8b90440-ac70-11f0-997a-77d867841568",
  neighbourLevels = {
    {
      levelIid = "3d752854-ac70-11f0-998c-5dddbfac239d",
      dir = "<"
    },
    {
      levelIid = "bab17c70-ac70-11f0-997a-85b3d3c5d229",
      dir = "nw"
    },
    {
      levelIid = "bf654080-ac70-11f0-997a-e578ba2da2ac",
      dir = "n"
    },
    {
      levelIid = "c118e3f0-ac70-11f0-997a-a35ec59b96eb",
      dir = "ne"
    },
    {
      levelIid = "cf8f2160-ac70-11f0-997a-c71a3a3308ed",
      dir = "w"
    },
    {
      levelIid = "dab87dc0-ac70-11f0-997a-63497867517d",
      dir = "e"
    },
    {
      levelIid = "6cc9d510-ac70-11f0-997a-191299f9209c",
      dir = "sw"
    },
    {
      levelIid = "715b4410-ac70-11f0-997a-156adb22b715",
      dir = "s"
    },
    {
      levelIid = "6de95960-ac70-11f0-998c-e3108c5f25c9",
      dir = "se"
    }
  },
  customFields = {
    shadow = false,
    light = 0.5,
    visited = false,
    comic_name = "pick-the-device",
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 8,
    tile = 8,
    DoorsConnection = {
      "Top",
      "Down",
      "Right"
    },
    play = "Cutscene",
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "07b70f50-ac70-11f0-8539-35ff95bfdbdf",
        x = 200,
        y = 236,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Down",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "c5a75a30-ac70-11f0-8539-6130c4fb1bfd",
        x = 200,
        y = 4,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Top",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "c25a9ea0-d380-11f0-a276-5f29b940eae6",
        x = 344,
        y = 4,
        width = 16,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Top",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "3bc2f830-fa90-11f0-9f0d-dd4b46089fc2",
        x = 88,
        y = 4,
        width = 16,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Top",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "1e6d98b0-fa90-11f0-9039-3be58b1a7a15",
        x = 396,
        y = 128,
        width = 8,
        height = 32,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Right",
          KeyNumber = nil
        }
      }
    },
    Triggers = {
      {
        id = "Triggers",
        iid = "1966a940-fa90-11f0-bb17-4bab457c7082",
        x = 214,
        y = 116,
        width = 32,
        height = 32,
        customFields = {
          script = "pick-the-device",
          usedTrigger = false,
          type = "Cutscene",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "ac81c810-fa90-11f0-bb17-65c231745807",
        x = 260,
        y = 196,
        width = 24,
        height = 48,
        customFields = {
          script = "reachComputer",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      }
    },
    PcBase2 = {
      {
        id = "PcBase2",
        iid = "2438d1a0-fa90-11f0-bb17-470acac3228b",
        x = 364,
        y = 204,
        width = 32,
        height = 32,
        customFields = {
          type = "pcBase2",
          nocollider = false,
          destroyed = false
        }
      }
    },
    PcSiriSad = {
      {
        id = "PcSiriSad",
        iid = "2832e2a0-fa90-11f0-bb17-5defe973a785",
        x = 364,
        y = 172,
        width = 32,
        height = 32,
        customFields = {
          type = "pcSiriSad",
          nocollider = false,
          destroyed = false
        }
      }
    },
    FellTable = {
      {
        id = "FellTable",
        iid = "4afbc310-fa90-11f0-bb17-9f9aae871b88",
        x = 164,
        y = 76,
        width = 32,
        height = 32,
        customFields = {
          type = "fellTable",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Trash = {
      {
        id = "Trash",
        iid = "4eb548a0-fa90-11f0-bb17-ddd5be806714",
        x = 164,
        y = 164,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "trash"
        }
      }
    },
    Box = {
      {
        id = "Box",
        iid = "52d24af0-fa90-11f0-bb17-b19454514619",
        x = 260,
        y = 52,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "box"
        }
      },
      {
        id = "Box",
        iid = "e1dcbc80-fa90-11f0-bb17-abae770f562b",
        x = 276,
        y = 180,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "box"
        }
      },
      {
        id = "Box",
        iid = "e46f9c60-fa90-11f0-bb17-e702b3a82c8e",
        x = 276,
        y = 212,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "box"
        }
      }
    },
    TubeExit = {
      {
        id = "TubeExit",
        iid = "9fbc56a0-21a0-11f1-9039-37e7cd6f0338",
        x = 36,
        y = 204,
        width = 32,
        height = 32,
        customFields = {
          type = "TubeExit",
          nocollider = false,
          destroyed = false
        }
      }
    }
  }
})
	--9
table.insert(levelsLDTK, {
  identifier = "Room_9",
  uniqueIdentifer = "dab87dc0-ac70-11f0-997a-63497867517d",
  neighbourLevels = {
    {
      levelIid = "40386700-ac70-11f0-998c-e53e1b32800c",
      dir = "<"
    },
    {
      levelIid = "bf654080-ac70-11f0-997a-e578ba2da2ac",
      dir = "nw"
    },
    {
      levelIid = "c118e3f0-ac70-11f0-997a-a35ec59b96eb",
      dir = "n"
    },
    {
      levelIid = "c2b4e0b0-ac70-11f0-997a-09fdc7fc6323",
      dir = "ne"
    },
    {
      levelIid = "d8b90440-ac70-11f0-997a-77d867841568",
      dir = "w"
    },
    {
      levelIid = "672c4d40-ac70-11f0-997a-7b0342bedabe",
      dir = "e"
    },
    {
      levelIid = "715b4410-ac70-11f0-997a-156adb22b715",
      dir = "sw"
    },
    {
      levelIid = "6de95960-ac70-11f0-998c-e3108c5f25c9",
      dir = "s"
    },
    {
      levelIid = "708f7320-ac70-11f0-998c-737ddc0c343a",
      dir = "se"
    }
  },
  customFields = {
    shadow = false,
    light = 0,
    visited = false,
    comic_name = nil,
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 9,
    tile = 9,
    DoorsConnection = {
      "Top",
      "Down",
      "Left"
    },
    play = nil,
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "f1da76b0-fa90-11f0-9039-7f762bb19d4f",
        x = 200,
        y = 235,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Down",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "104fb470-fa90-11f0-9039-f5ad4ff8081c",
        x = 4,
        y = 128,
        width = 8,
        height = 32,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Left",
          KeyNumber = nil
        }
      }
    },
    CrewMember = {
      {
        id = "CrewMember",
        iid = "0c11a640-fa90-11f0-9f0d-c9ca42f46487",
        x = 124,
        y = 76,
        width = 48,
        height = 48,
        customFields = {
          isTaken = false,
          crewID = "CM001"
        }
      }
    },
    Boots = {
      {
        id = "Boots",
        iid = "80778710-21a0-11f1-9039-454013ab8924",
        x = 220,
        y = 84,
        width = 32,
        height = 32,
        customFields = {
          type = "boots",
          isItem = true
        }
      }
    },
    Minifier = {
      {
        id = "Minifier",
        iid = "21887b30-fa90-11f0-9a41-eb80f350135c",
        x = 364,
        y = 204,
        width = 32,
        height = 32,
        customFields = {
          type = "minifier",
          nocollider = false,
          destroyed = false
        }
      }
    },
    Box = {
      {
        id = "Box",
        iid = "272ae500-fa90-11f0-9a41-890edd14f601",
        x = 244,
        y = 172,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "box"
        }
      },
      {
        id = "Box",
        iid = "27cf6260-fa90-11f0-9a41-b3f1e08f1341",
        x = 204,
        y = 172,
        width = 32,
        height = 32,
        customFields = {
          nocollider = false,
          destroyed = false,
          type = "box"
        }
      }
    }
  }
})
	--12
table.insert(levelsLDTK, {
  identifier = "Room_12",
  uniqueIdentifer = "6cc9d510-ac70-11f0-997a-191299f9209c",
  neighbourLevels = {
    {
      levelIid = "4a0bd050-ac70-11f0-998c-b14d359446e6",
      dir = "<"
    },
    {
      levelIid = "cb0db7f0-ac70-11f0-997a-b9923cff9cbf",
      dir = "nw"
    },
    {
      levelIid = "cf8f2160-ac70-11f0-997a-c71a3a3308ed",
      dir = "n"
    },
    {
      levelIid = "d8b90440-ac70-11f0-997a-77d867841568",
      dir = "ne"
    },
    {
      levelIid = "68b425c0-ac70-11f0-997a-7732cd72a5cc",
      dir = "w"
    },
    {
      levelIid = "715b4410-ac70-11f0-997a-156adb22b715",
      dir = "e"
    }
  },
  customFields = {
    shadow = false,
    light = 0,
    visited = false,
    comic_name = nil,
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 12,
    tile = 12,
    DoorsConnection = {
      "Left",
      "Right",
      "Lower"
    },
    play = nil,
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "c6e3d930-ac70-11f0-8539-e78eb22c7faf",
        x = 396,
        y = 120,
        width = 8,
        height = 48,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Right",
          KeyNumber = nil
        }
      }
    },
    Triggers = {
      {
        id = "Triggers",
        iid = "91a372e0-21a0-11f1-9039-ffb9ad47dba6",
        x = 360,
        y = 60,
        width = 48,
        height = 16,
        customFields = {
          script = "tinyfier",
          usedTrigger = false,
          type = "Story",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "ff2dc230-21a0-11f1-9039-03e34eda3ccc",
        x = 56,
        y = 100,
        width = 80,
        height = 8,
        customFields = {
          script = "abigJump",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "e5975f10-21a0-11f1-9039-77e3f5c70270",
        x = 340,
        y = 140,
        width = 8,
        height = 40,
        customFields = {
          script = "smallSpaces",
          usedTrigger = false,
          type = "Search",
          mapPercent = 0,
          conditionalScripts = {
            "isTiny:smallSpacesTiny"
          }
        }
      }
    },
    Plunger = {
      {
        id = "Plunger",
        iid = "f84981f0-fa90-11f0-8164-312164d448cc",
        x = 84,
        y = 180,
        width = 32,
        height = 32,
        customFields = {
          type = "plunger",
          isItem = true
        }
      }
    },
    Minifier = {
      {
        id = "Minifier",
        iid = "cef907d0-fa90-11f0-8164-09f23df37bd8",
        x = 356,
        y = 28,
        width = 32,
        height = 32,
        customFields = {
          type = "minifier",
          nocollider = false,
          destroyed = false
        }
      }
    }
  }
})
	--13
table.insert(levelsLDTK, {
  identifier = "Room_13",
  uniqueIdentifer = "715b4410-ac70-11f0-997a-156adb22b715",
  neighbourLevels = {
    {
      levelIid = "4cf534a4-ac70-11f0-998c-6712312c62dc",
      dir = "<"
    },
    {
      levelIid = "cf8f2160-ac70-11f0-997a-c71a3a3308ed",
      dir = "nw"
    },
    {
      levelIid = "d8b90440-ac70-11f0-997a-77d867841568",
      dir = "n"
    },
    {
      levelIid = "dab87dc0-ac70-11f0-997a-63497867517d",
      dir = "ne"
    },
    {
      levelIid = "6cc9d510-ac70-11f0-997a-191299f9209c",
      dir = "w"
    },
    {
      levelIid = "6de95960-ac70-11f0-998c-e3108c5f25c9",
      dir = "e"
    }
  },
  customFields = {
    shadow = true,
    light = 0.7,
    visited = false,
    comic_name = nil,
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 13,
    tile = 13,
    DoorsConnection = {
      "Top",
      "Left",
      "Right"
    },
    play = nil,
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "e35e4010-ac70-11f0-8539-cfa071292c9d",
        x = 4,
        y = 120,
        width = 8,
        height = 48,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Left",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "f2cac460-ac70-11f0-8539-f32c05a0c6fe",
        x = 200,
        y = 4,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Top",
          KeyNumber = nil
        }
      },
      {
        id = "Doors",
        iid = "5b6513e0-fa90-11f0-b965-f9db40bfdb74",
        x = 396,
        y = 176,
        width = 8,
        height = 32,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Right",
          KeyNumber = nil
        }
      }
    },
    Triggers = {
      {
        id = "Triggers",
        iid = "f5c64900-fa90-11f0-bb17-3998f48db633",
        x = 268,
        y = 36,
        width = 24,
        height = 56,
        customFields = {
          script = "secondCall",
          usedTrigger = false,
          type = "Story",
          mapPercent = 0,
          conditionalScripts = {}
        }
      },
      {
        id = "Triggers",
        iid = "e3ff23f0-21a0-11f1-9039-21f5d6ff2f4a",
        x = 60,
        y = 52,
        width = 32,
        height = 32,
        customFields = {
          script = "aLamp",
          usedTrigger = false,
          type = "Story",
          mapPercent = 0,
          conditionalScripts = {}
        }
      }
    },
    Lamp = {
      {
        id = "Lamp",
        iid = "e0de0dd0-21a0-11f1-9039-3d34a18fc4f7",
        x = 60,
        y = 52,
        width = 32,
        height = 32,
        customFields = {
          type = "lamp",
          isItem = true
        }
      }
    },
    Brocorat = {
      {
        id = "Brocorat",
        iid = "241dcb00-21a0-11f1-a37c-178142f6ba93",
        x = 324,
        y = 36,
        width = 32,
        height = 32,
        customFields = {
          speed = 0.5,
          dead = false
        }
      }
    }
  }
})
	--14
table.insert(levelsLDTK, {
  identifier = "Room_14",
  uniqueIdentifer = "6de95960-ac70-11f0-998c-e3108c5f25c9",
  neighbourLevels = {
    {
      levelIid = "50a125a0-ac70-11f0-998c-f3b70b95a9ac",
      dir = "<"
    },
    {
      levelIid = "d8b90440-ac70-11f0-997a-77d867841568",
      dir = "nw"
    },
    {
      levelIid = "dab87dc0-ac70-11f0-997a-63497867517d",
      dir = "n"
    },
    {
      levelIid = "672c4d40-ac70-11f0-997a-7b0342bedabe",
      dir = "ne"
    },
    {
      levelIid = "715b4410-ac70-11f0-997a-156adb22b715",
      dir = "w"
    },
    {
      levelIid = "708f7320-ac70-11f0-998c-737ddc0c343a",
      dir = "e"
    }
  },
  customFields = {
    shadow = false,
    light = 0,
    visited = false,
    comic_name = nil,
    comic_wasPlayed = false,
    level = 4,
    roomNumber = 14,
    tile = 14,
    DoorsConnection = {
      "Top",
      "Right"
    },
    play = nil,
    hasForeground = true
  },
  entities = {
    Doors = {
      {
        id = "Doors",
        iid = "e9b65690-ac70-11f0-8539-3392c72a1b66",
        x = 4,
        y = 176,
        width = 8,
        height = 32,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Left",
          KeyNumber = 1
        }
      },
      {
        id = "Doors",
        iid = "6f73a900-fa90-11f0-b965-0bc3730f853d",
        x = 200,
        y = 4,
        width = 48,
        height = 8,
        customFields = {
          NeedsKey = false,
          DoorsConnection = "Top",
          KeyNumber = nil
        }
      }
    }
  }
})
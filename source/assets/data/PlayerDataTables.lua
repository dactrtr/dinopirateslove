PlayerData = {
	x = 200,
	y = 200, 
	speed = 1.7,
	battery = 0, 
	sanity = 100,
	calories = 100, -- top 500
	steps = 0,
	totalSteps = 1000,
	sanityCounter = 0, -- top 100
	hasKey = false,
	hasLamp = false,
	hasRadio = true,
	hasNotes = true,
	hasBoots = false,
	hasBag = false,
	hasHonk = false,
	hasTools = false,
	canDance = false,
	activeItem = 1,
	sonarActive = false,
	storyCounter = 0,
	isActive = true, -- Changed to true so enemies can chase player
	isTalking = false,
	isCutscene = false,
	isFocused = false,
	isCharging = false,
	isEquiping = false,
	floor = 1,
	room = 1,
	isGaming = false,
	isDancing = false,
	amountDances = 0,
	isInDarkness = false,
	direction = "idle",
	lastRoom = nil,
	actualLevel = nil,
	actualRoom = nil,
	actualTilemap = nil,
	saveLevel= nil,
	playerSpawn ={
		x = 200,
		y = 200,
	},
	playerExit ={
		x = nil,
		y = nil,
	},
	lastEnemyTouched ={
		type = nil,
		id = nil,
		x = nil,
		y = nil
	},
	items={
		
	},
	EnemiesData ={
		powerLevel = 1, -- max 20
		sightRadius = 150, -- min 50, increased for better gameplay
		isEvolved = false,
	},
	CrewMemberData ={
		amountTaken = 0
	}
}

-- Enemy movement speeds (similar to player speed of 100)
EnemyData = {
	brocoratSpeed = 80, -- Slightly slower than player
	bosscolliSpeed = 60,
	crewmemberSpeed = 70
}

PlayerDataOriginal = {
	x = 200,
	y = 200, 
	speed = 1.7,
	battery = 0, 
	sanity = 100,
	calories = 100, -- top 500
	steps = 0,
	totalSteps = 0,
	sanityCounter = 0, -- top 100
	hasKey = false,
	hasLamp = false,
	hasRadio = true,
	hasNotes = true,
	hasBoots = false,
	hasBag = false,
	hasHonk = false,
	hasTools = false,
	canDance = false,
	activeItem = 1,
	sonarActive = false,
	storyCounter = 0,
	isActive = false,
	isTalking = false,
	isCutscene = false,
	isFocused = false,
	isCharging = false,
	isEquiping = false,
	floor = 1,
	room = 1,
	isGaming = false,
	isDancing = false,
	amountDances = 0,
	isInDarkness = false,
	direction = "idle",
	lastRoom = nil,
	actualLevel = nil,
	actualRoom = nil,
	actualTilemap = nil,
	saveLevel= nil,
	playerSpawn ={
		x = 200,
		y = 200,
	},
	playerExit ={
		x = nil,
		y = nil,
	},
	lastEnemyTouched ={
		type = nil,
		id = nil,
		x = nil,
		y = nil
	},
	items={
		
	},
	EnemiesData ={
		powerLevel = 1, -- max 20
		sightRadius = 50, -- min 50
		isEvolved = false,
	},
	CrewMemberData ={
		amountTaken = 0
	}
}
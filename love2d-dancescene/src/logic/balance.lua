-- src/logic/balance.lua
-- Pure balance-position logic extracted for testability.
-- DanceScene requires this module and delegates all balance math to it.
Balance = {}

Balance.A_BUTTON_DELTA    =  5
Balance.WRONG_PRESS_DELTA = -5
Balance.MISS_DELTA        = -0.3
Balance.MISS_GRACE_FRAMES =  5

function Balance.applyABHit(pos)
    return pos + Balance.A_BUTTON_DELTA
end

function Balance.applyArrowHit(pos, accuracy)
    return pos + accuracy
end

function Balance.applyWrongPress(pos)
    return pos + Balance.WRONG_PRESS_DELTA
end

-- Called every frame a button is in the zone with no input.
-- `accuracyFrames` is the miss-streak counter (resets to 0 on any zone collision).
function Balance.applyMissPenalty(pos, accuracyFrames)
    if accuracyFrames > Balance.MISS_GRACE_FRAMES then
        return pos + Balance.MISS_DELTA
    end
    return pos
end

function Balance.clamp(pos, maxOffset)
    return math.max(-maxOffset, math.min(maxOffset, pos))
end

function Balance.isWin(pos, maxOffset)  return pos >= maxOffset  end
function Balance.isLose(pos, maxOffset) return pos <= -maxOffset end

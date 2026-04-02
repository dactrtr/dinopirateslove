-- utilities/balance.lua
-- Pure balance-position logic. No love2d or PlayerData dependencies.
Balance = {}

Balance.A_BUTTON_DELTA    =  5
Balance.WRONG_PRESS_DELTA = -5
Balance.MISS_DELTA        = -0.3
Balance.MISS_GRACE_FRAMES =  5

function Balance.applyABHit(pos)      return pos + Balance.A_BUTTON_DELTA    end
function Balance.applyArrowHit(pos, accuracy) return pos + accuracy           end
function Balance.applyWrongPress(pos) return pos + Balance.WRONG_PRESS_DELTA  end

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

package school.pict.backend

import kotlinx.serialization.json.JsonObject
import java.time.Instant
import java.util.concurrent.atomic.AtomicInteger

class GameStore {
    private var round: Round = Scenario.defaultRound(status = RoundStatus.IDLE)
    private val eventLog = mutableListOf<GameEvent>()
    private val eventCounter = AtomicInteger(0)

    @Synchronized
    fun snapshot(): Round = round

    @Synchronized
    fun replace(nextRound: Round) {
        round = nextRound
    }

    @Synchronized
    fun append(type: String, turnNumber: Int, actor: ActorId?, payload: JsonObject): GameEvent {
        val event = GameEvent(
            id = "event-${eventCounter.incrementAndGet()}",
            roundId = round.id,
            turnNumber = turnNumber,
            type = type,
            timestamp = Instant.now().toString(),
            actor = actor?.wireName(),
            payload = payload
        )
        eventLog += event
        return event
    }

    @Synchronized
    fun events(): List<GameEvent> = eventLog.toList()

    @Synchronized
    fun clearEvents() {
        eventLog.clear()
        eventCounter.set(0)
    }
}

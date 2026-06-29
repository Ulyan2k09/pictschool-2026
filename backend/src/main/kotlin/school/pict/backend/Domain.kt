package school.pict.backend

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

@Serializable
data class Round(
    val id: String,
    val status: RoundStatus,
    val activeActor: ActorId,
    val turnNumber: Int,
    val moveLimitPerTurn: Int,
    val ducksTotal: Int,
    val ducksLeft: Int,
    val score: Score,
    val field: Field,
    val actors: Map<ActorId, ActorState>
)

@Serializable
enum class RoundStatus {
    @SerialName("idle")
    IDLE,

    @SerialName("running")
    RUNNING,

    @SerialName("completed")
    COMPLETED,

    @SerialName("failed")
    FAILED
}

@Serializable
enum class ActorId {
    @SerialName("robot")
    ROBOT,

    @SerialName("agent")
    AGENT;

    fun other(): ActorId = if (this == ROBOT) AGENT else ROBOT
    fun wireName(): String = name.lowercase()

    companion object {
        fun fromWire(value: String): ActorId? = entries.firstOrNull { it.name.equals(value, ignoreCase = true) }
    }
}

@Serializable
data class Score(val robot: Int, val agent: Int)

@Serializable
data class Field(
    val width: Int,
    val height: Int,
    val obstacles: List<Obstacle>,
    val ducks: List<Duck>
)

@Serializable
data class Position(val x: Int, val y: Int)

@Serializable
data class Obstacle(val id: String, val position: Position)

@Serializable
data class Duck(val id: String, val position: Position, val collectedBy: String? = null)

@Serializable
data class ActorState(
    val id: ActorId,
    val position: Position,
    val direction: Direction,
    val collectedDucks: Int,
    val lastError: String?
)

@Serializable
enum class Direction {
    @SerialName("N")
    N,

    @SerialName("E")
    E,

    @SerialName("S")
    S,

    @SerialName("W")
    W;

    fun left(): Direction = when (this) {
        N -> W
        W -> S
        S -> E
        E -> N
    }

    fun right(): Direction = when (this) {
        N -> E
        E -> S
        S -> W
        W -> N
    }
}

@Serializable
data class GameEvent(
    val id: String,
    val roundId: String,
    val turnNumber: Int,
    val type: String,
    val timestamp: String,
    val actor: String?,
    val payload: JsonObject
)

fun RoundStatus.wireName(): String = name.lowercase()

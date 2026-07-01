package school.pict.backend

import kotlinx.serialization.Serializable

@Serializable
data class SimulationCommandRequest(
    val actor: String,
    val commands: List<Int>,
    val round: Round
)

@Serializable
data class SimulationCommandResult(
    val ok: Boolean,
    val actor: String,
    val finalPosition: Position? = null,
    val finalDirection: Direction? = null,
    val ducksCollected: List<String> = emptyList(),
    val error: String? = null
)

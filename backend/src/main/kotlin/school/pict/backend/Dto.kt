package school.pict.backend

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

@Serializable
data class StartRoundRequest(val scenarioId: String? = "default")

@Serializable
data class TurnCommandRequest(val actor: String, val commands: List<Int>)

@Serializable
data class RoundResponse(val round: Round)

@Serializable
data class StartRoundResponse(val roundId: String, val status: String, val activeActor: String)

@Serializable
data class TurnAcceptedResponse(val accepted: Boolean, val eventId: String, val forwardedAs: String)

@Serializable
data class EventsResponse(val events: List<GameEvent>)

@Serializable
data class ResetRoundResponse(val roundId: String, val status: String, val readyForStart: Boolean)

@Serializable
data class ErrorResponse(val error: ApiError)

@Serializable
data class ApiError(
    val code: String,
    val message: String,
    val details: JsonObject = JsonObject(emptyMap())
)

@Serializable
data class AuthConfigResponse(val enabled: Boolean)

@Serializable
data class AuthRequest(val username: String, val password: String)

@Serializable
data class AuthResponse(val token: String, val username: String)

@Serializable
data class CurrentUserResponse(val username: String?)

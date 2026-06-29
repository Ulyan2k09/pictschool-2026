package school.pict.backend

import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.ApplicationCall
import io.ktor.server.application.call
import io.ktor.server.application.install
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.cors.routing.CORS
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.response.respondTextWriter
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.routing
import kotlinx.coroutines.delay
import kotlinx.serialization.encodeToString

fun main() {
    val config = AppConfig.fromEnvironment()
    embeddedServer(Netty, port = config.httpPort, host = config.httpHost) {
        backendModule(config)
    }.start(wait = true)
}

fun Application.backendModule(
    config: AppConfig = AppConfig.fromEnvironment(),
    tcpSender: TcpCommandSender = SocketTcpCommandSender(config),
    store: GameStore = GameStore()
) {
    install(ContentNegotiation) {
        json(backendJson)
    }

    install(CORS) {
        anyHost()
        allowHeader(HttpHeaders.ContentType)
        allowMethod(HttpMethod.Get)
        allowMethod(HttpMethod.Post)
    }

    val engine = RoundEngine(store, tcpSender, config)

    routing {
        get("/api/round") {
            call.respond(RoundResponse(store.snapshot()))
        }

        post("/api/round/start") {
            val request = runCatching { call.receive<StartRoundRequest>() }.getOrDefault(StartRoundRequest())
            val round = engine.startRound(request.scenarioId)
            call.respond(
                status = io.ktor.http.HttpStatusCode.Created,
                StartRoundResponse(round.id, round.status.wireName(), round.activeActor.wireName())
            )
        }

        post("/api/turn/submit") {
            val request = call.receive<TurnCommandRequest>()
            when (val result = engine.submitTurn(request)) {
                is SubmitTurnResult.Accepted -> call.respond(
                    status = io.ktor.http.HttpStatusCode.Accepted,
                    TurnAcceptedResponse(true, result.eventId, result.forwardedAs)
                )
                is SubmitTurnResult.Rejected -> call.respondError(result.error)
            }
        }

        get("/api/events") {
            call.respond(EventsResponse(store.events()))
        }

        get("/api/live") {
            call.respondTextWriter(contentType = ContentType.Text.EventStream) {
                var sentEvents = 0
                while (true) {
                    val events = store.events()
                    events.drop(sentEvents).forEach { event ->
                        write("event: ${event.type}\n")
                        write("data: ${backendJson.encodeToString(event)}\n\n")
                    }
                    sentEvents = events.size
                    flush()
                    delay(1_000)
                }
            }
        }

        post("/api/round/reset") {
            val round = engine.resetRound()
            call.respond(ResetRoundResponse(round.id, round.status.wireName(), true))
        }
    }
}

private suspend fun ApplicationCall.respondError(error: ApiError) {
    val status = when (error.code) {
        "unknown_command", "turn_limit_exceeded", "wrong_actor_turn", "round_not_running" -> io.ktor.http.HttpStatusCode.BadRequest
        "simulation_error" -> io.ktor.http.HttpStatusCode.BadGateway
        else -> io.ktor.http.HttpStatusCode.InternalServerError
    }
    respond(status, ErrorResponse(error))
}

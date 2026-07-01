package school.pict.backend

import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.testing.testApplication
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ApplicationTest {
    @Test
    fun `round can be started and turn can be submitted through http api`() = testApplication {
        application {
            backendModule(tcpSender = object : TcpCommandSender {
                override fun send(request: SimulationCommandRequest): Result<SimulationCommandResult> = Result.success(
                    SimulationCommandResult(
                        ok = true,
                        actor = request.actor,
                        finalPosition = Position(2, 1),
                        finalDirection = Direction.S,
                        ducksCollected = emptyList()
                    )
                )
            })
        }

        val start = client.post("/api/round/start") {
            headers.append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
            setBody("""{"scenarioId":"default"}""")
        }
        assertEquals(HttpStatusCode.Created, start.status)
        assertEquals("robot", Json.parseToJsonElement(start.bodyAsText()).jsonObject.getValue("activeActor").jsonPrimitive.content)

        val submit = client.post("/api/turn/submit") {
            headers.append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
            setBody("""{"actor":"robot","commands":[1,1,3,1,4]}""")
        }
        assertEquals(HttpStatusCode.Accepted, submit.status)
        assertEquals("1 1 3 1 4", Json.parseToJsonElement(submit.bodyAsText()).jsonObject.getValue("forwardedAs").jsonPrimitive.content)

        val round = client.get("/api/round")
        val roundJson = Json.parseToJsonElement(round.bodyAsText()).jsonObject.getValue("round").jsonObject
        assertEquals("running", roundJson.getValue("status").jsonPrimitive.content)
        assertEquals("agent", roundJson.getValue("activeActor").jsonPrimitive.content)
    }

    @Test
    fun `swagger docs and openapi spec are exposed`() = testApplication {
        application {
            backendModule(tcpSender = object : TcpCommandSender {
                override fun send(request: SimulationCommandRequest): Result<SimulationCommandResult> = Result.success(
                    SimulationCommandResult(
                        ok = true,
                        actor = request.actor,
                        finalPosition = Position(0, 0),
                        finalDirection = Direction.E,
                        ducksCollected = emptyList()
                    )
                )
            })
        }

        val docs = client.get("/api/docs")
        assertEquals(HttpStatusCode.OK, docs.status)
        assertTrue(docs.bodyAsText().contains("SwaggerUIBundle"))

        val openApi = client.get("/api/docs/openapi.yaml")
        assertEquals(HttpStatusCode.OK, openApi.status)
        val body = openApi.bodyAsText()
        assertTrue(body.contains("openapi: 3.0.3"))
        assertTrue(body.contains("/api/turn/submit:"))
    }
}

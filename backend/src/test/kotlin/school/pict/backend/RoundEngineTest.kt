package school.pict.backend

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class RoundEngineTest {
    @Test
    fun `successful robot turn is sent to tcp and switches active actor`() {
        val sender = RecordingTcpSender()
        val store = GameStore()
        val engine = RoundEngine(store, sender, AppConfig())

        engine.startRound("default")
        val result = engine.submitTurn(TurnCommandRequest("robot", listOf(1, 1, 3, 1)))

        assertIs<SubmitTurnResult.Accepted>(result)
        assertEquals("1 1 3 1", sender.payloads.single())
        assertEquals(ActorId.AGENT, store.snapshot().activeActor)
        assertEquals(2, store.snapshot().turnNumber)
    }

    @Test
    fun `more than five commands are rejected before tcp send`() {
        val sender = RecordingTcpSender()
        val store = GameStore()
        val engine = RoundEngine(store, sender, AppConfig())

        engine.startRound("default")
        val result = engine.submitTurn(TurnCommandRequest("robot", listOf(1, 1, 1, 1, 1, 1)))

        val rejected = assertIs<SubmitTurnResult.Rejected>(result)
        assertEquals("turn_limit_exceeded", rejected.error.code)
        assertEquals(emptyList(), sender.payloads)
        assertEquals(ActorId.ROBOT, store.snapshot().activeActor)
    }

    @Test
    fun `unknown commands are rejected before tcp send`() {
        val sender = RecordingTcpSender()
        val store = GameStore()
        val engine = RoundEngine(store, sender, AppConfig())

        engine.startRound("default")
        val result = engine.submitTurn(TurnCommandRequest("robot", listOf(1, 7, 4)))

        val rejected = assertIs<SubmitTurnResult.Rejected>(result)
        assertEquals("unknown_command", rejected.error.code)
        assertEquals(emptyList(), sender.payloads)
    }

    @Test
    fun `tcp failure is converted to simulation error`() {
        val sender = RecordingTcpSender(Result.failure(IllegalStateException("port closed")))
        val store = GameStore()
        val engine = RoundEngine(store, sender, AppConfig())

        engine.startRound("default")
        val result = engine.submitTurn(TurnCommandRequest("robot", listOf(1)))

        val rejected = assertIs<SubmitTurnResult.Rejected>(result)
        assertEquals("simulation_error", rejected.error.code)
        assertEquals(listOf("1"), sender.payloads)
        assertEquals(ActorId.ROBOT, store.snapshot().activeActor)
        assertEquals("turn.failed", store.events().last().type)
    }
}

private class RecordingTcpSender(private val result: Result<Unit> = Result.success(Unit)) : TcpCommandSender {
    val payloads = mutableListOf<String>()

    override fun send(payload: String): Result<Unit> {
        payloads += payload
        return result
    }
}

package school.pict.backend

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import java.net.InetSocketAddress
import java.net.Socket

interface TcpCommandSender {
    fun send(request: SimulationCommandRequest): Result<SimulationCommandResult>
}

class SocketTcpCommandSender(private val config: AppConfig) : TcpCommandSender {
    override fun send(request: SimulationCommandRequest): Result<SimulationCommandResult> = runCatching {
        val payload = backendJson.encodeToString(request)
        Socket().use { socket ->
            socket.connect(InetSocketAddress(config.simTcpHost, config.simTcpCommandPort), config.simTcpTimeoutMillis)
            socket.soTimeout = config.simTcpTimeoutMillis

            val output = socket.getOutputStream()
            output.write(payload.encodeToByteArray())
            output.write('\n'.code)
            output.flush()
            socket.shutdownOutput()

            val response = socket.getInputStream().bufferedReader().readText().trim()
            require(response.isNotBlank()) {
                "Симуляция закрыла соединение без ответа."
            }

            backendJson.decodeFromString<SimulationCommandResult>(response)
        }
    }
}

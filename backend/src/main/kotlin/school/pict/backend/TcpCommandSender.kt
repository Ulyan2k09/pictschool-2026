package school.pict.backend

import java.net.InetSocketAddress
import java.net.Socket

interface TcpCommandSender {
    fun send(payload: String): Result<Unit>
}

class SocketTcpCommandSender(private val config: AppConfig) : TcpCommandSender {
    override fun send(payload: String): Result<Unit> = runCatching {
        Socket().use { socket ->
            socket.connect(InetSocketAddress(config.simTcpHost, config.simTcpCommandPort), config.simTcpTimeoutMillis)
            socket.getOutputStream().use { output ->
                output.write(payload.encodeToByteArray())
                output.flush()
            }
        }
    }
}

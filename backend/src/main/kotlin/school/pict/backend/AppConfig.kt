package school.pict.backend

data class AppConfig(
    val httpHost: String = "0.0.0.0",
    val httpPort: Int = 8080,
    val simTcpHost: String = "127.0.0.1",
    val simTcpCommandPort: Int = 5055,
    val simTcpTelemetryPort: Int = 5056,
    val simTcpTimeoutMillis: Int = 1_000,
    val authEnabled: Boolean = false,
    val databaseUrl: String = "jdbc:postgresql://localhost:5432/pictschool",
    val databaseUser: String = "pictschool",
    val databasePassword: String = "pictschool"
) {
    companion object {
        fun fromEnvironment(): AppConfig = AppConfig(
            httpHost = readConfig("HTTP_HOST") ?: "0.0.0.0",
            httpPort = readConfig("HTTP_PORT")?.toIntOrNull() ?: 8080,
            simTcpHost = readConfig("SIM_TCP_HOST") ?: "127.0.0.1",
            simTcpCommandPort = readConfig("SIM_TCP_COMMAND_PORT")?.toIntOrNull() ?: 5055,
            simTcpTelemetryPort = readConfig("SIM_TCP_TELEMETRY_PORT")?.toIntOrNull() ?: 5056,
            simTcpTimeoutMillis = readConfig("SIM_TCP_TIMEOUT_MILLIS")?.toIntOrNull() ?: 1_000,
            authEnabled = readConfig("AUTH_ENABLED")?.toBooleanStrictOrNull() ?: false,
            databaseUrl = readConfig("DATABASE_URL") ?: "jdbc:postgresql://localhost:5432/pictschool",
            databaseUser = readConfig("DATABASE_USER") ?: "pictschool",
            databasePassword = readConfig("DATABASE_PASSWORD") ?: "pictschool"
        )

        private fun readConfig(key: String): String? = System.getenv(key) ?: System.getProperty(key)
    }
}

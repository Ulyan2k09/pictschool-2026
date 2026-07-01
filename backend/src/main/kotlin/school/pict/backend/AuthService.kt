package school.pict.backend

import java.security.MessageDigest
import java.security.SecureRandom
import java.sql.Connection
import java.sql.DriverManager
import java.sql.Timestamp
import java.time.Instant
import java.util.Base64
import java.util.UUID

class AuthService(private val config: AppConfig) {
    init {
        Class.forName("org.postgresql.Driver")
        initializeSchemaWithRetry()
    }

    fun register(username: String, password: String): Result<String> = runCatching {
        val normalized = normalizeUsername(username)
        validatePassword(password)
        val salt = randomToken(18)
        val passwordHash = hashPassword(password, salt)
        connection().use { connection ->
            connection.prepareStatement(
                """
                insert into users(username, password_salt, password_hash)
                values (?, ?, ?)
                """.trimIndent()
            ).use { statement ->
                statement.setString(1, normalized)
                statement.setString(2, salt)
                statement.setString(3, passwordHash)
                statement.executeUpdate()
            }
        }
        createSession(normalized)
    }

    fun login(username: String, password: String): Result<String> = runCatching {
        val normalized = normalizeUsername(username)
        connection().use { connection ->
            connection.prepareStatement(
                "select password_salt, password_hash from users where username = ?"
            ).use { statement ->
                statement.setString(1, normalized)
                statement.executeQuery().use { rows ->
                    require(rows.next()) { "Неверный логин или пароль." }
                    val salt = rows.getString("password_salt")
                    val expectedHash = rows.getString("password_hash")
                    require(hashPassword(password, salt) == expectedHash) { "Неверный логин или пароль." }
                }
            }
        }
        createSession(normalized)
    }

    fun usernameByToken(token: String?): String? {
        if (token.isNullOrBlank()) return null
        connection().use { connection ->
            connection.prepareStatement("select username from sessions where token = ?").use { statement ->
                statement.setString(1, token)
                statement.executeQuery().use { rows ->
                    return if (rows.next()) rows.getString("username") else null
                }
            }
        }
    }

    private fun initializeSchemaWithRetry() {
        var lastError: Exception? = null
        repeat(30) { attempt ->
            try {
                initializeSchema()
                return
            } catch (error: Exception) {
                lastError = error
                Thread.sleep(500L + attempt * 100L)
            }
        }
        throw IllegalStateException("Не удалось подключиться к базе авторизации.", lastError)
    }

    private fun initializeSchema() {
        connection().use { connection ->
            connection.createStatement().use { statement ->
                statement.executeUpdate(
                    """
                    create table if not exists users(
                        username text primary key,
                        password_salt text not null,
                        password_hash text not null,
                        created_at timestamptz not null default now()
                    )
                    """.trimIndent()
                )
                statement.executeUpdate(
                    """
                    create table if not exists sessions(
                        token text primary key,
                        username text not null references users(username) on delete cascade,
                        created_at timestamptz not null default now()
                    )
                    """.trimIndent()
                )
            }
        }
    }

    private fun createSession(username: String): String {
        val token = randomToken(32)
        connection().use { connection ->
            connection.prepareStatement(
                "insert into sessions(token, username, created_at) values (?, ?, ?)"
            ).use { statement ->
                statement.setString(1, token)
                statement.setString(2, username)
                statement.setTimestamp(3, Timestamp.from(Instant.now()))
                statement.executeUpdate()
            }
        }
        return token
    }

    private fun connection(): Connection =
        DriverManager.getConnection(config.databaseUrl, config.databaseUser, config.databasePassword)

    private fun normalizeUsername(username: String): String {
        val normalized = username.trim().lowercase()
        require(normalized.matches(Regex("[a-z0-9_\\-.]{3,32}"))) {
            "Логин должен быть 3-32 символа: латиница, цифры, _, - или точка."
        }
        return normalized
    }

    private fun validatePassword(password: String) {
        require(password.length >= 6) { "Пароль должен быть не короче 6 символов." }
    }

    private fun hashPassword(password: String, salt: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest("$salt:$password".encodeToByteArray())
        return Base64.getEncoder().encodeToString(bytes)
    }

    private fun randomToken(byteCount: Int): String {
        val bytes = ByteArray(byteCount)
        secureRandom.nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes) + "." + UUID.randomUUID()
    }

    companion object {
        private val secureRandom = SecureRandom()
    }
}

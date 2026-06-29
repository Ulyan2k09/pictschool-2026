package school.pict.backend

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

fun Position.toJson(): JsonObject = buildJsonObject {
    put("x", x)
    put("y", y)
}

fun Score.toJson(): JsonObject = buildJsonObject {
    put("robot", robot)
    put("agent", agent)
}

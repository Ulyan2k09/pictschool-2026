package school.pict.backend

import kotlinx.serialization.json.Json

val backendJson: Json = Json {
    prettyPrint = true
    isLenient = true
    ignoreUnknownKeys = true
    encodeDefaults = true
}

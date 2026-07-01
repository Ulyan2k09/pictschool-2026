package school.pict.backend

object LocalMovement {
    fun apply(round: Round, actor: ActorId, commands: List<Int>): MovementResult {
        var state = round.actors.getValue(actor)
        commands.forEach { command ->
            state = when (command) {
                1 -> state.copy(position = move(state.position, state.direction, 1, round.field))
                2 -> state.copy(position = move(state.position, state.direction, -1, round.field))
                3 -> state.copy(direction = state.direction.left())
                4 -> state.copy(direction = state.direction.right())
                else -> state
            }
        }

        val collected = round.field.ducks
            .filter { it.collectedBy == null && it.position == state.position }
            .map { it.id }
        val nextDucks = round.field.ducks.map { duck ->
            if (duck.id in collected) duck.copy(collectedBy = actor.wireName()) else duck
        }
        val nextScore = when (actor) {
            ActorId.ROBOT -> round.score.copy(robot = round.score.robot + collected.size)
            ActorId.AGENT -> round.score.copy(agent = round.score.agent + collected.size)
        }
        val ducksLeft = nextDucks.count { it.collectedBy == null }
        val completed = ducksLeft == 0
        val nextActors = round.actors + (actor to state.copy(collectedDucks = state.collectedDucks + collected.size, lastError = null))
        val nextRound = round.copy(
            status = if (completed) RoundStatus.COMPLETED else RoundStatus.RUNNING,
            activeActor = if (completed) round.activeActor else actor.other(),
            turnNumber = if (completed) round.turnNumber else round.turnNumber + 1,
            ducksLeft = ducksLeft,
            score = nextScore,
            field = round.field.copy(ducks = nextDucks),
            actors = nextActors
        )
        return MovementResult(nextRound, nextActors.getValue(actor), collected)
    }

    fun applySimulationResult(round: Round, actor: ActorId, result: SimulationCommandResult): MovementResult {
        val finalPosition = requireNotNull(result.finalPosition)
        val finalDirection = requireNotNull(result.finalDirection)
        val reportedCollected = result.ducksCollected.toSet()
        val collected = round.field.ducks
            .filter { it.collectedBy == null && it.id in reportedCollected }
            .map { it.id }
        val nextDucks = round.field.ducks.map { duck ->
            if (duck.id in collected) duck.copy(collectedBy = actor.wireName()) else duck
        }
        val nextScore = when (actor) {
            ActorId.ROBOT -> round.score.copy(robot = round.score.robot + collected.size)
            ActorId.AGENT -> round.score.copy(agent = round.score.agent + collected.size)
        }
        val ducksLeft = nextDucks.count { it.collectedBy == null }
        val completed = ducksLeft == 0
        val nextActorState = round.actors.getValue(actor).copy(
            position = finalPosition,
            direction = finalDirection,
            collectedDucks = round.actors.getValue(actor).collectedDucks + collected.size,
            lastError = null
        )
        val nextActors = round.actors + (actor to nextActorState)
        val nextRound = round.copy(
            status = if (completed) RoundStatus.COMPLETED else RoundStatus.RUNNING,
            activeActor = if (completed) round.activeActor else actor.other(),
            turnNumber = if (completed) round.turnNumber else round.turnNumber + 1,
            ducksLeft = ducksLeft,
            score = nextScore,
            field = round.field.copy(ducks = nextDucks),
            actors = nextActors
        )
        return MovementResult(nextRound, nextActorState, collected)
    }

    private fun move(position: Position, direction: Direction, step: Int, field: Field): Position {
        val candidate = when (direction) {
            Direction.N -> position.copy(y = position.y - step)
            Direction.E -> position.copy(x = position.x + step)
            Direction.S -> position.copy(y = position.y + step)
            Direction.W -> position.copy(x = position.x - step)
        }
        val inside = candidate.x in 0 until field.width && candidate.y in 0 until field.height
        val blocked = field.obstacles.any { it.position == candidate }
        return if (inside && !blocked) candidate else position
    }
}

data class MovementResult(
    val round: Round,
    val actorState: ActorState,
    val collectedDucks: List<String>
)

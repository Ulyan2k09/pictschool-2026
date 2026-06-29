package school.pict.backend

object Scenario {
    fun defaultRound(status: RoundStatus): Round {
        val ducks = listOf(
            Duck("duck-1", Position(1, 0)),
            Duck("duck-2", Position(3, 1)),
            Duck("duck-3", Position(6, 1)),
            Duck("duck-4", Position(2, 3)),
            Duck("duck-5", Position(5, 3)),
            Duck("duck-6", Position(0, 5)),
            Duck("duck-7", Position(4, 5)),
            Duck("duck-8", Position(7, 2))
        )
        return Round(
            id = "round-1",
            status = status,
            activeActor = ActorId.ROBOT,
            turnNumber = 1,
            moveLimitPerTurn = 5,
            ducksTotal = ducks.size,
            ducksLeft = ducks.size,
            score = Score(0, 0),
            field = Field(
                width = 8,
                height = 6,
                obstacles = listOf(
                    Obstacle("wall-1", Position(3, 2)),
                    Obstacle("wall-2", Position(4, 2))
                ),
                ducks = ducks
            ),
            actors = mapOf(
                ActorId.ROBOT to ActorState(ActorId.ROBOT, Position(0, 0), Direction.E, 0, null),
                ActorId.AGENT to ActorState(ActorId.AGENT, Position(7, 5), Direction.W, 0, null)
            )
        )
    }
}

#ifndef MOVEMENT_LAYER_H
#define MOVEMENT_LAYER_H

#define PLATFORM_CMD_FORWARD 1
#define PLATFORM_CMD_TURN_RIGHT 2
#define PLATFORM_CMD_TURN_LEFT 3
#define PLATFORM_CMD_BACKWARD 4

#define SCHOOL_CMD_FORWARD 1
#define SCHOOL_CMD_BACKWARD 2
#define SCHOOL_CMD_TURN_LEFT 3
#define SCHOOL_CMD_TURN_RIGHT 4

#define SCHOOL_CMD_FORWARD_TWICE 10
#define SCHOOL_CMD_U_TURN 11
#define SCHOOL_CMD_STEP_RIGHT 12
#define SCHOOL_CMD_STEP_LEFT 13

int movement_is_supported_command(int command);
int movement_expand_command(int command, int *platform_commands, int max_commands);

#endif

#include <webots/robot.h>
#include <webots/supervisor.h>
#include <webots/emitter.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "movement_layer.h"
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
typedef SOCKET socket_t;
#define CLOSE_SOCKET closesocket
#define WOULD_BLOCK_ERROR (WSAGetLastError() == WSAEWOULDBLOCK)
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
typedef int socket_t;
#define INVALID_SOCKET (-1)
#define SOCKET_ERROR (-1)
#define CLOSE_SOCKET close
#define WOULD_BLOCK_ERROR (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
#endif

#define TIME_STEP 32
#define FIELD_SIZE_X 10
#define FIELD_SIZE_Y 10
#define PLATFORM_SIZE 0.1
#define MAX_COMMANDS 100
#define PORT1 10000
#define PORT2 10001
#define MAX_LINE 4096
#define FALLING_PLATFORMS 0

static int occupied[FIELD_SIZE_X][FIELD_SIZE_Y] = {0};
static int activated[FIELD_SIZE_X][FIELD_SIZE_Y] = {0};
static int blocked[FIELD_SIZE_X][FIELD_SIZE_Y] = {0};

typedef struct {
    int i, j;
    int orientation;
    int commands[MAX_COMMANDS];
    int cmd_count;
    int cmd_index;
    int active;
    WbNodeRef node;
    char name[20];
    int waiting;
    int wait_counter;
} RobotState;

RobotState robots[2];

int orientation_from_direction(const char *direction) {
    if (strcmp(direction, "E") == 0) return 0;
    if (strcmp(direction, "S") == 0) return 1;
    if (strcmp(direction, "W") == 0) return 2;
    if (strcmp(direction, "N") == 0) return 3;
    return 0;
}

double angle_from_orientation(int orient) {
    return orient * M_PI / 2.0;
}

void set_robot_orientation(RobotState *r) {
    WbFieldRef rotation_field = wb_supervisor_node_get_field(r->node, "rotation");
    double angle = angle_from_orientation(r->orientation);
    const double rotation[4] = {0, 0, 1, angle};
    wb_supervisor_field_set_sf_rotation(rotation_field, rotation);
}

int is_cell_free(int i, int j) {
    if (i < 0 || i >= FIELD_SIZE_X || j < 0 || j >= FIELD_SIZE_Y) {
        printf("Cell (%d,%d) is out of field!\n", i, j);
        fflush(stdout);
        return 0;
    }
    if (occupied[i][j]) {
        printf("Cell (%d,%d) is occupied by another robot!\n", i, j);
        fflush(stdout);
        return 0;
    }
    if (blocked[i][j]) {
        printf("Cell (%d,%d) is blocked by obstacle!\n", i, j);
        fflush(stdout);
        return 0;
    }
    return 1;
}

void cell_to_position(int i, int j, double z, double position[3]) {
    position[0] = -0.45 + i * PLATFORM_SIZE;
    position[1] = -0.45 + j * PLATFORM_SIZE;
    position[2] = z;
}

void set_robot_cell(int robot_index, int i, int j, int orientation) {
    RobotState *robot = &robots[robot_index];
    if (robot->i >= 0 && robot->i < FIELD_SIZE_X && robot->j >= 0 && robot->j < FIELD_SIZE_Y) {
        occupied[robot->i][robot->j] = 0;
    }
    robot->i = i;
    robot->j = j;
    robot->orientation = orientation;
    robot->cmd_count = 0;
    robot->cmd_index = 0;
    robot->active = 0;
    robot->waiting = 0;
    robot->wait_counter = 0;
    occupied[i][j] = 1;

    double position[3];
    cell_to_position(i, j, 0.05, position);
    WbFieldRef translation_field = wb_supervisor_node_get_field(robot->node, "translation");
    wb_supervisor_field_set_sf_vec3f(translation_field, position);
    set_robot_orientation(robot);
}

void remove_existing_platforms() {
    for (int i = 0; i < FIELD_SIZE_X; ++i) {
        for (int j = 0; j < FIELD_SIZE_Y; ++j) {
            char def_name[64];
            sprintf(def_name, "platform_%d_%d", i, j);
            WbNodeRef platform = wb_supervisor_node_get_from_def(def_name);
            if (platform) {
                wb_supervisor_node_remove(platform);
            }
        }
    }
}

void create_platforms(WbFieldRef children_field, int duck_present[FIELD_SIZE_X][FIELD_SIZE_Y]) {
    remove_existing_platforms();
    memset(activated, 0, sizeof(activated));

    for (int i = 0; i < FIELD_SIZE_X; ++i) {
        for (int j = 0; j < FIELD_SIZE_Y; ++j) {
            double position[3];
            cell_to_position(i, j, -0.1, position);
            char description[2048];
            sprintf(description,
                "DEF platform_%d_%d Solid { "
                "translation %f %f %f "
                "children [ "
                "Shape { appearance Appearance { material Material { diffuseColor %s } } geometry Box { size %f %f 0.01 } }",
                i, j, position[0], position[1], position[2],
                blocked[i][j] ? "0.55 0.08 0.08" : "0.2 0.2 0.2",
                PLATFORM_SIZE, PLATFORM_SIZE);
            if (duck_present[i][j]) {
                char duck_part[1024];
                double duck_angle = (double)((i * 31 + j * 17) % 360) * M_PI / 180.0;
                sprintf(duck_part,
                    " RubberDuck { translation 0 0 0.03 rotation 0 0 1 %f scale 0.6 }",
                    duck_angle);
                strcat(description, duck_part);
            }
            strcat(description, " ] boundingObject Box { size ");
            char buffer[100];
            sprintf(buffer, "%f %f 0.01 } }", PLATFORM_SIZE, PLATFORM_SIZE);
            strcat(description, buffer);
            wb_supervisor_field_import_mf_node_from_string(children_field, -1, description);
        }
    }
}

void apply_setup_line(const char *line, WbFieldRef children_field) {
    char *copy = strdup(line);
    if (!copy) {
        return;
    }

    int duck_present[FIELD_SIZE_X][FIELD_SIZE_Y] = {0};
    memset(blocked, 0, sizeof(blocked));
    memset(occupied, 0, sizeof(occupied));

    char *token = strtok(copy, " ");
    if (!token || strcmp(token, "SETUP") != 0) {
        free(copy);
        return;
    }

    token = strtok(NULL, " "); // round id
    token = strtok(NULL, " "); // field width
    token = strtok(NULL, " "); // field height

    while ((token = strtok(NULL, " ")) != NULL) {
        if (strcmp(token, "R") == 0 || strcmp(token, "A") == 0) {
            int robot_index = strcmp(token, "R") == 0 ? 0 : 1;
            char *x_token = strtok(NULL, " ");
            char *y_token = strtok(NULL, " ");
            char *direction_token = strtok(NULL, " ");
            if (!x_token || !y_token || !direction_token) break;
            int i = atoi(x_token);
            int j = atoi(y_token);
            if (i >= 0 && i < FIELD_SIZE_X && j >= 0 && j < FIELD_SIZE_Y) {
                set_robot_cell(robot_index, i, j, orientation_from_direction(direction_token));
            }
        } else if (strcmp(token, "D") == 0 || strcmp(token, "O") == 0) {
            int is_duck = strcmp(token, "D") == 0;
            char *count_token = strtok(NULL, " ");
            if (!count_token) break;
            int count = atoi(count_token);
            for (int index = 0; index < count; ++index) {
                char *x_token = strtok(NULL, " ");
                char *y_token = strtok(NULL, " ");
                if (!x_token || !y_token) break;
                int i = atoi(x_token);
                int j = atoi(y_token);
                if (i >= 0 && i < FIELD_SIZE_X && j >= 0 && j < FIELD_SIZE_Y) {
                    if (is_duck) {
                        duck_present[i][j] = 1;
                    } else {
                        blocked[i][j] = 1;
                    }
                }
            }
        }
    }

    create_platforms(children_field, duck_present);
    printf("Applied backend setup to Webots scene.\n");
    fflush(stdout);
    free(copy);
}

void activate_platform(int i, int j) {
    if (activated[i][j]) {
        return;
    }
    activated[i][j] = 1;
    if (!FALLING_PLATFORMS) {
        return;
    }
    char def_name[64];
    sprintf(def_name, "platform_%d_%d", i, j);
    WbNodeRef platform = wb_supervisor_node_get_from_def(def_name);
    if (platform) {
        WbFieldRef physics_field = wb_supervisor_node_get_field(platform, "physics");
        if (physics_field) {
            WbNodeRef physics_node = wb_supervisor_field_get_sf_node(physics_field);
            if (physics_node == NULL) {
                wb_supervisor_field_import_sf_node_from_string(physics_field, "Physics { density 1000 }");
                printf("Platform (%d,%d) fell down.\n", i, j);
                fflush(stdout);
            }
        }
    }
}

socket_t setup_server(int port) {
    socket_t sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == INVALID_SOCKET) {
        perror("socket");
        return INVALID_SOCKET;
    }
    int opt = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (const char *)&opt, sizeof(opt));
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);
    if (bind(sock, (struct sockaddr*)&address, sizeof(address)) < 0) {
        perror("bind");
        CLOSE_SOCKET(sock);
        return INVALID_SOCKET;
    }
    if (listen(sock, 1) < 0) {
        perror("listen");
        CLOSE_SOCKET(sock);
        return INVALID_SOCKET;
    }
#ifdef _WIN32
    u_long mode = 1;
    ioctlsocket(sock, FIONBIO, &mode);
#else
    fcntl(sock, F_SETFL, O_NONBLOCK);
#endif
    return sock;
}

socket_t accept_connection(socket_t listen_sock) {
    struct sockaddr_in client_address;
#ifdef _WIN32
    int length = sizeof(client_address);
#else
    socklen_t length = sizeof(client_address);
#endif
    socket_t client = accept(listen_sock, (struct sockaddr*)&client_address, &length);
    if (client == INVALID_SOCKET) {
        if (WOULD_BLOCK_ERROR) {
            return INVALID_SOCKET;
        }
        perror("accept");
        return INVALID_SOCKET;
    }
#ifdef _WIN32
    u_long mode = 1;
    ioctlsocket(client, FIONBIO, &mode);
#else
    fcntl(client, F_SETFL, O_NONBLOCK);
#endif
    return client;
}

int read_line(socket_t sock, char *buffer, int *buffer_len, char *out_line, int max_line) {
    if (sock == INVALID_SOCKET) {
        return -1;
    }
    int n = recv(sock, buffer + *buffer_len, MAX_LINE - *buffer_len - 1, 0);
    if (n > 0) {
        *buffer_len += n;
        buffer[*buffer_len] = '\0';
        char *newline = strchr(buffer, '\n');
        if (newline) {
            *newline = '\0';
            strncpy(out_line, buffer, max_line);
            int remaining = strlen(newline + 1);
            memmove(buffer, newline + 1, remaining + 1);
            *buffer_len = remaining;
            return 1;
        }
        return 0;
    } else if (n == 0) {
        return -1;
    } else {
        if (WOULD_BLOCK_ERROR) {
            return 0;
        }
        perror("recv");
        return -1;
    }
}

int parse_commands(const char *line, int *commands_array) {
    int count = 0;
    char *copy = strdup(line);
    if (!copy) {
        return 0;
    }
    char *token = strtok(copy, " ,");
    while (token && count < MAX_COMMANDS) {
        int value = atoi(token);
        int expanded[MAX_COMMANDS];
        int expanded_count = movement_expand_command(value, expanded, MAX_COMMANDS - count);
        if (expanded_count > 0) {
            for (int i = 0; i < expanded_count; ++i) {
                commands_array[count++] = expanded[i];
            }
        } else if (!movement_is_supported_command(value)) {
            printf("Unsupported movement command ignored: %d\n", value);
            fflush(stdout);
        }
        token = strtok(NULL, " ,");
    }
    free(copy);
    return count;
}

int main() {
    printf("Supervisor started.\n");
    fflush(stdout);

#ifdef _WIN32
    WSADATA wsa_data;
    if (WSAStartup(MAKEWORD(2, 2), &wsa_data) != 0) {
        printf("WSAStartup failed.\n");
        return 1;
    }
#endif

    wb_robot_init();
    srand(time(NULL));

    WbDeviceTag emitter = wb_robot_get_device("emitter");
    if (emitter == 0) {
        printf("Emitter not found! Add Emitter to supervisor.\n");
        wb_robot_cleanup();
        return 1;
    }

    WbNodeRef root = wb_supervisor_node_get_root();
    WbFieldRef children_field = wb_supervisor_node_get_field(root, "children");

    const char *robot_defs[2] = {"e-puck", "e-puck-2"};
    for (int r = 0; r < 2; ++r) {
        WbNodeRef node = wb_supervisor_node_get_from_def(robot_defs[r]);
        if (node == NULL) {
            printf("Robot DEF '%s' not found.\n", robot_defs[r]);
            wb_robot_cleanup();
            return 1;
        }
        robots[r].node = node;
        strcpy(robots[r].name, robot_defs[r]);
        robots[r].active = 1;
        robots[r].cmd_count = 0;
        robots[r].cmd_index = 0;
        robots[r].i = -1;
        robots[r].j = -1;
        robots[r].orientation = 0;
        robots[r].waiting = 0;
        robots[r].wait_counter = 0;
    }

    set_robot_cell(0, 0, 0, orientation_from_direction("E"));
    set_robot_cell(1, 7, 5, orientation_from_direction("W"));

    int duck_present[FIELD_SIZE_X][FIELD_SIZE_Y] = {0};
    create_platforms(children_field, duck_present);
    printf("Empty platforms created; waiting for backend SETUP.\n");
    fflush(stdout);

    socket_t listen_sock1 = setup_server(PORT1);
    socket_t listen_sock2 = setup_server(PORT2);
    if (listen_sock1 == INVALID_SOCKET || listen_sock2 == INVALID_SOCKET) {
        printf("Failed to create TCP servers.\n");
        wb_robot_cleanup();
        return 1;
    }

    socket_t client1 = INVALID_SOCKET;
    socket_t client2 = INVALID_SOCKET;
    char receive_buffer1[MAX_LINE] = {0};
    char receive_buffer2[MAX_LINE] = {0};
    int buffer_len1 = 0;
    int buffer_len2 = 0;
    char line1[MAX_LINE];
    char line2[MAX_LINE];

    printf("Servers on ports %d and %d, waiting for connections...\n", PORT1, PORT2);
    fflush(stdout);

    while (wb_robot_step(TIME_STEP) != -1) {
        if (client1 == INVALID_SOCKET) {
            client1 = accept_connection(listen_sock1);
            if (client1 != INVALID_SOCKET) {
                printf("e-puck connected (fd=%d)\n", client1);
                fflush(stdout);
            }
        }
        if (client2 == INVALID_SOCKET) {
            client2 = accept_connection(listen_sock2);
            if (client2 != INVALID_SOCKET) {
                printf("e-puck-2 connected (fd=%d)\n", client2);
                fflush(stdout);
            }
        }

        if (client1 != INVALID_SOCKET) {
            int result = read_line(client1, receive_buffer1, &buffer_len1, line1, MAX_LINE);
            if (result == 1) {
                if (strncmp(line1, "SETUP ", 6) == 0) {
                    printf("received setup: %s\n", line1);
                    apply_setup_line(line1, children_field);
                } else {
                    printf("e-puck received commands: %s\n", line1);
                    robots[0].cmd_count = parse_commands(line1, robots[0].commands);
                    robots[0].cmd_index = 0;
                    robots[0].active = 1;
                    printf("e-puck parsed %d commands.\n", robots[0].cmd_count);
                }
                fflush(stdout);
            } else if (result == -1) {
                CLOSE_SOCKET(client1);
                client1 = INVALID_SOCKET;
                buffer_len1 = 0;
                printf("e-puck disconnected.\n");
                fflush(stdout);
            }
        }
        if (client2 != INVALID_SOCKET) {
            int result = read_line(client2, receive_buffer2, &buffer_len2, line2, MAX_LINE);
            if (result == 1) {
                if (strncmp(line2, "SETUP ", 6) == 0) {
                    printf("received setup: %s\n", line2);
                    apply_setup_line(line2, children_field);
                } else {
                    printf("e-puck-2 received commands: %s\n", line2);
                    robots[1].cmd_count = parse_commands(line2, robots[1].commands);
                    robots[1].cmd_index = 0;
                    robots[1].active = 1;
                    printf("e-puck-2 parsed %d commands.\n", robots[1].cmd_count);
                }
                fflush(stdout);
            } else if (result == -1) {
                CLOSE_SOCKET(client2);
                client2 = INVALID_SOCKET;
                buffer_len2 = 0;
                printf("e-puck-2 disconnected.\n");
                fflush(stdout);
            }
        }

        for (int r = 0; r < 2; ++r) {
            RobotState *robot = &robots[r];

            if (robot->waiting) {
                robot->wait_counter++;
                if (robot->wait_counter > 30) {
                    robot->waiting = 0;
                    robot->wait_counter = 0;
                    const double *position = wb_supervisor_node_get_position(robot->node);
                    int i = (int)round((position[0] + 0.45) / PLATFORM_SIZE);
                    int j = (int)round((position[1] + 0.45) / PLATFORM_SIZE);
                    if (i != robot->i || j != robot->j) {
                        occupied[robot->i][robot->j] = 0;
                        robot->i = i;
                        robot->j = j;
                        occupied[i][j] = 1;
                        activate_platform(i, j);
                    }
                    robot->cmd_index++;
                    if (robot->cmd_index >= robot->cmd_count) {
                        printf("%s all commands executed.\n", robot->name);
                        fflush(stdout);
                        robot->active = 0;
                    }
                }
                continue;
            }

            if (robot->active && robot->cmd_index < robot->cmd_count) {
                int command = robot->commands[robot->cmd_index];

                if (command == 2 || command == 3) {
                    if (command == 2) {
                        robot->orientation = (robot->orientation + 1) % 4;
                    } else {
                        robot->orientation = (robot->orientation + 3) % 4;
                    }
                    set_robot_orientation(robot);
                    robot->cmd_index++;
                    printf("%s turn, new orientation %d\n", robot->name, robot->orientation);
                    fflush(stdout);
                    continue;
                }

                int delta_i = 0;
                int delta_j = 0;
                if (command == 1) {
                    switch (robot->orientation) {
                        case 0: delta_i = 1; break;
                        case 1: delta_j = 1; break;
                        case 2: delta_i = -1; break;
                        case 3: delta_j = -1; break;
                    }
                } else if (command == 4) {
                    switch (robot->orientation) {
                        case 0: delta_i = -1; break;
                        case 1: delta_j = -1; break;
                        case 2: delta_i = 1; break;
                        case 3: delta_j = 1; break;
                    }
                }

                int new_i = robot->i + delta_i;
                int new_j = robot->j + delta_j;

                if (!is_cell_free(new_i, new_j)) {
                    robot->active = 0;
                    robot->cmd_count = 0;
                    robot->cmd_index = 0;
                    printf("%s abort at cell (%d,%d)\n", robot->name, new_i, new_j);
                    fflush(stdout);
                    continue;
                }

                char message[8];
                sprintf(message, "%d:%d", r, command);
                wb_emitter_send(emitter, message, strlen(message) + 1);
                printf("%s sent command %d -> cell (%d,%d)\n",
                       robot->name, command, new_i, new_j);
                fflush(stdout);
                robot->waiting = 1;
                robot->wait_counter = 0;
            }
        }
    }

    if (client1 != INVALID_SOCKET) CLOSE_SOCKET(client1);
    if (client2 != INVALID_SOCKET) CLOSE_SOCKET(client2);
    if (listen_sock1 != INVALID_SOCKET) CLOSE_SOCKET(listen_sock1);
    if (listen_sock2 != INVALID_SOCKET) CLOSE_SOCKET(listen_sock2);

#ifdef _WIN32
    WSACleanup();
#endif

    wb_robot_cleanup();
    printf("Supervisor finished.\n");
    fflush(stdout);
    return 0;
}

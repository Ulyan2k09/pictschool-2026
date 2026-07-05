#include <webots/robot.h>
#include <webots/receiver.h>
#include <webots/motor.h>
#include <webots/position_sensor.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
 
#define TIME_STEP 32
#define MAX_SPEED 6.28
#define WHEEL_RADIUS 0.0205
#define CELL_SIZE 0.1
#define CORRECTION_FACTOR 0.5

int main() {
  wb_robot_init();
  const char *robot_name = wb_robot_get_name();
  int robot_index = strstr(robot_name, "(1)") != NULL ? 1 : 0;

  WbDeviceTag receiver = wb_robot_get_device("receiver");
  wb_receiver_enable(receiver, TIME_STEP);

  WbDeviceTag left_motor = wb_robot_get_device("left wheel motor");
  WbDeviceTag right_motor = wb_robot_get_device("right wheel motor");
  wb_motor_set_position(left_motor, INFINITY);
  wb_motor_set_position(right_motor, INFINITY);
  wb_motor_set_velocity(left_motor, 0);
  wb_motor_set_velocity(right_motor, 0);

  WbDeviceTag left_encoder = wb_robot_get_device("left wheel sensor");
  WbDeviceTag right_encoder = wb_robot_get_device("right wheel sensor");
  wb_position_sensor_enable(left_encoder, TIME_STEP);
  wb_position_sensor_enable(right_encoder, TIME_STEP);

  int moving = 0;
  double start_position = 0.0;
  double target_position = 0.0;
  double target_distance = CELL_SIZE * CORRECTION_FACTOR;

  while (wb_robot_step(TIME_STEP) != -1) {
    if (!moving && wb_receiver_get_queue_length(receiver) > 0) {
      const char *msg = (const char*)wb_receiver_get_data(receiver);
      int target_index = -1;
      int cmd = 0;
      if (sscanf(msg, "%d:%d", &target_index, &cmd) != 2) {
        target_index = robot_index;
        cmd = atoi(msg);
      }
      wb_receiver_next_packet(receiver);

      if (target_index != robot_index) {
        continue;
      }

      if (cmd == 1 || cmd == 4) {
        double left_pos = wb_position_sensor_get_value(left_encoder);
        double right_pos = wb_position_sensor_get_value(right_encoder);
        start_position = (left_pos + right_pos) / 2.0;
        double delta_angle = target_distance / WHEEL_RADIUS;
        target_position = start_position + delta_angle * (cmd == 1 ? 1.0 : -1.0);
        moving = 1;
        if (cmd == 1) {
          wb_motor_set_velocity(left_motor, MAX_SPEED);
          wb_motor_set_velocity(right_motor, MAX_SPEED);
        } else {
          wb_motor_set_velocity(left_motor, -MAX_SPEED);
          wb_motor_set_velocity(right_motor, -MAX_SPEED);
        }
      }
    }

    if (moving) {
      double left_pos = wb_position_sensor_get_value(left_encoder);
      double right_pos = wb_position_sensor_get_value(right_encoder);
      double avg_pos = (left_pos + right_pos) / 2.0;

      if ((avg_pos - start_position) * (target_position - start_position) >= 0 &&
          fabs(avg_pos - start_position) >= fabs(target_position - start_position)) {
        wb_motor_set_velocity(left_motor, 0);
        wb_motor_set_velocity(right_motor, 0);
        moving = 0;
        printf("Target reached, stopping\n");
        fflush(stdout);
      }
    }
  }

  wb_robot_cleanup();
  return 0;
}

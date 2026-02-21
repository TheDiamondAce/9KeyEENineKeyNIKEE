#include <stdio.h>
#include <math.h>
#include "driver/i2c_master.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define MPU6050_ADDR 0x68
#define PWR_MGMT_1   0x6B
#define ACCEL_XOUT_H 0x3B

#define I2C_MASTER_SCL_IO 22
#define I2C_MASTER_SDA_IO 21

i2c_master_bus_handle_t bus;
i2c_master_dev_handle_t dev;

void mpu6050_write(uint8_t reg, uint8_t data)
{
  uint8_t buf[2] = {reg, data};
  i2c_master_transmit(dev, buf, 2, -1);
}

void mpu6050_read(uint8_t reg, uint8_t *data, size_t len)
{
  i2c_master_transmit_receive(dev, &reg, 1, data, len, -1);
}

void app_main(void)
{
  i2c_master_bus_config_t bus_config = {
      .clk_source = I2C_CLK_SRC_DEFAULT,
      .sda_io_num = I2C_MASTER_SDA_IO,
      .scl_io_num = I2C_MASTER_SCL_IO,
  };

  i2c_new_master_bus(&bus_config, &bus);

  i2c_device_config_t dev_cfg = {
      .device_address = MPU6050_ADDR,
      .scl_speed_hz = 100000,
  };

  i2c_master_bus_add_device(bus, &dev_cfg, &dev);

  // Wake up MPU6050
  mpu6050_write(PWR_MGMT_1, 0);

  printf("MPU6050 ready\n");

  while (1) {
      uint8_t data[6];
      mpu6050_read(ACCEL_XOUT_H, data, 6);

      int16_t ax = (data[0] << 8) | data[1];
      int16_t ay = (data[2] << 8) | data[3];
      int16_t az = (data[4] << 8) | data[5];

      float axf = ax / 16384.0;
      float ayf = ay / 16384.0;
      float azf = az / 16384.0;

      float angle_x = atan2(ayf, azf) * 180 / M_PI;
      float angle_y = atan2(-axf, sqrt(ayf*ayf + azf*azf)) * 180 / M_PI;

      // printf("Tilt X: %.2f°, Tilt Y: %.2f°\n", angle_x, angle_y);
      if(angle_x >= -90 && angle_x <= 90){
        printf("Direction: UP\n");
      }
    else{
      printf("Direction: Down\n");
    }

      vTaskDelay(pdMS_TO_TICKS(500));
  }
}

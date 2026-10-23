#include <Wire.h>
#include <LSM6DS3.h>

// XIAO MG24 Sense:
// LSM6DS3TR-C I2C address is 0x6A.
LSM6DS3 myIMU(I2C_MODE, 0x6A);

// Maximum gyro rate is 1.66kHz, Accel would go up to 6.66kHz
constexpr uint16_t SENSOR_ODR_HZ = 416;//208;//833;
// FIFO rate should be the same, don't know why this is listed as 1600
constexpr uint16_t FIFO_ODR_HZ = 400;

// if true, print in ASCII
constexpr bool ascii_mode = false;

// Binary packet:
//   uint32_t MCU timestamp (micros at FIFO read)
//   uint32_t sensor timestamp (LSM6DS3, 25 us resolution)
//   int16_t gyro X
//   int16_t gyro Y
//   int16_t gyro Z
//   int16_t accel X
//   int16_t accel Y
//   int16_t accel Z
//
// = 26 bytes/packet (2 marker + 2 counter + 2 debugData + 8 timestamps + 12 IMU).
struct __attribute__((packed)) ImuSample
{
  int16_t gx;
  int16_t gy;
  int16_t gz;
  int16_t ax;
  int16_t ay;
  int16_t az;
};

static_assert(sizeof(ImuSample) == 12, "Unexpected packet size");

void sendSample(const uint16_t debugData, const uint32_t t_us,
                const uint32_t t_sensor, const ImuSample &sample)
{
  static uint16_t packetCounter = 0;

  Serial.write(0xAA); // marker byte 1
  Serial.write(0x55); // marker byte 2
  Serial.write(reinterpret_cast<const uint8_t *>(&packetCounter), sizeof(packetCounter));
  packetCounter++;
  Serial.write(reinterpret_cast<const uint8_t *>(&debugData), sizeof(debugData));
  Serial.write(reinterpret_cast<const uint8_t *>(&t_us), sizeof(t_us));
  Serial.write(reinterpret_cast<const uint8_t *>(&t_sensor), sizeof(t_sensor));
  Serial.write(reinterpret_cast<const uint8_t *>(&sample),
               sizeof(sample));
}

void sendSampleAscii(const uint32_t t_us, const uint32_t t_sensor,
                     const ImuSample &sample)
{
  Serial.print(t_us);
  Serial.write(",");
  Serial.print(t_sensor);
  Serial.write(",");
  Serial.print(myIMU.calcAccel(sample.ax), 3);
  Serial.write(",");
  Serial.print(myIMU.calcAccel(sample.ay), 3);
  Serial.write(",");
  Serial.print(myIMU.calcAccel(sample.az), 3);
  Serial.write(",");
  Serial.print(myIMU.calcGyro(sample.gx), 3);
  Serial.write(",");
  Serial.print(myIMU.calcGyro(sample.gy), 3);
  Serial.write(",");
  Serial.print(myIMU.calcGyro(sample.gz), 3);
  Serial.write("\n");
}

void setup()
{
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);

  // we need a pretty high baud rate
  Serial.begin(921600);
  
  while (!Serial);

  // turn on IMU power
  pinMode(PD5, OUTPUT);
  digitalWrite(PD5, HIGH);

  // set I2C to 400 kHz
  Wire.setClock(400000);

  // Configure the IMU
  myIMU.settings.gyroEnabled = 1;
  myIMU.settings.gyroRange = 2000; //max deg/s
  myIMU.settings.gyroBandWidth = 400; //Hz
  myIMU.settings.gyroSampleRate = SENSOR_ODR_HZ;

  myIMU.settings.accelEnabled = 1;
  myIMU.settings.accelRange = 16; //max g
  myIMU.settings.accelBandWidth = 400; //Hz
  myIMU.settings.accelSampleRate = SENSOR_ODR_HZ;

  // Include both sensors in the FIFO.
  myIMU.settings.gyroFifoEnabled = 1;
  myIMU.settings.gyroFifoDecimation = 1;

  myIMU.settings.accelFifoEnabled = 1;
  myIMU.settings.accelFifoDecimation = 1;

  // myIMU.settings.timestampFifoEnabled = 1;

  // Sensor timestamp counter, read from TIMESTAMP0..2 for every sample.
  // 25 us resolution; 6.4 ms would be too coarse at 416 Hz.
  myIMU.settings.timestampEnabled = 1;
  myIMU.settings.timestampResolution = 1;

  // FIFO configuration.
  myIMU.settings.fifoSampleRate = FIFO_ODR_HZ;
  myIMU.settings.fifoModeWord = 6; // continuous
  myIMU.settings.fifoThreshold = 512;

  // Temperature is unnecessary
  myIMU.settings.tempEnabled = 0;

  if (myIMU.begin() != 0) {
    // ASCII error is OK because this happens only during startup.
    Serial.println("LSM6DS3 initialization failed");
    while (1);
  }

  if (ascii_mode) {
    // write a header so this can be used as CSV file
    Serial.write("t_us,t_sensor,ax,ay,az,gx,gy,gz\n");
  }

  myIMU.fifoBegin();

  // workarround
  myIMU.writeRegister(LSM6DS3_ACC_GYRO_FIFO_CTRL4, 0); // disable dataset 3 and 4

  // wait a bit for everything to settle
  delay(10);

  // clear the FIFO, we are ready to go
  myIMU.fifoClear();

  // turn on LED for synchronisation with a camera
  digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
}

void loop()
{
  // check for reset command
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'r') {
      digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
      delay(100);
      myIMU.fifoClear();
      digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
    }
  }

  int16_t status = myIMU.fifoGetStatus();
  uint16_t words = status & 0x0FFF;

  while (words >= 6)
  {

    // One complete gyro + accel sample
    ImuSample sample;

    // Both stamps are read when the sample is dequeued. If debugData stays
    // well above 6, the FIFO is backed up and these are later than the sample.
    const uint32_t t_us = micros();
    myIMU.readRegisterRegion(reinterpret_cast<uint8_t *>(&sample), LSM6DS3_ACC_GYRO_FIFO_DATA_OUT_L, sizeof(sample));

    uint8_t ts[3] = {0};
    myIMU.readRegisterRegion(ts, LSM6DS3_ACC_GYRO_TIMESTAMP0_REG, sizeof(ts));
    const uint32_t t_sensor =
        (uint32_t)ts[0] |
        ((uint32_t)ts[1] << 8) |
        ((uint32_t)ts[2] << 16);

    if (!ascii_mode) {
        sendSample(words, t_us, t_sensor, sample);
    } else {
        sendSampleAscii(t_us, t_sensor, sample);
    }

    words -= 6;
  }
}

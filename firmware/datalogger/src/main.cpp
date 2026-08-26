#include <Arduino.h>
#include <Wire.h>
#include <LSM6DS3.h>

// XIAO MG24 Sense:
// LSM6DS3TR-C I2C address is 0x6A.
LSM6DS3 myIMU(I2C_MODE, 0x6A);

// Maximum gyro rate is 1.66kHz, Accel would go up to 6.66kHz
constexpr uint16_t SENSOR_ODR_HZ = 1660;
// FIFO rate should be the same, don't know why this is listed as 1600
constexpr uint16_t FIFO_ODR_HZ = 1600;

// if true, print in ASCII
constexpr bool ascii_mode = true;

// Binary packet:
//   int16_t accel X
//   int16_t accel Y
//   int16_t accel Z
//   int16_t gyro X
//   int16_t gyro Y
//   int16_t gyro Z
//
// = 12 bytes/sample.
struct __attribute__((packed)) ImuSample
{
  int16_t ax;
  int16_t ay;
  int16_t az;
  int16_t gx;
  int16_t gy;
  int16_t gz;
};

static_assert(sizeof(ImuSample) == 12, "Unexpected packet size");

void sendSample(const ImuSample &sample)
{
  Serial.write(reinterpret_cast<const uint8_t *>(&sample),
               sizeof(sample));
}

void sendSampleAscii(const ImuSample &sample)
{
  Serial.print(myIMU.calcAccel(sample.ax), 3);
  Serial.write("\,");
  Serial.print(myIMU.calcAccel(sample.ay), 3);
  Serial.write("\,");
  Serial.print(myIMU.calcAccel(sample.az), 3);
  Serial.write("\,");
  Serial.print(myIMU.calcGyro(sample.gx), 3);
  Serial.write("\,");
  Serial.print(myIMU.calcGyro(sample.gy), 3);
  Serial.write("\,");
  Serial.print(myIMU.calcGyro(sample.gz), 3);
  Serial.write("\n");
}

void setup()
{
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);

  // we need a pretty high baud rate
  if (!ascii_mode) {
    Serial.begin(460800);
  } else {
    Serial.begin(921600);
  }

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
    Serial.write("ax,ay,az,gx,gy,gz\n");
  }

  // wait a bit for everything to settle
  delay(10);

  //clear the FIFO, we are ready to go
  myIMU.fifoClear();

  // turn on LED for synchronisation with a camera
  digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
}

void loop()
{
  uint16_t fifoStatus = myIMU.fifoGetStatus();
  // low 12 bits are FIFO sample count
  uint16_t fifoSamples = fifoStatus & 0x0FFF;

  // Each FIFO sample contains six 16-bit values:
  // GX,GY,GZ, AX,AY,AZ
  while (fifoSamples > 0)
  {
    ImuSample sample;

    // fifoRead() reads one 16-bit word from FIFO_DATA_OUT.
    //
    // The FIFO data order for this configuration is gyro followed
    // by accelerometer.
    int16_t gx = myIMU.fifoRead();
    int16_t gy = myIMU.fifoRead();
    int16_t gz = myIMU.fifoRead();

    int16_t ax = myIMU.fifoRead();
    int16_t ay = myIMU.fifoRead();
    int16_t az = myIMU.fifoRead();

    sample.ax = ax;
    sample.ay = ay;
    sample.az = az;

    sample.gx = gx;
    sample.gy = gy;
    sample.gz = gz;

    if (!ascii_mode) {
      sendSample(sample);
    } else {
      sendSampleAscii(sample);
    }

    fifoSamples--;
  }
}
